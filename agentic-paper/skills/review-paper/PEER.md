# `--peer <JOURNAL>` workflow

Read this file before Phase 0 of `/agentic-paper:review-paper --peer <JOURNAL>`. It is the whole pipeline:

Phase 0 → Pre-Flight Report → Phase 1 (editor) → **Gate 1** → Phase 2 (referees) → Phase 3 (editor) → **Gate 2** → Phase 4

**Who does what.** This skill is the orchestrator: it dispatches every agent and runs both verification gates itself. The agents only read and write their own reports. The editor has no `Agent` tool, so it cannot dispatch the verifier; that is why the gates are steps you run after each editor run. Neither gate is optional.

Every report goes under `.claude/session-reports/peer_review_[sanitized_paper_name]/` (layout at the end of this file).

## Contents

- Phase 0: Cross-artifact pre-flight
- Pre-Flight Report
- Phase 1: Editor desk review and referee selection
- Gate 1: Novelty-probe verification
- Phase 2: Two referees, blind to each other
- Phase 3: Editorial decision
- Gate 2: Post-judge hallucination gate
- Phase 4: Summary
- R&R rounds and stress mode
- Output layout

## Phase 0: Cross-artifact pre-flight

Unless `--no-cross-artifact` is set, run the protocol in [CROSS-ARTIFACT.md](CROSS-ARTIFACT.md) *before* the desk review, so any reproducibility FAIL is evidence the editor can cite. Reports: `.claude/session-reports/cross_artifact_[paper]/reproducibility.md`, plus one `review_[script].md` per referenced script.

## Pre-Flight Report

Before dispatching the editor, output a Pre-Flight Report so the user can check the inputs were read correctly:

```markdown
## Pre-Flight Report — /agentic-paper:review-paper --peer

**Manuscript:** [path] — [page count, last modified]
**Target journal:** [JOURNAL_SHORT] → [full name]
**Journal profile loaded:** [yes — from `.claude/references/journal-profiles.md`, key adjustments; or no — calibrated from general venue norms]
**Cross-artifact scripts found:** [list referenced .R / .py / .do files]
**Reproducibility status:** [PASS / FAIL from Phase 0] — [N of M claims within tolerance]
**Round:** [fresh / r2 / r3 / stress]
```

If the manuscript path doesn't exist or a referenced cross-artifact script is missing, stop and surface the issue before proceeding. A missing journal profile is **not** a stop condition: calibrate from general venue norms and note it.

## Phase 1: Editor desk review and referee selection

Dispatch the `agentic-paper:editor` subagent (named, so it starts fresh) with the manuscript path, the journal, the round (fresh or stress), whether novelty probes are on, and the Phase 0 report path. In one run the editor:

- loads the journal profile if `.claude/references/journal-profiles.md` has one, and otherwise calibrates from general venue norms and says so;
- reads the abstract, introduction, methods overview and headline results;
- runs the novelty probes (unless `--no-novelty-check`) and marks each prior-work finding *unverified*;
- decides **DESK REJECT** or **SEND OUT**. On SEND OUT it also chooses two different referee dispositions and their peeves, each with a one-line reason, in the Referee Selection section.

Output: `desk_review.md`.

## Gate 1: Novelty-probe verification

Run this after Phase 1 and before you act on its verdict, whether that means stopping on a DESK REJECT or starting Phase 2. The probes come from `WebSearch`, which can return fabricated prior work, misattributed findings or wrong years, so no novelty claim reaches the verdict until it passes Post-Flight Verification per [`/agentic-paper:verify-claims`](../verify-claims/SKILL.md).

1. Read the **Novelty probes** table in `desk_review.md`. Collect every row that reports prior work: "already done", an overlap, or a close cousin the authors should cite. If there are none (all clear, or the probes were skipped), the gate passes.
2. Dispatch `claim-verifier` with the `Agent` tool (`subagent_type: agentic-paper:claim-verifier`), passing each claim (e.g., "Smith 2022 already showed this exact result"), a verification question for it, and the URL or DOI the editor gave. A named subagent starts with a fresh context and has never seen this conversation. **Never use the `fork` subagent type here:** a fork inherits the whole conversation, draft included, and the check turns into self-confirmation. The fresh context is the CoVe independence trick.
3. Save the verifier's report as `novelty_verification.md`; the verifier has no Write tool. A claim counts as confirmed only when its `Match?` is `yes`.
4. Act on the result:
   - **The verdict is DESK REJECT and its reason rests on a claim that was not confirmed** (typically "Already done"): dispatch `agentic-paper:editor` again, fresh, with the same inputs plus `novelty_verification.md`. Ask it to redo Phase 1 and treat those claims as "editor could not verify — manual check recommended", not as prior work. It rewrites `desk_review.md`, with Referee Selection if the new verdict is SEND OUT. If the new run reports prior work that was not in the first one, run steps 2–3 on those claims only.
   - **Otherwise:** append a **Novelty verification** section to `desk_review.md` listing each claim with its outcome, and label each unconfirmed one "editor could not verify — manual check recommended". Only confirmed claims are presented to the user as established prior work.

