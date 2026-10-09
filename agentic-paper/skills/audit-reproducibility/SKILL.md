---
name: audit-reproducibility
description: Cross-check numeric claims in a manuscript against the actual outputs produced by the analysis pipeline. Report PASS/FAIL per claim against tolerance thresholds. Use before submission and before releasing a replication package.
argument-hint: "[manuscript path] [outputs-dir] (outputs-dir defaults to the project's analysis-outputs directory)"
allowed-tools: ["Read", "Grep", "Glob", "Write", "Bash", "Agent", "Task"]
---

<!-- Adapted from pedrohcgs/claude-code-my-workflow (MIT), https://github.com/pedrohcgs/claude-code-my-workflow -->


# Audit Reproducibility

Compare numeric claims in a manuscript (point estimates, standard errors, p-values, counts) against the actual outputs produced by the analysis pipeline. Report PASS / FAIL per claim against the tolerance thresholds in Phase 4 below.

**Core principle:** If the paper says `ATT = -1.632 (0.584)` and the code produces `-1.628 (0.591)`, we verify — **numerically** — that the difference is within the documented tolerance. No more "looks close enough" eyeballing.

## When to use

- **Before submission.** Catches the "I updated the analysis but forgot to update Table 2" bug.
- **Before releasing a replication package.** Verifies the code actually reproduces the paper.
- **After a major revision.** Ensures the paper still matches the latest code.
- **Before committing manuscript + analysis changes.** Run it and act on the PASS/FAIL verdict. It is a model-run check, not a git hook: nothing blocks the commit automatically.

## Inputs

- `$0` — path to the manuscript (`.tex`, `.qmd`, `.md`, `.pdf`). Required.
- `$1` — path to the analysis-outputs directory: wherever your pipeline writes its results (e.g. `scripts/_outputs/`, `results/`, `output/`, a build cache, a log directory). If unset, infer it from the project layout and say which directory you chose.

## Workflow

### Phase 0: Pre-flight

1. Note the tolerance thresholds in Phase 4. If the project defines its own tolerances (in the project section of AGENTS.md or a project replication protocol), those override the defaults.
2. Verify the outputs directory exists and is non-empty. If empty or stale (older than the manuscript), prompt the user to re-run their analysis pipeline before auditing.
3. Ensure an environment capture exists in the outputs dir if the project produces one (e.g. a dependency lockfile, a `sessionInfo`/`pip freeze`/`conda env export` dump). Note its absence rather than failing on it.

### Phase 1: Extract claims from the manuscript

Parse the manuscript for numeric claims. Patterns to match:

- **Point-estimate + SE**: `ATT = -1.632 (0.584)`, `$\beta = 0.342$ (0.091)`, `hat{\tau} = 1.28**` with starred significance
- **Table cells**: `& -1.632$^{***}$ & 0.584 &` in LaTeX table environments
- **Counts**: `our sample of 2,847 firms`, `$N = 2{,}847$`
- **Summary stats**: `mean = 0.423`, `SD = 0.087`
- **P-values**: `p < 0.01`, `$p = 0.003$`

Record each claim as a tuple:

```
{
  claim_id: "Table2_col3_ATT",
  location: "Table 2, Column 3, row 'Treatment'",
  kind: "point_estimate" | "standard_error" | "p_value" | "count" | "percentage",
  reported_value: -1.632,
  uncertainty: 0.584,              # only for point estimates
  significance_stars: 3,            # 0-3 or None
  raw_context: "the ATT estimate of -1.632 (0.584) indicates..."
}
```

Write the extracted claims to `.claude/session-reports/reproducibility_claims_[manuscript-name].json` so the user can review the extraction before audit.

### Phase 2: Extract results from outputs

Scan `$1` for corresponding values. Priority order:

1. **`.rds` files** — `readRDS(path)$coef[["treatment"]]` style lookups. Can use `Rscript -e "saveRDS(summary(readRDS(...)), '/tmp/audit.rds')"` to extract.
2. **`.tex` tables** — parse LaTeX table cells directly; match on column headers + row labels.
3. **`.csv` summary files** — pandas/readr parse, key-value lookup.
4. **`.out` / `.log` files** (Stata, regress output) — regex extraction.
5. **`.json`** — direct key lookup.

Record each extracted result:

