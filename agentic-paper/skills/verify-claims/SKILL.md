---
name: verify-claims
description: Run Chain-of-Verification (CoVe) on a draft or a block of text with factual claims. Spawns the `claim-verifier` agent in a forked (fresh) context so it never sees the draft — then reports which claims are supported, contradicted, or unverifiable. Use when user says "verify these citations", "check the claims in X", "did I hallucinate anything", "fact-check this draft", "run CoVe on this", or after any text generation that asserts facts about papers, datasets, or numerical results. NOT for style/grammar review (use `/agentic-paper:proofread`) or substance review (use `/agentic-paper:review-paper`).
argument-hint: "[file-or-text-path] [--source <path-or-url>] [--no-fail-closed]"
allowed-tools: ["Read", "Grep", "Glob", "Task", "Write"]
---

<!-- Adapted from pedrohcgs/claude-code-my-workflow (MIT), https://github.com/pedrohcgs/claude-code-my-workflow -->


# /agentic-paper:verify-claims — Chain-of-Verification on a Draft

Fact-check a draft using the **Post-Flight Verification protocol**. This skill is where that protocol lives; `.claude/rules/post-flight-verification.md` in the project scaffold is the trigger rule that points here. Rules are scaffold-side by law — a plugin cannot ship them — so that is a **project** path, not a plugin-relative one.

**Input:** `$ARGUMENTS` — path to a file containing the draft (markdown, .qmd, .tex, .md) or a shorthand pointer. Optional flags:

- `--source <path-or-url>` — one or more source-material pointers (repeat for multiple). If omitted, the skill infers from context (e.g., papers referenced, cited arXiv URLs).
- `--no-fail-closed` — downgrade FAIL outcomes to warnings without regeneration. Use sparingly.

## When to pick this skill

- **`/agentic-paper:verify-claims`** (this skill) — ad-hoc fact-checking on any draft or text block the user hands you. One-shot, user-invoked.
- **Other skills that auto-run Post-Flight internally** (`/lit-review`, `/research-ideation`, `/agentic-paper:respond-to-referees`, `/agentic-paper:review-paper --peer`) — no need to call this separately; they already run it.
- **`/agentic-paper:proofread`** — grammar, typos, overflow. Different lens.
- **`/agentic-paper:review-paper`** (default mode) — full manuscript review, not just claim verification.

## How it works

