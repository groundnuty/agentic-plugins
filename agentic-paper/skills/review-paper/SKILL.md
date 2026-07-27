---
name: review-paper
description: "Comprehensive manuscript review with three modes: single-pass (default), --adversarial critic-fixer loop, and --peer [journal] simulated peer-review pipeline (editor + 2 dispositioned referees + editorial decision, calibrated to a target journal). R&R continuation via --peer --r2/--r3; hostile-editor stress test via --peer --stress. Reviews referenced analysis scripts and runs /agentic-paper:audit-reproducibility on them unless --no-cross-artifact."
argument-hint: "[paper path] [--adversarial | --peer <journal> [--r2 | --r3 | --stress] [--no-novelty-check]] [--no-cross-artifact]"
allowed-tools: ["Read", "Grep", "Glob", "Write", "Edit", "Bash", "Task"]
---

<!-- Adapted from pedrohcgs/claude-code-my-workflow (MIT), https://github.com/pedrohcgs/claude-code-my-workflow -->


# Manuscript Review

Produce a thorough, constructive review of an academic manuscript — the kind of report a top-journal referee would write.

> **Which review skill do I want?**
>
> - **`/agentic-paper:review-paper`** (this skill) — single comprehensive report, optional `--adversarial` critic-fixer loop, or `--peer <journal>` simulated peer-review pipeline. Best for **most drafts**.
> - **`/agentic-paper:seven-pass-review`** — seven independent lenses in parallel (abstract, intro, methods, results, robustness, prose, citations) then synthesized. Heavier (7× token cost). Best for **submission-ready drafts** or **R&R stage** where you need maximum coverage.
> - **`/agentic-paper:respond-to-referees`** — if you already have referee comments and need a response document, not another review.
> - **`/slide-excellence`** — for lecture slides, not papers.

**Input:** `$ARGUMENTS` — path to a paper (`.tex`, `.md`, `.pdf`, `.docx`, `.qmd`, …), or a bare filename to resolve against the project's document directories. Optional flags:

- `--adversarial` — critic-fixer loop; runs until a round turns up nothing new (fallback cap: 5 rounds).
- `--peer <JOURNAL>` — simulated peer review pipeline calibrated to `<JOURNAL>`. If you maintain `.claude/references/journal-profiles.md` (built from `.claude/templates/journal-profile-template.md`), profiles there are used; otherwise the pipeline calibrates from general norms for the venue.
- `--r2` / `--r3` — R&R continuation mode (requires `--peer`). Reloads prior round, classifies concerns Resolved / Partial / Not addressed.
- `--stress` — hostile-editor stress test (requires `--peer`). Forces SKEPTIC dispositions, doubles critical peeves.
- `--no-novelty-check` — skip editor's WebSearch novelty probe (default is ON).
- `--no-cross-artifact` — skip the code review + `/agentic-paper:audit-reproducibility` of referenced scripts.

> **Already received referee comments?** Use [`/agentic-paper:respond-to-referees`](../respond-to-referees/SKILL.md) instead. That skill cross-references each referee concern against the revised manuscript and drafts a complete response document.

---

## Modes

### Default mode (single-pass)

One comprehensive review report. Fast, low token cost, suitable for early drafts where the author wants feedback and will iterate manually.

### Adversarial mode (`--adversarial`)

Iterative critic-fixer loop. The critic identifies issues, the fixer proposes and applies edits (with user approval), and a fresh-context critic re-audits. The loop runs **until dry** — until a round adds no new concerns — with a fallback round cap so a non-converging loop still terminates.

Use when: preparing a pre-submission draft, responding to a journal-desk rejection with substantive revisions, or after your own major rewrite. Costs more tokens but produces a manuscript the critic has signed off on.

### Peer-review mode (`--peer <JOURNAL>`)

Simulated editorial pipeline: **editor desk review → referee selection → 2 blind referees with different dispositions → editorial synthesis**. Calibrated to a target journal (from your `.claude/references/journal-profiles.md` if present, else general venue norms). Use when: pre-submission dress rehearsal, choosing between target journals, R&R planning.

