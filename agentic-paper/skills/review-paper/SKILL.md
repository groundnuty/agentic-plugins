---
name: review-paper
description: "Comprehensive manuscript review with three modes: single-pass (default), --adversarial critic-fixer loop, and --peer [journal] simulated peer-review pipeline (editor + 2 dispositioned referees + editorial decision, calibrated to a target journal). R&R continuation via --peer --r2/--r3; hostile-editor stress test via --peer --stress. Reviews referenced analysis scripts and runs /agentic-paper:audit-reproducibility on them unless --no-cross-artifact."
argument-hint: "[paper path] [--adversarial | --peer <journal> [--r2 | --r3 | --stress] [--no-novelty-check]] [--no-cross-artifact]"
allowed-tools: ["Read", "Grep", "Glob", "Write", "Edit", "Bash", "Agent", "Task"]
---

<!-- Adapted from pedrohcgs/claude-code-my-workflow (MIT), https://github.com/pedrohcgs/claude-code-my-workflow -->


# Manuscript Review

Produce a thorough, constructive review of an academic manuscript — the kind of report a top-journal referee would write.

> **Which review skill do I want?**
>
> - **`/agentic-paper:review-paper`** (this skill) — single comprehensive report, optional `--adversarial` critic-fixer loop, or `--peer <journal>` simulated peer-review pipeline. Best for **most drafts**.
> - **`/agentic-paper:seven-pass-review`** — seven independent lenses in parallel (abstract, intro, methods, results, robustness, prose, citations) then synthesized. Heavier (7× token cost). Best for **submission-ready drafts** or **R&R stage** where you need maximum coverage.
> - **`/agentic-paper:respond-to-referees`** — if you already have referee comments and need a response document, not another review.

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

Choose the mode from the flags, and read that mode's file before you start it:

| Flags | Mode | Read first |
|---|---|---|
| none | **Default** — one review report | nothing more: follow Steps 1–6b below |
| `--adversarial` | **Critic-fixer loop** until a round adds nothing new (fallback cap: 5 rounds) | [ADVERSARIAL.md](ADVERSARIAL.md), before Step 1 |
| `--peer <JOURNAL>` (plus `--r2` / `--r3` / `--stress`) | **Simulated peer review** — editor + 2 blind referees, calibrated to the journal | [PEER.md](PEER.md), before its Phase 0 (after Step 1 here) |

Cross-artifact review runs in every mode unless `--no-cross-artifact` is set: read [CROSS-ARTIFACT.md](CROSS-ARTIFACT.md) before Step 6b (default, `--adversarial`) or before `--peer` Phase 0.

### Default mode (single-pass)

One comprehensive review report. Fast, low token cost, suitable for early drafts where the author wants feedback and will iterate manually.

### Adversarial mode (`--adversarial`)

Iterative critic-fixer loop. The critic identifies issues, the fixer proposes and applies edits (with user approval), and a fresh-context critic re-audits. The loop runs **until dry** — until a round adds no new concerns — with a fallback round cap so a non-converging loop still terminates.

Use when: preparing a pre-submission draft, responding to a journal-desk rejection with substantive revisions, or after your own major rewrite. Costs more tokens but produces a manuscript the critic has signed off on.

### Peer-review mode (`--peer <JOURNAL>`)

Simulated editorial pipeline: **editor desk review → referee selection → 2 blind referees with different dispositions → editorial synthesis**. Calibrated to a target journal (from your `.claude/references/journal-profiles.md` if present, else general venue norms). Use when: pre-submission dress rehearsal, choosing between target journals, R&R planning.

This mode is materially different from `--adversarial`: adversarial re-runs one critic, in a fresh context each round, until a round turns up nothing new (5-round fallback cap); `--peer` runs **different personas** (editor + 2 referees with dispositions chosen from a 6-way taxonomy: STRUCTURAL / CREDIBILITY / MEASUREMENT / POLICY / THEORY / SKEPTIC) whose priors are *deliberately different* and who are blind to each other.

