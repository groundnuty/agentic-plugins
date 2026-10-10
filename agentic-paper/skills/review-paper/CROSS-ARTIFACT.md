# Cross-artifact protocol (the full contract)

Read this file before Step 6b of SKILL.md (default and `--adversarial` modes) or before Phase 0 of [PEER.md](PEER.md) (`--peer`). Skip it when `--no-cross-artifact` is set.

A paper's claims depend on the code that produced them, so reviewing the manuscript without the code reviews half the artifact. A bug in `02_clean` invalidates Table 2, and reading `manuscript.tex` alone cannot see it.

**Detection is pattern-based and deliberately conservative** — a theory paper that happens to live in a repo containing scripts must not trigger this. Signals:

- `\input{scripts/...}` or `\input{tables/...}`
- `%% source: scripts/03_analyze.R` (or `.py`, `.do`, `.jl`, …) comments
- Numeric claims in the text (estimates, coefficients, N, p-values) **combined with** a sibling `scripts/` directory
- Table labels matching filenames under `scripts/**/_outputs/`

If none are present, no cross-artifact work happens and `--no-cross-artifact` is a no-op.

**Steps.**

1. Build the list of scripts that produced content in this paper.
2. Review each in a fresh subagent (general-purpose, not the `fork` type) — read it and verify it actually produces the claimed outputs, in whatever language it is written (R, Python, Stata, Julia, shell). This is correctness of the paper's numeric claims, not style. Save to `.claude/session-reports/cross_artifact_[paper]/review_[script].md`. (This template ships no language-specific code-review skill; if you have added one for your stack, invoke it here, otherwise review directly.)
3. Run `/agentic-paper:audit-reproducibility $manuscript scripts/**/_outputs/` once, saving to `.../reproducibility.md`.
4. Add a **Cross-Artifact Findings** section at the top of the review report: scripts reviewed, reproducibility PASS/FAIL (k of m claims within tolerance), code-quality counts, then three tables — critical paper+code issues (paper claim / code location / issue), code-only issues (follow-up, non-blocking), paper-only issues.

**Escalation.** An `/agentic-paper:audit-reproducibility` FAIL on tolerance becomes CRITICAL in the paper review. A code CRITICAL that affects a paper claim escalates the same way. A code CRITICAL unrelated to any paper claim is filed as a separate action item.

**Out of scope:** running R / Stata / Python / Julia (that is `/agentic-paper:audit-reproducibility`'s job — it reads existing outputs), git-blame archaeology, and judging whether the authors write good code as distinct from whether their *results* are defensible. The results come first.

**Ordering.** `--peer` runs cross-artifact as Phase 0, before the editor's desk review, so the editor holds reproducibility evidence when deciding. Default and `--adversarial` run it at Step 6b, after the paper review. Both orderings are valid.