This mode is materially different from `--adversarial`: adversarial runs the same critic 5× with fresh context; `--peer` runs **different personas** (editor + 2 dispositioned referees drawn from 6-way taxonomy: STRUCTURAL / CREDIBILITY / MEASUREMENT / POLICY / THEORY / SKEPTIC) whose priors are *deliberately different* and who are blind to each other.

**Agents used** (all reimplemented in this template; adapted from [Hugo Sant'Anna's clo-author](https://github.com/hugosantanna/clo-author) with permission):

- `agentic-paper:editor` — editor (desk review, referee selection, synthesis).
- `agentic-paper:domain-referee` — substance referee.
- `agentic-paper:methods-referee` — methodology referee (paper-type-aware).

**Sub-flags:**

- `--r2` / `--r3` — R&R mode. Skips fresh desk review; reloads prior round's reports; same referees + dispositions + peeves; classifies each prior concern as Resolved / Partial / Not addressed. Hard cap at `--r3` (no round 4+).
- `--stress` — Hostile editor. Forces both referees to SKEPTIC disposition, doubles critical peeves, framing: "you are looking for reasons to reject this paper." Output is a concern-list gauntlet, not a decision letter.
- `--no-novelty-check` — Disables the editor's WebSearch novelty probes (default is ON). Use in offline or hallucination-sensitive contexts. **Novelty-check caveat (document this to users):** WebSearch can return hallucinated citations or miss paywalled recent work. Always surface novelty-probe results as flags for manual verification, not verdicts.

---


## Steps (both modes)

1. **Locate and read the manuscript.** First strip flags (`--adversarial`, `--no-cross-artifact`) from `$ARGUMENTS` to get the bare manuscript path. Check:
   - Direct path (bare path from step 1)
   - `papers/$ARGUMENTS` and `input/$ARGUMENTS` (per `knowledge-work-structure.md`)
   - Glob for partial matches

2. **Read the full paper** end-to-end. For long PDFs, page through with the Read tool's `pages` parameter (up to 20 pages per request) — no pre-splitting needed. See `.claude/rules/pdf-processing.md`.

3. **Evaluate across 6 dimensions** (see below).

4. **Generate 3–5 "referee objections"** — the tough questions a top referee would ask.

5. **Produce the review report.**

6. **Save to** `.claude/session-reports/paper_review_[sanitized_name]_round[N].md` (N=1 in default mode; N increments in adversarial mode).

6b. **Cross-artifact integration.** Unless `$ARGUMENTS` contains `--no-cross-artifact`, and if the manuscript references analysis scripts (detected via `\input{scripts/...}`, `%% source:` comments, or filenames matching the analysis-outputs directory), auto-invoke:
   - a code review of each referenced script — read it and check it actually produces the claimed outputs (forked subagent, results to `.claude/session-reports/cross_artifact_[paper]/review_[script].md`)
   - `/agentic-paper:audit-reproducibility` on the manuscript + outputs dir (results to `.claude/session-reports/cross_artifact_[paper]/reproducibility.md`)

   Merge critical cross-artifact findings (code bug invalidates paper claim, reproducibility FAIL) into a new "Cross-Artifact Findings" section at the top of the paper review report. See "Cross-artifact protocol" at the end of this skill for the full contract.

7. **If `--adversarial` is in `$ARGUMENTS`:** invoke the critic-fixer loop defined in the next section. Otherwise stop here.

---

## Review Dimensions

### 1. Argument Structure
- Is the research question clearly stated?
- Does the introduction motivate the question effectively?
- Is the logical flow sound (question → method → results → conclusion)?
- Are the conclusions supported by the evidence?
- Are limitations acknowledged?

### 2. Identification Strategy
- Is the causal claim credible?
- What are the key identifying assumptions? Are they stated explicitly?
- Are there threats to identification (omitted variables, reverse causality, measurement error)?
- Are robustness checks adequate?
- Is the estimator appropriate for the research design?

### 3. Econometric Specification
- Correct standard errors (clustered? robust? bootstrap?)?
- Appropriate functional form?
- Sample selection issues?
- Multiple testing concerns?
- Are point estimates economically meaningful (not just statistically significant)?

### 4. Literature Positioning
- Are the key papers cited?
- Is prior work characterized accurately?
- Is the contribution clearly differentiated from existing work?
- Any missing citations that a referee would flag?

### 5. Writing Quality
- Clarity and concision
- Academic tone
- Consistent notation throughout
- Abstract effectively summarizes the paper
- Tables and figures are self-contained (clear labels, notes, sources)

### 6. Presentation
- Are tables and figures well-designed?
- Is notation consistent throughout?
- Are there any typos, grammatical errors, or formatting issues?
- Is the paper the right length for the contribution?

---

## Output Format

```markdown
# Manuscript Review: [Paper Title]

**Date:** [YYYY-MM-DD]
**Reviewer:** review-paper skill
**File:** [path to manuscript]

## Summary Assessment

**Overall recommendation:** [Strong Accept / Accept / Revise & Resubmit / Reject]

[2-3 paragraph summary: main contribution, strengths, and key concerns]

## Strengths

1. [Strength 1]
2. [Strength 2]
3. [Strength 3]

## Major Concerns

### MC1: [Title]
- **Dimension:** [Identification / Econometrics / Argument / Literature / Writing / Presentation]
- **Issue:** [Specific description]
- **Suggestion:** [How to address it]
- **Location:** [Section/page/table if applicable]

[Repeat for each major concern]

## Minor Concerns

### mc1: [Title]
- **Issue:** [Description]
- **Suggestion:** [Fix]

[Repeat]

## Referee Objections

These are the tough questions a top referee would likely raise:

### RO1: [Question]
**Why it matters:** [Why this could be fatal]
**How to address it:** [Suggested response or additional analysis]

[Repeat for 3-5 objections]

## Specific Comments

[Line-by-line or section-by-section comments, if any]

## Summary Statistics

| Dimension | Rating (1-5) |
|-----------|-------------|
| Argument Structure | [N] |
| Identification | [N] |
| Econometrics | [N] |
| Literature | [N] |
| Writing | [N] |
| Presentation | [N] |
| **Overall** | **[N]** |
```

---

## Principles

- **Be constructive.** Every criticism should come with a suggestion.
- **Be specific.** Reference exact sections, equations, tables.
- **Think like a referee at a top-5 journal.** What would make them reject?
- **Distinguish fatal flaws from minor issues.** Not everything is equally important.
- **Acknowledge what's done well.** Good research deserves recognition.
- **Do NOT fabricate details.** If you can't read a section clearly, say so.

---

## Adversarial Mode — Critic-Fixer Loop

**Only runs if `--adversarial` is in `$ARGUMENTS`.**

A **loop-until-dry** critic-fixer pattern: the critic emits typed findings, the fixer applies approved edits, a fresh-context critic re-audits, and the loop ends when a round surfaces nothing new. Papers get it because the single-pass review leaves authors doing manual fix-and-resubmit cycles.

### Flow

```
Phase 0: Pre-flight
  │
  ├─ Verify the manuscript compiles (xelatex / quarto render) if applicable
  ├─ Snapshot the pre-review version: git stash OR copy to a .review-backup/
  │
Phase 1: Critic audit (round N=1,2,3,...)
  │
  ├─ Run the default review above, producing a round-N report
  ├─ Diff round N's concerns against every prior round (dedup key:
  │  location + finding). If the round adds ZERO new CRITICAL/MAJOR
  │  concerns and ZERO new "fatal" Referee Objections:
  │     → VERDICT = APPROVED. Stop the loop. Write final summary.
  │  Else: continue.
  │
Phase 2: Fixer
  │
  ├─ For each Major Concern in the round-N report, produce a concrete
  │  proposed edit (diff or new text block).
  ├─ Present proposed edits to the user grouped by severity (Critical →
  │  Major → Minor). Ask for approval: "apply all", "apply critical+major
  │  only", "review each", or "abort".
  ├─ Apply approved edits with Edit / Edit tools.
  ├─ If the manuscript is a compile target (`.tex` / `.qmd`), re-compile
  │  and verify it still builds.
  │
Phase 3: Re-audit
  │
  └─ Spawn a FRESH-CONTEXT subagent (via Task, `subagent_type` set to
     general-purpose) to re-read the paper and produce a round-(N+1)
     report. Fresh context prevents anchoring bias — the new reviewer
     sees the edited paper, not the diff.
     → Jump back to Phase 1.
```

### Iteration limits — loop-until-dry

The loop is **not** a fixed round count. Each critic round returns typed findings —

```yaml
findings:
  - severity: CRITICAL | MAJOR | MINOR
    location: <section, page, table, or line>
    finding: <one sentence — what is wrong>
    evidence: <quote or number lifted from the manuscript>
    change_my_mind: <what would make this concern go away>
```

— and the loop **converges when a round adds 0 new CRITICAL/MAJOR concerns**, deduped on `location` + `finding`. A round that only restates concerns already on the table is a converged round, even if the raw count is non-zero.

- **Convergence (the normal exit):** APPROVED once a round adds no new CRITICAL/MAJOR concerns and no new fatal Referee Objections.
- **Fallback cap:** 5 rounds bounds a loop that refuses to converge. After round 5, halt and list what remains. This is a backstop, not the expected ending — if you routinely hit it, the manuscript needs a rewrite, not another round.
- **Two-strikes:** if the same Concern label appears in rounds N and N+2, flag as "author disagreement" and let the user decide (keep-as-is with rationale vs. another fix attempt).
- **Budget escape:** if cumulative token cost across rounds exceeds ~200k, warn and let the user cap further rounds. This is a spend ceiling, not a context-window limit — each re-audit runs in fresh context.

### Stopping criteria

| Condition | Action |
|---|---|
| Round adds 0 new CRITICAL/MAJOR concerns and 0 new fatal Referee Objections | APPROVED (converged) — final summary |
| Fallback cap (5 rounds) reached without converging | HALTED — list remaining concerns, user decides |
| User approves zero fixes in a round | HALTED — user signals "I disagree with this review" |
| Compile fails after applied fixes | ROLLED BACK to pre-round-N snapshot, report compile error, user decides |

### Final report

After the loop ends, write `.claude/session-reports/paper_review_[sanitized_name]_FINAL.md`:

```markdown
# Final Review: [Paper Title]

**Rounds:** N
**Verdict:** APPROVED (converged) | HALTED (fallback cap) | HALTED (user override) | ROLLED BACK
**Token cost estimate:** ~XXk

## Round Summary
| Round | Major Concerns | Fatal Objections | Status |
|---|---|---|---|
| 1 | 7 | 2 | Fixed 5, deferred 2 |
| 2 | 3 | 1 | ...              |
| ... | ... | ... | ...         |
| N | 0 | 0 | APPROVED        |

## Changes Applied
[link to git diff between the pre-round-1 snapshot and HEAD]

## Remaining Concerns (if HALTED)
[list with severity + rationale]

## Next Steps
[recommended action: submit / one more pass / substantial revision]
```

### When NOT to use adversarial mode

- Early exploratory drafts (the loop forces premature polish on ideas still being shaped)
- Papers you don't yet have compilable source for (can't verify edits)
- When you'd rather get ONE opinion and decide for yourself (adversarial-mode enforces "critic signed off" semantics — that's sometimes the wrong frame)