## Phase 2: Two referees, blind to each other

Only on SEND OUT. Read the Referee Selection section of `desk_review.md`, then dispatch both referees in one message so they run in parallel:

- `agentic-paper:domain-referee` with disposition D1 and its peeves → `referee_domain.md`
- `agentic-paper:methods-referee` with disposition D2 and its peeves → `referee_methods.md`

Give each the manuscript path, the journal, and the path to `desk_review.md`. Never give one referee the other's report. Each referee writes its own report and must include "What would change my mind: [specific ask]" on every MAJOR concern.

## Phase 3: Editorial decision

Dispatch `agentic-paper:editor` again (fresh) for its Phase 3, passing the paths to `desk_review.md`, `referee_domain.md` and `referee_methods.md`. The editor is a reducer, not a third referee: it classifies each MAJOR concern as FATAL / ADDRESSABLE / TASTE, names the source of each in the *From* column (Referee A, Referee B, or Editor), and applies the decision rule in its own instructions. Output: `editorial_decision.md`.

## Gate 2: Post-judge hallucination gate

The editor may **not** desk-reject or escalate the decision on a CRITICAL reason **neither referee raised**. Enforce that here, after Phase 3:

1. Read `editorial_decision.md` (in R&R rounds, this round's `editorial_decision_r2.md` / `_r3.md`). List every FATAL or ADDRESSABLE row whose *From* column names no referee (Editor, or blank). If there are none, the gate passes.
2. For each row, dispatch a fresh `claim-verifier` (the `Agent` tool with `subagent_type: agentic-paper:claim-verifier` — never the `fork` type, which would inherit the referee reports and self-confirm). Pass the concern as the claim, the manuscript as the source material, and a question such as "Does the manuscript have this problem at <location>?". See [`/agentic-paper:verify-claims`](../verify-claims/SKILL.md).
3. A row whose `Match?` is `yes` stays. If any row was not confirmed, dispatch `agentic-paper:editor` again (fresh) with the same three report paths and the list of unconfirmed rows. Ask it to move those rows to a **Dropped by the hallucination gate** list labeled `[JUDGE-HALLUCINATED]`, recompute the decision from its decision rule without them, and rewrite `editorial_decision.md`. Then read the file and check that the dropped rows no longer count toward the decision. If the re-run added Editor rows that were not in the previous version, run steps 2–3 on those rows only; rows already checked are not checked again.

The gate runs in one direction only: the editor may always downgrade, de-duplicate or reclassify a referee's concern. Only blockers the editor introduced are checked.

## Phase 4: Summary

Tell the user:

- Final decision (Accept / Minor / Major / Reject / Desk Reject), and what either gate changed: claims not confirmed, rows dropped as `[JUDGE-HALLUCINATED]`.
- Token usage + wall-clock time
- Paths to all reports (desk_review, novelty_verification if Gate 1 ran, referee_domain, referee_methods, editorial_decision)

## R&R rounds and stress mode

- **`--r2` / `--r3`:** skip Phase 1 and Gate 1. Read the prior round's `desk_review.md` and reuse its dispositions and peeves unchanged. In Phase 2, give each referee the revised manuscript and its own prior report; it classifies each prior concern as Resolved / Partial / Not addressed. Phase 3 and Gate 2 run as usual. Every report written this round carries the `_r2` / `_r3` suffix. `--r3` is the last round (no round 4+); its decision is Accept / Minor Rev / Reject.
- **`--stress`:** pass `--stress` to the editor in Phase 1. It forces both referees to SKEPTIC with 2 critical + 1 constructive peeves each, and frames itself as "looking for reasons to reject this paper". In Phase 3 it writes a concern list the author must prepare to defend, not a decision letter. Gate 2 still applies to that list.

## Output layout

```
.claude/session-reports/
  peer_review_[sanitized_paper_name]/
    desk_review.md                       # Phase 1 (+ Novelty verification from Gate 1)
    novelty_verification.md              # Gate 1, when it ran
    referee_domain.md                    # Phase 2 (parallel)
    referee_methods.md                   # Phase 2 (parallel)
    editorial_decision.md                # Phase 3, amended by Gate 2
    (R&R rounds: referee_domain_r2.md, referee_methods_r2.md, editorial_decision_r2.md, ...)
  cross_artifact_[sanitized_paper_name]/
    reproducibility.md                   # Phase 0
    review_[script].md                   # Phase 0 (one per referenced script)
```
