# agentic-paper

The paper + LaTeX capability plugin for
[agentic-repo-template](https://github.com/groundnuty/agentic-repo-template) (v0.3+).
Serves both the `paper` and `paper-latex` profiles — the LaTeX skills are inert without `.tex`
files, so one plugin covers both tiers.

```bash
claude plugin marketplace add groundnuty/agentic-plugins --scope project
claude plugin install agentic-paper@agentic-plugins --scope project
```

## What it ships

**10 skills** — every name is namespaced; bare names are not this plugin's contract:

| Skill | What it does |
| :-- | :-- |
| `/agentic-paper:review-paper` | Manuscript review: single-pass, `--adversarial` critic-fixer loop, or `--peer <journal>` simulated peer review (editor + 2 dispositioned referees) |
| `/agentic-paper:seven-pass-review` | Seven independent lenses in parallel, then synthesis. ~7× the token cost of single-pass |
| `/agentic-paper:verify-claims` | Chain-of-Verification (CoVe) on a draft via a fresh-context verifier (never a fork) |
| `/agentic-paper:respond-to-referees` | Drafts a response document from referee comments (ships its own output template) |
| `/agentic-paper:audit-reproducibility` | Numeric-claim reproducibility audit: manuscript numbers vs. script outputs |
| `/agentic-paper:analyze-paper` | Structured read of a paper |
| `/agentic-paper:proofread` | Grammar, typos, overflow |
| `/agentic-paper:humanizer` | Removes AI-writing tells — **vendored third-party**, see below |
| `/agentic-paper:tikz` | TikZ collision audit by measurement, plus `PREVENTION.md`, `LIBRARIES.md` and five canonical `snippets/` |
| `/agentic-paper:validate-bib` | BibTeX structural + semantic validation |

**5 agents** — `agentic-paper:claim-verifier`, `:domain-referee`, `:methods-referee`, `:editor`,
`:proofreader`. All four review agents carry `memory: project`. `claim-verifier` deliberately does
**not**: it is the CoVe fresh-context verifier, and project memory would let it see prior drafts,
which is exactly the independence the mechanism buys.

**1 LSP server** — `texlab`, mapping `.tex` → `latex` and `.bib` → `bibtex`.

> **You must install the binary yourself:** `brew install texlab` (or your platform's
> equivalent). A plugin configures the LSP connection; it cannot ship the server. If the binary is
> missing, the error appears in `/plugin` → Errors **only after your first `.tex` edit**, not at
> session start — a lazy failure worth knowing about.

## What it deliberately does NOT ship

| Not here | Where it lives | Why |
| :-- | :-- | :-- |
| **Hooks** (`notify.sh`, `log-reminder.py`, `verify-reminder.py`) | project scaffold | Paper hooks are **opt-in by design** — the user wires them from `settings.local.json`. A plugin hook is active whenever the plugin is enabled, which would silently convert opt-in to mandatory. |
| **MCP servers** | project `.mcp.json.example` | Keeps the documented per-server approval path and the existing `mcp__papers__*` permission rules unchanged. |
| **Rules** | project `AGENTS.md` | Plugins cannot ship rules. The project guidance these skills rely on (post-flight verification, the knowledge-work directory layout, project conventions) lives in the project's `AGENTS.md` since template v0.5.0; skills point to it by section name, never by a plugin-relative path. |
| **`journal-profile-template.md`** | project scaffold | You copy it and fill it in at `.claude/references/journal-profiles.md`. A version-pinned plugin cache is the wrong home for a file the user edits. |

## Vendored third-party content

`skills/humanizer/` is **not ours**. It is [blader/humanizer](https://github.com/blader/humanizer)
`v3.0.0` by Siqi Chen, redistributed under the **MIT License**.

* Full licence text: [`skills/humanizer/LICENSE`](skills/humanizer/LICENSE)
* Attribution, the byte-identity contract, and how to bump the pin:
  [`skills/humanizer/ATTRIBUTION.md`](skills/humanizer/ATTRIBUTION.md)

`SKILL.md`, `README.md` and `LICENSE` in that directory are byte-identical to upstream `v3.0.0`
and the test suite asserts it. Upstream's own README documents a different install path and the
name `/humanizer:humanizer`; here the skill is `/agentic-paper:humanizer` and needs no separate
install. Those upstream strings are the single documented exception to the namespacing rule below.

Everything else in this plugin is adapted from named sources with attribution recorded in-file:
`pedrohcgs/claude-code-my-workflow` (MIT), Hugo Sant'Anna's `clo-author` (used with permission),
and the `tikz` skill from Scott Cunningham's `scunning1975/MixtapeTools` (use freely with
attribution, pinned to the pre-rewrite commit — see the header in `skills/tikz/SKILL.md`).

## Namespacing is load-bearing, not cosmetic

Every cross-reference inside this plugin names skills and agents in their namespaced form, and
every `subagent_type=` dispatch is `agentic-paper:<agent>`. This is a **correctness** requirement,
not tidiness. During a partial migration a *bare* name silently resolves to a leftover file-copied
scaffold skill of the same name — no error, no version signal, stale content. Phase 0's arm 3
demonstrated it. Namespaced references make that failure loud instead of silent.

`tests/test-plugin.sh` at the marketplace root asserts zero bare-name and zero stale-scaffold-path
references, so the property cannot rot.

## Version

`1.0.0`, declared **only** in `.claude-plugin/plugin.json`. It is deliberately absent from the
marketplace entry: `plugin.json` wins at install time without warning, so two copies can only
drift. `claude plugin tag --dry-run` enforces the agreement.