---

## `--peer [journal]` workflow detail

### Phase 0: Cross-artifact pre-flight (runs BEFORE desk review in --peer mode)

Unless `--no-cross-artifact` is set, auto-invoke `/agentic-paper:audit-reproducibility` on the manuscript + its outputs directory *first*. Any reproducibility FAIL becomes desk-reject-worthy evidence the editor can cite. See "Cross-artifact protocol" at the end of this skill.

Reports: `.claude/session-reports/cross_artifact_[paper]/reproducibility.md`.

**Novelty-probe Post-Flight (new in v1.7.0).** The editor's novelty probe uses `WebSearch` to check whether the paper's contribution has been made before. WebSearch results can be hallucinated — fabricated prior work, misattributed findings, wrong years. Before the editor's desk review incorporates novelty-probe claims into its decision, those claims must pass Post-Flight Verification per [`/agentic-paper:verify-claims`](../verify-claims/SKILL.md):

1. The editor collects novelty-probe claims (e.g., "Smith 2022 already showed this exact result").
2. Spawn `claim-verifier` via `Task` with `subagent_type=agentic-paper:claim-verifier` and `context=fork`, passing the claims + verification questions + candidate source URLs. Forked fresh context is the CoVe independence trick.
3. Only verified claims are allowed into the desk-review narrative. Unverified claims are surfaced separately as "editor could not verify — manual check recommended" rather than presented as established prior work.