```
{
  source: "<outputs-dir>/results.<ext>",
  lookup_key: "fit_main$coefficients['treated']",
  value: -1.628,
  uncertainty: 0.591,
  p_value: 0.005
}
```

### Phase 3: Match claims to results

Use fuzzy heuristics when exact labels don't match:

- Name similarity (`"treatment effect"` ~ `"ATT"` ~ `"treated"`)
- Magnitude similarity (if two candidates have values within 10% of the reported, prefer the one with closer SE)
- Context hints from the claim's `raw_context` field (table number, row label, description)

For every claim, produce a match candidate with a confidence score. Claims below 0.7 confidence get flagged as "UNMATCHED — manual review needed" rather than silently passing.

### Phase 4: Tolerance check

For each matched claim, apply these thresholds (defaults — a project may override them in the project section of AGENTS.md):

| Kind | Tolerance | Example |
|---|---|---|
| Integers (N, counts) | Exact | 2,847 must equal 2,847 |
| Point estimates | `abs(reported - computed)` < 0.01 | -1.632 vs -1.628 → diff = 0.004 → PASS |
| Standard errors | `abs(reported - computed)` < 0.05 | 0.584 vs 0.591 → diff = 0.007 → PASS |
| P-values | Same significance level | p<0.01 and p<0.01 → PASS; p<0.01 and p=0.03 → FAIL |
| Percentages | ±0.1pp | 42.3% vs 42.35% → PASS |

Respect any **tolerance overrides** the project defines (loosened for simulation noise, tightened for administrative data, etc.).

### Phase 5: Report

Write `.claude/session-reports/reproducibility_audit_[manuscript-name].md`:

```markdown
# Reproducibility Audit: [Manuscript Title]

**Date:** [YYYY-MM-DD]
**Manuscript:** [path]
**Outputs directory:** [path]
**Tolerance source:** skill defaults (Phase 4), plus any project overrides

## Summary

| Status | Count |
|---|---|
| PASS | N |
| FAIL (diff > tolerance) | M |
| UNMATCHED (manual review) | K |
| **Overall verdict** | **PASS / FAIL** |

## PASS (all within tolerance)
| Claim | Reported | Computed | Diff | Tolerance |
|---|---|---|---|---|
| Table2_col3_ATT | -1.632 (0.584) | -1.628 (0.591) | 0.004 / 0.007 | 0.01 / 0.05 |

## FAIL (outside tolerance — BLOCKER)
| Claim | Reported | Computed | Diff | Tolerance | Location in paper |
|---|---|---|---|---|---|

## UNMATCHED (manual review)
| Claim | Raw context | Candidate sources |
|---|---|---|

## Environment
[environment capture excerpt, if the project produces one]

## Next steps
1. Fix any FAIL rows — either update the manuscript or rerun analysis.
2. Review UNMATCHED rows — add explicit lookup keys or widen the search scope.
3. After zero FAILs, the paper is replication-ready.
```

## Verdict

The skill reports a verdict; it has no exit status (it is a model-run skill, not a script, and this plugin ships no script that would set one). End the reply with the verdict line:

- **All PASS:** `PASS`, with the summary.
- **Any FAIL:** `FAIL`, with the FAIL rows listed first. Treat it as a blocker: do not submit or release the replication package until every FAIL is resolved.
- **UNMATCHED > 0 (with 0 FAIL):** `PASS with warnings` — the user must review the UNMATCHED rows by hand.

## Cross-references

- `/agentic-paper:review-paper` ("Cross-artifact protocol") — the code review of referenced scripts; this skill catches NUMERICAL reproducibility.
- [`/agentic-paper:review-paper`](../review-paper/SKILL.md) — content review; pair with this skill for a full pre-submission audit.

## What this skill does NOT do

- **Re-run your analysis.** The skill compares CURRENT outputs against manuscript claims. If the outputs are stale, re-run your pipeline first (the pre-flight phase will warn).
- **Catch wrong specifications.** A regression that compiles cleanly and produces a reproducible `-1.632` is reproducible. Whether `-1.632` is the RIGHT estimand is a question for `/agentic-paper:review-paper` (in `--peer` mode, its `agentic-paper:methods-referee`).
- **Check dependency versions.** An environment capture lets a reviewer see what produced the numbers; pinning versions is on the user (a lockfile — `renv.lock`, `requirements.txt`, `poetry.lock`, `Manifest.toml`, whatever the stack uses).