**Agents used** (all reimplemented in this template; adapted from [Hugo Sant'Anna's clo-author](https://github.com/hugosantanna/clo-author) with permission):

- `agentic-paper:editor` — editor (desk review, referee selection, synthesis).
- `agentic-paper:domain-referee` — substance referee.
- `agentic-paper:methods-referee` — methodology referee (paper-type-aware).

**Sub-flags:**

- `--r2` / `--r3` — R&R mode. Skips fresh desk review; reloads prior round's reports; same referees + dispositions + peeves; classifies each prior concern as Resolved / Partial / Not addressed. Hard cap at `--r3` (no round 4+).
- `--stress` — Hostile editor. Forces both referees to SKEPTIC disposition, doubles critical peeves, framing: "you are looking for reasons to reject this paper." Output is a concern-list gauntlet, not a decision letter.
- `--no-novelty-check` — Disables the editor's WebSearch novelty probes (default is ON). Use in offline or hallucination-sensitive contexts. **Novelty-check caveat (document this to users):** WebSearch can return hallucinated citations or miss paywalled recent work. Always surface novelty-probe results as flags for manual verification, not verdicts.

**Two verification gates, run by this skill, not by the editor.** The editor agent has no `Agent` tool, so it cannot dispatch a verifier. After the editor's Phase 1 run and after its Phase 3 run, you run the matching gate yourself, exactly as PEER.md describes:

1. **Gate 1, novelty-probe verification (after Phase 1):** every prior-work claim from the editor's novelty probes goes to `agentic-paper:claim-verifier`; a desk reject that rests on an unconfirmed claim sends the editor back to redo its verdict.
2. **Gate 2, post-judge hallucination gate (after Phase 3):** every FATAL or ADDRESSABLE concern that no referee raised is verified or dropped as `[JUDGE-HALLUCINATED]`, and the editor recomputes its decision without it.

Both gates dispatch the verifier by name, so it starts with a fresh context. Never use the `fork` subagent type for them: a fork inherits this conversation and turns the check into self-confirmation.

Re-read the gate's section of [PEER.md](PEER.md) right before you run it, even if you read the file earlier. A long `--peer` run can hit context compaction, which re-attaches this file but keeps only a summary of what you read from PEER.md.

---


## Steps (default and `--adversarial` modes; `--peer` follows [PEER.md](PEER.md) after Step 1)

1. **Locate and read the manuscript.** First strip every flag (and the journal name after `--peer`) from `$ARGUMENTS` to get the bare manuscript path. Check:
   - Direct path (bare path from step 1)
   - `papers/$ARGUMENTS` and `input/$ARGUMENTS` (the layout in the "Knowledge-work directory structure" section of the project's AGENTS.md)
   - Glob for partial matches

2. **Read the full paper** end-to-end. For long PDFs, page through with the Read tool's `pages` parameter (up to 20 pages per request) — no pre-splitting needed. See `.claude/rules/pdf-processing.md`.

3. **Evaluate across 6 dimensions** (see below).

4. **Generate 3–5 "referee objections"** — the tough questions a top referee would ask.

5. **Produce the review report.**

6. **Save to** `.claude/session-reports/paper_review_[sanitized_name]_round[N].md` (N=1 in default mode; N increments in adversarial mode).

6b. **Cross-artifact integration.** Unless `$ARGUMENTS` contains `--no-cross-artifact`, and if the manuscript references analysis scripts (detected via `\input{scripts/...}`, `%% source:` comments, or filenames matching the analysis-outputs directory), auto-invoke:
   - a code review of each referenced script — read it and check it actually produces the claimed outputs (a fresh general-purpose subagent, not the `fork` type; results to `.claude/session-reports/cross_artifact_[paper]/review_[script].md`)
   - `/agentic-paper:audit-reproducibility` on the manuscript + outputs dir (results to `.claude/session-reports/cross_artifact_[paper]/reproducibility.md`)

   Merge critical cross-artifact findings (code bug invalidates paper claim, reproducibility FAIL) into a new "Cross-Artifact Findings" section at the top of the paper review report. Read [CROSS-ARTIFACT.md](CROSS-ARTIFACT.md) before this step: it holds the full contract (detection signals, escalation, what is out of scope).

7. **If `--adversarial` is in `$ARGUMENTS`:** continue the critic-fixer loop in [ADVERSARIAL.md](ADVERSARIAL.md) from its Phase 1 convergence check, with this report as round 1. Re-read ADVERSARIAL.md at the start of every round: compaction re-attaches this file, not that one. Otherwise stop here.

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

## Field adaptation

This template ships **no** journal profiles — the pipeline is field-agnostic and calibrates from general venue norms out of the box. To pin the calibration for venues you submit to, copy `.claude/templates/journal-profile-template.md`, fill in the schema, and save the result as `.claude/references/journal-profiles.md`. Only the calibration data is field-specific; the pipeline is not.

To add paper types for your field (e.g., biology: `observational / experimental / computational / review`), list them in `.claude/references/paper-types.md`, each with its dimensions and weights; `agentic-paper:methods-referee` reads that file when it exists. Do not edit the plugin's own files for this: the plugin cache is version-pinned and replaced on every update.