Opt-out: `--no-novelty-check` already skips the probe entirely. If the probe runs, Post-Flight is mandatory.

**Pre-Flight Report (required before Phase 1).** Before spawning the editor, output a Pre-Flight Report so the user can verify the inputs are read correctly:

```markdown
## Pre-Flight Report — /agentic-paper:review-paper --peer

**Manuscript:** [path] — [page count, last modified]
**Target journal:** [JOURNAL_SHORT] → [full name]
**Journal profile loaded:** [yes — from `.claude/references/journal-profiles.md`, key adjustments; or no — calibrated from general venue norms]
**Cross-artifact scripts found:** [list referenced .R / .py / .do files]
**Reproducibility status:** [PASS / FAIL from Phase 0] — [N of M claims within tolerance]
**Round:** [fresh / r2 / r3 / stress]
```

If the manuscript path doesn't exist or a referenced cross-artifact script is missing, stop and surface the issue before proceeding. A missing journal profile is **not** a stop condition — calibrate from general venue norms and note it.

### Phase 1: Editor desk review

Spawn forked subagent `editor` with the manuscript path and `--peer <JOURNAL>` context. Editor:
- Loads the journal profile if `.claude/references/journal-profiles.md` exists → states "Calibrated to: [journal]" (or notes calibration from general venue norms).
- Reads abstract + intro + methods overview + headline results.
- Runs novelty probes (unless `--no-novelty-check`).
- Either **DESK REJECT** (pipeline terminates with rejection letter) or **SEND OUT**.

