---
name: respond-to-referees
description: Generate a structured response-to-referees document from a referee report and the revised manuscript. Maps each referee comment to the specific revision, classifies coverage (addressed / partially / deferred / disagreement), and drafts polite but firm responses. Use during the R&R (revise-and-resubmit) stage of paper revision.
argument-hint: "[referee-report-path] [revised-manuscript-path] [--no-verify]"
disable-model-invocation: true
allowed-tools: ["Read", "Write", "Edit", "Grep", "Glob", "Bash", "Agent", "Task"]
---

<!-- Adapted from pedrohcgs/claude-code-my-workflow (MIT), https://github.com/pedrohcgs/claude-code-my-workflow -->


# Respond to Referees

Produce a complete response-to-referees document by cross-referencing the referee report against the revised manuscript. Classify every concern, draft a courteous response for each, and flag anything unaddressed before submission.

## Inputs

- `$0` — path to the referee report
- `$1` — path to the revised manuscript

Supported formats and how to read them. In the commands below, `FILE` stands for the input path being converted — either `$0` (referee report) or `$1` (revised manuscript). Always use `mktemp` for the temp file (not a predictable `/tmp/...` name) so paths with spaces and concurrent runs don't collide, and so untrusted `FILE` paths can't clobber other temp files via symlink races.

| Format | How to extract text |
| --- | --- |
| `.tex`, `.qmd`, `.md`, `.txt` | Read directly with the `Read` tool. |
| `.pdf` | `TMP=$(mktemp --suffix=.txt) && pdftotext "FILE" "$TMP"` (poppler-utils; use `mktemp -t ...` on macOS if `--suffix` is unsupported). Grep `"$TMP"`. |
| `.docx` | `TMP=$(mktemp --suffix=.txt) && pandoc "FILE" -t plain -o "$TMP"` (or `docx2txt "FILE" "$TMP"`). Grep `"$TMP"`. |
| `.html` | `TMP=$(mktemp --suffix=.txt) && pandoc "FILE" -t plain -o "$TMP"`. Grep `"$TMP"`. |

If a required tool is missing or extraction fails, ask the user to provide a plain-text version (`.txt` or `.md`) and stop.

## Workflow

### Step 0: Convert Inputs to Plain Text

Before any parsing or grep, convert non-text inputs (`.pdf`, `.docx`, `.html`) to plain text using the table above. Keep both the temp text file (for grep) and the original (for citation page references).

### Step 1: Parse the Referee Report

1. Read the report end-to-end.
2. Decompose into discrete numbered concerns. Common patterns:
   - Numbered or bulleted enumerations ("1.", "(a)", "Comment 1", etc.).
   - Section headers ("Major comments", "Minor comments").
   - Implicit concerns embedded in prose paragraphs — extract these too.
3. For each concern, capture:
   - **Concern ID** (R{n}.{m} = referee n, comment m)
   - **Severity** the referee assigned (major / minor / typographic)
   - **Verbatim quote** of the most representative sentence (~25 words max)
   - **One-line summary** in your own words

### Step 2: Locate Each Concern in the Revised Manuscript

For every concern:

1. Extract the key terms from the referee's wording.
2. `Grep` the **plain-text version** of the revised manuscript for those terms (and synonyms). Note: Grep only works on text — if the original was any non-text format (for example, `.pdf`, `.docx`, or `.html`), grep the converted temp file from Step 0.
3. `Read` the surrounding context (±20 lines) to confirm the change addresses the concern.
4. Note the page/section/line numbers in the **original** file (not the temp file) for the response document.

### Step 3: Classify Coverage

Assign one of four labels to each concern:

| Label | Meaning |
| --- | --- |
| **Addressed** | The revision directly resolves the concern with a specific change you can point to. |
| **Partially addressed** | The revision moves in the requested direction but does not fully resolve the concern (e.g., added one robustness check when the referee asked for two). |
| **Deferred** | The revision does not change the manuscript on this point but the response will explain why (out of scope, separate paper, conflicting referee, etc.). |
| **Disagreement** | The author respectfully disagrees with the referee's premise. The response will explain the reasoning and any compromise. |

If you cannot find any evidence of a revision OR a deliberate decision to defer/disagree, mark the concern **UNADDRESSED — REQUIRES AUTHOR INPUT** and surface it in the warning summary at the end.

### Step 4: Draft Each Response

For every concern, write a 3–6 sentence response in this structure:

1. **Acknowledge** the concern (one sentence, no paraphrasing flattery).
2. **State the change** (or the reason for not changing).
3. **Point to the location** in the revised manuscript (page, section, line range, or table/figure number).
4. **(Optional) Justify** the choice if the change diverges from the referee's exact ask.

Tone conventions: courteous but firm; never defensive; never quote the referee back at length; use "we" for the author team; avoid "the referee is wrong" — prefer "we respectfully retain our original framing because…".

### Step 5: Produce the Response Document

Write the output to `response-to-referees.md` (matching the template filename) or a path the user specifies. Use the structure in [`response-to-referees.md`](response-to-referees.md) (shipped beside this skill):

1. **Header** — journal, manuscript ID, revision round, date.
2. **Cover paragraph** — one paragraph thanking the editor and referees, summarizing the major changes at a high level.
3. **Per-referee sections** — for each referee, a numbered list of responses produced in Step 4.
4. **Concern matrix** — at the end, a single table summarizing every concern: ID, classification, promised action, affected files or exhibits, whether code had to be re-run, and response location. This is the obligation ledger — nothing promised in the letter without a row, no row without its evidence trail.

### Step 5.5: Post-Flight Verification (MANDATORY, CoVe)

