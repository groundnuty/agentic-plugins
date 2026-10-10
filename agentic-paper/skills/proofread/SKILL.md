---
name: proofread
description: Proofreading pass over manuscript `.tex`, `.qmd` or `.md` files. Checks grammar, typos, overflow, terminology consistency, and academic writing quality; writes a report of proposed fixes without editing the manuscript. Use when user says "proofread", "check for typos", "look for grammar issues", "copy-edit this", "any writing errors?", or before submitting a paper.
argument-hint: "[filename or 'all']"
allowed-tools: ["Read", "Grep", "Glob", "Write", "Agent", "Task"]
disallowed-tools: ["Edit", "MultiEdit"]
---

<!-- Adapted from pedrohcgs/claude-code-my-workflow (MIT), https://github.com/pedrohcgs/claude-code-my-workflow -->


# Proofread Manuscript Files

Run the mandatory proofreading protocol on paper/manuscript files. This produces a report of all issues found WITHOUT editing any source files.

## Steps

1. **Identify files to review:**
   - If `$ARGUMENTS` is a specific filename: review that file only
   - If `$ARGUMENTS` is "all": review all paper/manuscript files in `**/*.tex`, `**/*.qmd` and `**/*.md`

2. **For each file, launch the `agentic-paper:proofreader` subagent** (named, so it starts fresh — never the `fork` type). It checks for:

   **GRAMMAR:** Subject-verb agreement, articles (a/an/the), prepositions, tense consistency
   **TYPOS:** Misspellings, search-and-replace artifacts, duplicated words
   **OVERFLOW:** Overfull hbox (LaTeX), content overflowing the rendered page or column (Quarto / Markdown)
   **CONSISTENCY:** Citation format, notation, terminology
   **ACADEMIC QUALITY:** Informal language, missing words, awkward constructions

3. **The proofreader writes a detailed report** for each file listing every finding with:
   - Location (line number or section heading)
   - Current text (what's wrong)
   - Proposed fix (what it should be)
   - Category and severity

4. **The proofreader saves each report** — this skill does not write it a second time — to `.claude/session-reports/`:
   - For `.tex` and `.md` files: `.claude/session-reports/FILENAME_report.md`
   - For `.qmd` files: `.claude/session-reports/FILENAME_qmd_report.md`

5. **Write only the reports; leave every source file unchanged.**
   Fixes are applied separately, after the user has reviewed the report and approved them (see "The full protocol" below).

6. **Read the saved reports and present a summary** to the user:
   - Total issues found per file
   - Breakdown by category
   - Most critical issues highlighted


---

## The full protocol: propose → approve → apply

This skill is the **propose** step and deliberately stops there. A proofreading pass writes only its report and proposes every change in it for the user to approve: this skill disallows `Edit` and `MultiEdit`, and `Write` — here and in the `agentic-paper:proofreader` agent — is for the report alone, never for a source file. Never change manuscript prose without showing the proposed change first.

**Approve.** The user reads the report and accepts all of it, accepts selectively, or asks for modifications. Nothing is written until they say so. Silence is not approval.

**Apply.** Back in the session, apply only the approved items — `replace_all: true` for an issue with many identical instances — verify each edit landed, and report what was applied and what was skipped.