Report: `.claude/session-reports/peer_review_[paper]/desk_review.md`.

### Phase 1b: Referee selection (inside editor)

Editor draws 2 DIFFERENT dispositions from journal's Referee-pool weights and assigns each referee 1 critical + 1 constructive peeve (stress mode: 2 critical + 1 constructive). Appended to `desk_review.md`.

### Phase 2: Two parallel referees, blind to each other

Spawn in parallel:
- Forked subagent `domain-referee` with disposition D1, peeves P1 → `referee_domain.md`.
- Forked subagent `methods-referee` with disposition D2, peeves P2 → `referee_methods.md`.

Each referee must include "What would change my mind: [specific ask]" on every MAJOR concern.

### Phase 3: Editor synthesis (reduce → judge, with the hallucination gate)

Read both referee reports. **Reduce** their findings: classify each MAJOR concern as FATAL / ADDRESSABLE / TASTE, then produce the editorial decision using the decision rule table in `editor.md`. The decision is a function of what the referees found — the editor is a reducer, not a third referee.

**Post-judge hallucination gate.** The editor may **not** desk-reject or escalate the decision on a CRITICAL reason **neither referee raised**. Any editor-introduced blocker that is not traceable to a referee finding must either be re-verified in a fresh `claim-verifier` fork (`Task` with `subagent_type=agentic-paper:claim-verifier` and `context=fork`, which has never seen the referee reports and so cannot self-confirm), or be dropped, labeled `[JUDGE-HALLUCINATED]` in the decision letter, and the decision recomputed without it. The gate is one-directional: the editor may always downgrade, de-duplicate, or reclassify a referee's concern. See [`/agentic-paper:verify-claims`](../verify-claims/SKILL.md).

