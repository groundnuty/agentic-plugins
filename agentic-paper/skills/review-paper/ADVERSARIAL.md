# Adversarial mode — critic-fixer loop

Read this file before Step 1 of SKILL.md when `--adversarial` is in `$ARGUMENTS`. Phase 0 below runs first; round 1 of the loop is the default review (SKILL.md Steps 1–6b), and SKILL.md Step 7 hands control back here.

A **loop-until-dry** critic-fixer pattern: the critic emits typed findings, the fixer applies approved edits, a fresh-context critic re-audits, and the loop ends when a round surfaces nothing new. Papers get it because the single-pass review leaves authors doing manual fix-and-resubmit cycles.

**Contents:** Flow · Iteration limits — loop-until-dry · Stopping criteria · Final report · When NOT to use adversarial mode

## Flow

```
Phase 0: Pre-flight
  │
  ├─ Verify the manuscript compiles (xelatex / quarto render) if applicable
  ├─ Snapshot the pre-review version: git stash OR copy to a .review-backup/
  │
Phase 1: Critic audit (round N=1,2,3,...)
  │
  ├─ Run the default review (SKILL.md Steps 1–6), producing a round-N report
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
  ├─ Apply approved edits with the Edit tool.
  ├─ If the manuscript is a compile target (`.tex` / `.qmd`), re-compile
  │  and verify it still builds.
  │
Phase 3: Re-audit
  │
  └─ Spawn a FRESH-CONTEXT subagent (via the `Agent` tool, `subagent_type` set to
     general-purpose) to re-read the paper and produce a round-(N+1)
     report. Fresh context prevents anchoring bias — the new reviewer
     sees the edited paper, not the diff.
     → Jump back to Phase 1.
```

## Iteration limits — loop-until-dry

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

## Stopping criteria

| Condition | Action |
|---|---|
| Round adds 0 new CRITICAL/MAJOR concerns and 0 new fatal Referee Objections | APPROVED (converged) — final summary |
| Fallback cap (5 rounds) reached without converging | HALTED — list remaining concerns, user decides |
| User approves zero fixes in a round | HALTED — user signals "I disagree with this review" |
| Compile fails after applied fixes | ROLLED BACK to pre-round-N snapshot, report compile error, user decides |

## Final report

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

## When NOT to use adversarial mode

- Early exploratory drafts (the loop forces premature polish on ideas still being shaped)
- Papers you don't yet have compilable source for (can't verify edits)
- When you'd rather get ONE opinion and decide for yourself (adversarial-mode enforces "critic signed off" semantics — that's sometimes the wrong frame)