The response document's most hallucination-prone content is the set of "we added X on page Y" claims. Hallucinating these gets a paper desk-rejected on sight. Before declaring the response document final, run the Post-Flight Verification protocol from [`/agentic-paper:verify-claims`](../verify-claims/SKILL.md).

**Steps:**

1. **Extract revision-location claims** — every "we added / we modified / we revised X (page Y, line Z / Section N)" assertion in the response document.
2. **Generate verification questions** — "Does the revised manuscript actually contain the revision claimed at page Y, line Z? Does it match the description?"
3. **Dispatch `claim-verifier`** with the `Agent` tool (`subagent_type: agentic-paper:claim-verifier`). A named subagent starts with a fresh context and has never seen this conversation. **Never use the `fork` subagent type here:** a fork inherits the whole conversation, draft included, and the check turns into self-confirmation. Hand it: the claims table, the verification questions, the path to the revised manuscript. Do NOT include the response draft.
4. **Reconcile:** PASS → attach green block. PARTIAL / FAIL → rewrite the affected response entries using the verifier's evidence. A response that says "we added robustness check X on page 34" when X is actually on page 27 (or not at all) is worse than a "Deferred" classification.

Downgrade to the classification the evidence supports:

- Claim verified at location → `Addressed`
- Claim verified at different location → update the location in the response
- Claim not verifiable in manuscript → downgrade to `Partially addressed` or `Deferred` with an honest rationale

Opt-out: `--no-verify` flag. Not recommended — the referee will run this check themselves.

### Step 6: Warning Summary (MANDATORY)

After the document is written, include this summary in your **final chat message to the user** (NOT inside the response document):

```
## Unaddressed concerns requiring author input

- R1.3: [summary] — no evidence of revision found
- R2.7: [summary] — flagged as deferred but no rationale yet drafted
```

If everything is covered, the final message should say `All concerns addressed or explicitly classified.`

## Revision diff (LaTeX manuscripts)

Editors and referees read the diff before they read the response. If the manuscript is LaTeX, produce a marked-up PDF and point at it — a response entry that says "see the highlighted passage on p. 12 of the diff" is checkable in seconds; one that says "we clarified the identification argument" is not.

**Generate it.** Two routes:

```bash
# Plain: pre-revision source vs revised source
latexdiff --flatten old.tex new.tex > diff.tex && pdflatex diff.tex && pdflatex diff.tex

# Against the tag you submitted from (no stale copy of old.tex needed)
latexdiff-vc --git --flatten --pdf -r submission-v1 main.tex
```

- `--flatten` is not optional for multi-file manuscripts — without it `latexdiff` diffs the wrapper and ignores every `\input`/`\include`.
- Run `pdflatex` twice (or `latexmk diff.tex`) so cross-references and the ToC settle.
- Macro-heavy preambles can break the markup. `--append-safecmd=cmd1,cmd2` for commands whose *arguments* are safe to mark up; `--exclude-textcmd` for ones that must be left alone. If a specific environment explodes, `%DIF PREAMBLE` blocks and `--config` are the escape hatches — do not hand-edit `diff.tex`, it is regenerated output.

**Wire it into the response.** For every concern classified **Addressed** or **Partially addressed** whose change is *textual*, cite the diff page next to the manuscript location: `(revised manuscript p. 14, §4.2; diff p. 16)`. Skip it for concerns resolved by a new figure, table, or dataset — those need the artifact itself, not a text diff. If you produced a diff, name its filename once in the cover paragraph so the editor knows it exists.

**Availability.** `latexdiff` ships in TeX Live's `collection-binextra`, so full TeX Live and MacTeX already have it. BasicTeX / `scheme-small` users install it explicitly:

```bash
tlmgr install latexdiff       # may need sudo on MacTeX/BasicTeX
```

If `latexdiff` is unavailable and cannot be installed, say so in the final message and fall back to per-comment page/line references — do not fabricate diff page numbers.

**Submission prep.** Before uploading the revised source, strip comments, unused files, and oversized images with [`arxiv-latex-cleaner`](https://github.com/google-research/arxiv-latex-cleaner) (`pip install arxiv-latex-cleaner`, then `arxiv_latex_cleaner paper/` → `paper_arXiv/`). Referee-facing `% TODO` and `% reviewer 2 is wrong about this` comments have been read before. Clean the copy you upload; keep the annotated one in git.

## Output Files

- `response-to-referees.md` — the deliverable (filename matches this skill's [`response-to-referees.md`](response-to-referees.md) template)
- (Optional) `response-to-referees-matrix.csv` — machine-readable concern-to-response mapping for tracking across revisions
- (LaTeX) `diff.pdf` / `main-diff<tag>.pdf` — the marked-up revision diff referenced from the response entries

## Pre-submission rehearsal

**Tip.** Before drafting your response, consider running `/agentic-paper:review-paper --peer --r2 <journal>` on the *revised* manuscript first. It simulates the next referee round against your revisions — catching the "Resolved / Partial / Not addressed" classification mistakes before the real referee does. See [`/agentic-paper:review-paper`](../review-paper/SKILL.md).

## Cross-References

- For first-pass manuscript review **before** receiving referee comments, use `/agentic-paper:review-paper`.
- For a substantive content audit of the revised manuscript, use `/agentic-paper:review-paper --peer <journal>`, whose `agentic-paper:domain-referee` reviews substance.
- Save the response to `.claude/session-reports/` if you want a permanent record alongside other quality reports.

## Verification

Before reporting completion:

1. Confirm every concern has a classification (no orphans).
2. Confirm every "Addressed" or "Partially addressed" classification cites a specific page/section/line.
3. Confirm the warning summary was emitted (even if empty).
4. Confirm the cover paragraph names the journal and manuscript ID correctly.
