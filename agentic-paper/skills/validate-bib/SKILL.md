---
name: validate-bib
description: Validate bibliography entries against citations in all paper/manuscript files. Structural checks (missing/unused entries, malformed fields) by default; `--semantic` adds citation-drift detection, DOI verification, existence + retraction checks, and style-consistency checks.
argument-hint: "[--semantic] [--skip-doi] [--cite-claim]"
allowed-tools: ["Read", "Grep", "Glob", "Write", "Bash", "WebFetch"]
---

<!-- Adapted from pedrohcgs/claude-code-my-workflow (MIT), https://github.com/pedrohcgs/claude-code-my-workflow -->


# Validate Bibliography

Cross-reference citations in paper/manuscript files against bibliography entries. Two modes:

- **Default (structural):** missing entries, unused entries, malformed fields, typo candidates.
- **`--semantic`:** adds citation-drift detection (duplicate entries for the same paper), DOI verification via crossref, an existence + retraction pass (Crossref + OpenAlex), and citation-style consistency within each file.

Report saved to `.claude/session-reports/bib_audit_[structural|semantic].md`.

## Mode 1: Structural (default)

### Steps

1. **Read the bibliography file** and extract all citation keys.

2. **Scan paper/manuscript files for citation keys:**
   - `.tex`: `\cite{`, `\citet{`, `\citep{`, `\citeauthor{`, `\citeyear{`, `\textcite{`, `\parencite{`
   - `.qmd` / `.md`: `@key`, `[@key]`, `[@key1; @key2]`
   - Extract all unique citation keys used.

3. **Cross-reference:**
   - **Missing entries (CRITICAL):** cited in lectures, absent from `.bib`.
   - **Unused entries (informational):** in `.bib` but never cited.
   - **Typo candidates:** keys within edit-distance 2 of a `.bib` key (e.g., `Smith2020` vs `Smth2020`).

4. **Check entry quality:**
   - Required fields present (author, title, year, journal/booktitle).
   - Author field properly formatted.
   - Year in 1900–current.
   - No malformed characters / encoding issues.
   - `doi` field normalized (no leading `https://doi.org/`).

5. **Write report** to `.claude/session-reports/bib_audit_structural.md`.

### Files scanned

```
**/*.tex
**/*.qmd
guide/*.qmd
**/*.md
```

### Bibliography location

`Bibliography_base.bib` at repo root by default; override via CLAUDE.md.

## Mode 2: Semantic (`--semantic`)

Everything in Mode 1, plus:

### 2a. Citation drift detection

Multiple `.bib` entries describing the same paper under different keys. Symptoms:

- `Smith2020` + `Smith2020a` with identical DOI or title.
- `CallawaySantAnna2021` + `CS2021` both pointing to the same paper.
- Collaborator-merged `.bib` files.

**Detection heuristics (any → FLAG):**

| Check | Signal |
|---|---|
| Same DOI across keys | Hard-duplicate (CRITICAL) |
| Same title (case-insensitive, punct-stripped) | Likely duplicate (CRITICAL) |
| Same author+year+journal | Probable duplicate (MEDIUM) |
| Title Jaccard > 0.85 on tokens ≥ 4 chars | Soft-duplicate (LOW) |

For each flagged pair: list both keys, where each is cited, and recommend a canonical key (prefer most-cited, then alphabetically first).

### 2b. DOI verification (optional; network)

For each entry with a `doi`, fetch `https://api.crossref.org/works/{doi}` and compare:

- First-author last name
- Year
- Title (Jaccard > 0.7 on normalized tokens)
- Container-title / journal (exact or abbreviation)

**Severity:**

- Author or title mismatch → CRITICAL (wrong paper)
- Year mismatch → MEDIUM (preprint vs published, or typo)
- Journal mismatch → LOW (legitimate preprint variants)

**Rate limit:** cap 50 lookups per run, 0.5s delay between calls. Cache in `.claude/session-reports/.doi_cache.json`.

**Opt-out:** `--skip-doi` for offline or no-WebFetch environments.

### 2c. Style consistency within each file

For each file, count citation commands (`\citet` vs `\citep` vs `\cite`; `@key` vs `[@key]`). FLAG files with mixed styles without an obvious pattern (e.g., 20× `\citep` and 3× `\cite` in the same deck). Low-severity.

### 2d. Cite-claim sanity (flag-only)

Gated behind `--cite-claim`. For the top-10 most-cited works per file, WebFetch the crossref abstract and surface it beside the in-text context. **No auto-judgment** — humans decide if the claim matches.

### 2e. Existence + retraction pass (network)

2b asks whether a DOI's metadata *matches* the entry. This pass asks the two questions that actually catch fabrication and stale scholarship: **does the cited work exist**, and **is it still standing?** Run it over every *cited* entry, not only the ones that already carry a `doi`.

**Use `curl`, not `WebFetch`.** Both APIs are keyless and return JSON. WebFetch pipes the response through a summarizer, which drops exactly the fields this pass turns on — `is_retracted`, the `update-to` relation array, the full `author` list. Shell out instead:

```bash
DOI="10.1234/example"

# Crossref — existence + metadata (polite pool: use a real address in mailto)
curl -sfL -H 'User-Agent: validate-bib (mailto:you@example.org)' \
  "https://api.crossref.org/works/${DOI}" | jq '{
     title:   .message.title[0],
     authors: [.message.author[]?.family],
     year:    .message.issued."date-parts"[0][0],
     updates: [.message."update-to"[]? | {type, doi: .DOI}] }'

# OpenAlex — retraction status (keyless; mailto in the query string)
curl -sfL "https://api.openalex.org/works/doi:${DOI}?mailto=you@example.org" \
  | jq '{title, is_retracted, is_paratext}'
```