Report: `.claude/session-reports/peer_review_[paper]/editorial_decision.md`.

### Phase 4: Summary

Tell the user:
- Final decision (Accept / Minor / Major / Reject / Desk Reject)
- Token usage + wall-clock time
- Paths to all 4 reports (desk_review, referee_domain, referee_methods, editorial_decision)

---

## Output layout for `--peer` mode

```
.claude/session-reports/
  peer_review_[sanitized_paper_name]/
    desk_review.md                       # Phase 1 + Phase 1b
    referee_domain.md                    # Phase 2 (parallel)
    referee_methods.md                   # Phase 2 (parallel)
    editorial_decision.md                # Phase 3
    (R&R rounds: desk_review_r2.md, referee_domain_r2.md, ...)
  cross_artifact_[sanitized_paper_name]/
    reproducibility.md                   # Phase 0
    review_r_*.md                        # Phase 0 (one per referenced script)
```

---

## Field adaptation

This template ships **no** journal profiles — the pipeline is field-agnostic and calibrates from general venue norms out of the box. To pin the calibration for venues you submit to, copy `.claude/templates/journal-profile-template.md`, fill in the schema, and save the result as `.claude/references/journal-profiles.md`. Only the calibration data is field-specific; the pipeline is not.

For non-econ paper types in `methods-referee.md`, extend the paper-type list (e.g., biology: `observational / experimental / computational / review`).


---

## Cross-artifact protocol (the full contract)

A paper's claims depend on the code that produced them, so reviewing the manuscript without the code reviews half the artifact. A bug in `02_clean` invalidates Table 2, and reading `manuscript.tex` alone cannot see it.

**Detection is pattern-based and deliberately conservative** — a theory paper that happens to live in a repo containing scripts must not trigger this. Signals:

- `\input{scripts/...}` or `\input{tables/...}`
- `%% source: scripts/03_analyze.R` (or `.py`, `.do`, `.jl`, …) comments
- Numeric claims in the text (estimates, coefficients, N, p-values) **combined with** a sibling `scripts/` directory
- Table labels matching filenames under `scripts/**/_outputs/`

If none are present, no cross-artifact work happens and `--no-cross-artifact` is a no-op.

**Steps.**

1. Build the list of scripts that produced content in this paper.
2. Review each in a forked subagent — read it and verify it actually produces the claimed outputs, in whatever language it is written (R, Python, Stata, Julia, shell). This is correctness of the paper's numeric claims, not style. Save to `.claude/session-reports/cross_artifact_[paper]/review_[script].md`. (This template ships no language-specific code-review skill; if you have added one for your stack, invoke it here, otherwise review directly.)
3. Run `/agentic-paper:audit-reproducibility $manuscript scripts/**/_outputs/` once, saving to `.../reproducibility.md`.
4. Add a **Cross-Artifact Findings** section at the top of the review report: scripts reviewed, reproducibility PASS/FAIL (k of m claims within tolerance), code-quality counts, then three tables — critical paper+code issues (paper claim / code location / issue), code-only issues (follow-up, non-blocking), paper-only issues.

**Escalation.** An `/agentic-paper:audit-reproducibility` FAIL on tolerance becomes CRITICAL in the paper review. A code CRITICAL that affects a paper claim escalates the same way. A code CRITICAL unrelated to any paper claim is filed as a separate action item.

**Out of scope:** running R / Stata / Python / Julia (that is `/agentic-paper:audit-reproducibility`'s job — it reads existing outputs), git-blame archaeology, and judging whether the authors write good code as distinct from whether their *results* are defensible. The results come first.

**Ordering.** `--peer` runs cross-artifact as Phase 0, before the editor's desk review, so the editor holds reproducibility evidence when deciding. Default and `--adversarial` run it at Step 6b, after the paper review. Both orderings are valid.