Implements the 4-step CoVe loop from Dhuliawala et al. 2023 ([arXiv:2309.11495](https://arxiv.org/abs/2309.11495)), with architectural enforcement of the fresh-context independence trick.

### Phase 0 — Pre-Flight

Confirm:
- Draft file exists and is readable
- At least one source pointer available (either `--source` or auto-detected from draft)
- The `agentic-paper:claim-verifier` agent is **available** (the `agentic-paper` plugin is installed and
  enabled for this project). Check the agent list, not a file path: a plugin agent lives in a
  version-pinned plugin cache, so there is no stable `.claude/agents/…` path to test. If it is missing,
  say so plainly — CoVe without the forked verifier is not CoVe.

If any fail → surface the failure, do NOT proceed.

### Phase 1 — Extract claims

Read the draft. Identify factual assertions of these types:

| Type | Example |
|------|---------|
| Citation | "Smith (2019, *JEL*) shows X" |
| Numerical fact | "N = 10,000", "ATT = 0.42" |
| Negative literature | "No prior work studies X" |
| Named entity | researcher, paper title, venue, package, estimator name |
| Dataset claim | "The CPS contains field `educ_attain`" |

Skip: opinions, forward-looking suggestions, definitions the draft introduces.

Output a claims table:

```markdown
| ID | Claim | Source hint |
|----|-------|-------------|
| C1 | ... | ... |
```

### Phase 2 — Generate verification questions

One question per claim. Make it specific and answerable from the source alone.

### Phase 3 — Spawn `claim-verifier` (forked, fresh context)

```
Task: subagent_type=agentic-paper:claim-verifier, context=fork
Prompt: hand over claims table + verification questions + source material pointers.
        Do NOT include the draft text.
```

The forked agent runs the CoVe independent-answer step. It has never seen the draft and cannot confirm-bias. It returns a structured verification report.

### Phase 4 — Reconcile

Based on the report:

Aggregate from the verifier's per-claim **severity tiers** (defined in the [`agentic-paper:claim-verifier`](../../agents/claim-verifier.md) agent) — a `cannot-verify` is not automatically a failure:

| Highest tier present | Outcome | What to do |
|---|---|---|
| none | **PASS** | Green Post-Flight block; return. |
| LOW-WARN / EXPLAINED only | **PASS (with notes)** | Green block, listing the inaccessible sources and any documented alternatives. These are not defects. |
| MED-WARN | **PARTIAL** | Yellow block. Name the transient failures and recommend re-running verification or supplying local copies. |
| HIGH-WARN | **FAIL** | Red block listing each contradiction with evidence. If the draft is writeable and the user asked for auto-correction, regenerate the affected sections using the verifier's evidence. Otherwise return the report and let the user decide. |

A fabricated citation is always HIGH-WARN and therefore always FAIL — it is never downgraded, whatever else the run found.

Respect `--no-fail-closed`: on FAIL, produce the warning but do not regenerate.

## Example

```
/agentic-paper:verify-claims .claude/session-reports/lit-review_topic.md --source papers/smith_2021_method.pdf --source papers/jones_2020_survey.pdf
```

Expected output (abridged):

```markdown
## Post-Flight Verification — lit-review_staggered-did.md

**Claims extracted:** 14
**Verified independently:** 14 (forked claim-verifier)
**Outcome:** PARTIAL — 12 verified, 1 discrepancy, 1 unverifiable

### Discrepancies

- **C7** — draft claims "de Chaisemartin & D'Haultfœuille (2020) *propose* a DR estimator." Source Section 4 shows they propose a weighting estimator, not DR. Recommend correction.

### Unverifiable

- **C12** — draft cites "Borusyak et al. 2024 (working paper)". No canonical URL in provided sources. Recommend user supply DOI or arXiv link.

### Verified

| ID | Claim | Evidence |
|----|-------|----------|
| C1 | "Callaway & Sant'Anna 2021 use group-time ATT" | p. 5, eq. (3) |
| ... | ... | ... |
```

## Fail modes and recovery

**Verifier times out:** surface a warning block, return draft as provisional. Do not silently ship.

**Source material inaccessible** (paywall, 404): report the specific claims that hinge on it, flag as `cannot-verify`, recommend user supply an alternative source.

**Draft contains only opinions / forward-looking text:** report "no verifiable factual claims extracted — nothing to check" and return.

## Relationship to `/agentic-paper:validate-bib`

The two checks are complementary and neither substitutes for the other:

- **`/agentic-paper:validate-bib`** (same plugin) checks that citations **exist** and are well-formed — entry present, DOI resolves, no missing or unused keys.
- **`/agentic-paper:verify-claims`** checks that the citations **hold** — that what the draft *says about* a source is actually what the source says. "Smith (2019) shows a positive effect" becomes `{cite: Smith2019, attributed: "positive effect"}`, and the verifier independently answers whether that attribution survives contact with the paper.

A citation can pass `/agentic-paper:validate-bib` (the paper is real, the DOI resolves) and still fail `/agentic-paper:verify-claims` (the paper says the opposite of what you claimed).

---

## Cross-references

- [`agentic-paper:claim-verifier`](../../agents/claim-verifier.md) — the forked verifier.
- `.claude/rules/post-flight-verification.md` — the trigger rule (project scaffold, not shipped by this plugin).
- MEMORY.md `[LEARN:pattern]` on Chain-of-Verification vs critic-fixer vs cross-artifact review.


---

## When post-flight verification is mandatory

Any skill whose output contains factual claims verifiable against a source runs this protocol before returning: `/lit-review` and `/research-ideation` (citations, negative-literature claims, dataset and feasibility claims), `/agentic-paper:respond-to-referees` ("we added X on page Y"), `/agentic-paper:review-paper --peer` (novelty-probe claims), and any drafting skill that cites. Mechanical skills (`/compile-latex`, `/extract-tikz`, `/commit`) are exempt — a compiler already verifies their output.

Each such skill surfaces a Post-Flight block in its response: claims extracted, claims verified independently, outcome, and per-tier detail. The user must be able to see what was checked.

**Fail closed.** If the verifier errors, returns malformed output, or times out, do not silently ship the draft. Say so: "Post-Flight verification failed (…). Draft has not been independently checked. Treat the output as provisional." Verification discipline matters most exactly when things are going sideways.

**Opt-out.** `--no-verify` (in the calling skill) or `--no-fail-closed` (here) skips or downgrades the check — for speed-critical iteration, or when the user is reading the sources themselves. Document the opt-out in the calling skill's argument hints.