`curl -f` turns an HTTP 404 into a non-zero exit — that is the UNRESOLVABLE signal, and it is *not* the same as a transport failure (exit 6/7/28). Keep them apart: a 404 is evidence about the citation, a timeout is evidence about your connection.

#### Per-cite verdicts

| Verdict | Test | Tier |
|---|---|---|
| **PASS** | DOI resolves; Crossref title and first-author family name match the `.bib` entry (title Jaccard > 0.7 on normalized tokens ≥ 4 chars). | — |
| **MISMATCH** | DOI resolves but points at a **different paper** — title and/or author disagree beyond threshold. | **HIGH-WARN** → CRITICAL |
| **RETRACTED** | OpenAlex `is_retracted: true`, or a Crossref `update-to` entry of type `retraction` / `withdrawal`. | **HIGH-WARN** → CRITICAL |
| **UNRESOLVABLE** | DOI 404s at Crossref, or the entry has no DOI and no venue hit. | **HIGH-WARN** (dead DOI) / **LOW-WARN** (no DOI on file) |

Tier names match the severity ladder in [`agents/claim-verifier.md`](../../agents/claim-verifier.md) on purpose, so a bib audit and a claims audit read on one scale.

**MISMATCH is never downgradable.** A DOI that resolves cleanly to a *different* work is the canonical fabrication signature: a plausible title/author/year invented first, a real-but-unrelated DOI attached after. It looks *healthier* than a broken link — the URL works, the page loads — which is precisely why it has to be CRITICAL. "Maybe Crossref's metadata is stale" is not an acceptable downgrade. Same hard floor the claim-verifier applies: a fabricated citation is never softened.

**RETRACTED is CRITICAL, but the fix is not always deletion.** Retracted work is legitimately citable — as a retracted result, in related work, in a failure-mode discussion. The defect is citing it *silently*. Recommend one of: drop the cite, or keep it and cite the retraction notice beside it (`\cite{orig,orig_retraction}`) with the retraction named in the prose. Also flag OpenAlex `is_paratext: true` (LOW) — the DOI resolved to front matter or an errata page, not the article.

**UNRESOLVABLE splits by cause — record which:**

- No `doi` field and none expected (pre-1998 work, book chapter, working paper) → **LOW-WARN**, informational. Not a defect.
- A `doi` field that 404s → **HIGH-WARN / CRITICAL**. Treat as fabricated until a human finds the work by hand.
- Network error, timeout, or 429 → not a verdict. Mark `RETRY` (**MED-WARN**) and re-run; never let an unreachable API silently score as PASS or as fabrication.

**Report the denominator.** End the pass with `checked N/M cited entries (K skipped: no DOI, J RETRY)`. Silent partial coverage reads as a clean bill of health.

**Rate limit:** shares 2b's budget — 50 lookups per run, 0.5 s between calls, same `.doi_cache.json` (key retraction results separately; retraction status changes, metadata does not). Crossref's polite pool wants the `mailto`; OpenAlex allows 100k requests/day with one.

**Opt-out:** `--skip-doi` disables this pass too — it is network-bound end to end. There is no offline existence check.

### Report structure (`.claude/session-reports/bib_audit_semantic.md`)

```markdown
# Bibliography Semantic Audit

**Date:** YYYY-MM-DD
**Bibliography:** Bibliography_base.bib (N entries)
**Files scanned:** [list]

## Summary

| Check | Critical | Medium | Low |
|---|---|---|---|
| Structural | | | |
| Citation drift | | | |
| DOI verification | | | |
| Existence + retraction | | | |
| Style consistency | 0 | 0 | |

## Critical Issues

### Duplicate entries
| Keys | Signal | Citations | Recommended canonical |
|---|---|---|---|

### DOI mismatches
| Key | Field | .bib value | crossref value |
|---|---|---|---|

### Existence + retraction
_checked N/M cited entries (K skipped: no DOI, J RETRY)_

| Key | Verdict | Tier | Evidence | Recommended action |
|---|---|---|---|---|

## Medium / Low issues
…

## Next steps
1. Resolve duplicates — pick canonical key, update citations, remove orphans.
2. Fix DOI mismatches — verify paper in crossref or strip the wrong DOI.
3. Resolve every MISMATCH and UNRESOLVABLE-with-DOI by hand — these are the fabrication candidates.
4. For each RETRACTED entry, drop the cite or cite the retraction notice alongside it.
5. Review style-consistency notes.
```

## Exit behavior

- **Structural:** exit 0; report enumerates issues.
- **Semantic:** exit 0 if only LOW findings; exit 1 on any CRITICAL — which now includes any MISMATCH, RETRACTED, or dead-DOI UNRESOLVABLE from 2e. Usable as a pre-submission gate.
- A `RETRY` (network) verdict never sets the exit code by itself, but it must appear in the report — an unchecked cite is not a passing cite.

## Cross-references

- `/agentic-paper:review-paper` — pair for full pre-submission.
- `/agentic-paper:audit-reproducibility` — numeric-claims counterpart.

## What this skill does NOT do

- Judge whether a citation is used in the right *context* (`--cite-claim` surfaces abstracts but does not judge).
- Auto-fix your `.bib` file — all edits are recommendations.
- Check non-DOI identifiers (ISBN, arXiv, SSRN) — roadmap.
