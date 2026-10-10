# Changelog — agentic-plugins

## agentic-paper 1.0.3 — 2026-10-10

From a review against Anthropic's skill-authoring guide and the Claude 5.5 prompting guides (research doc 18).

- **The `--peer` claim checks now run.** Both CoVe gates — verifying the editor's novelty claims, and the post-judge hallucination gate — were the editor agent's job, but it has no tool to dispatch a verifier, so neither ran. `/review-paper` now runs both itself after each editor pass, re-dispatching the editor when a claim does not verify.
- **No agent sets `memory:`.** It silently granted Edit (and Write) to the editor, both referees and the proofreader, which are told never to edit the manuscript. Tests B3 and C11 fail on any `memory:`.
- **`/review-paper` survives compaction.** It was ~6.3k tokens; after compaction Claude Code keeps the first 5,000 tokens of a skill, which cut its final verification gate. The adversarial loop, the `--peer` workflow and the cross-artifact contract now live in their own files (~3.5k tokens left in SKILL.md); test C13 caps every SKILL.md.
- **Your customizations live in your project.** Text that told you to edit files inside the plugin — lost on every update — now points at `.claude/references/` files the skills read when present (`paper-types.md`, `positioning.md`, `peeves.md`, alongside `journal-profiles.md`).
- **Smaller fixes:** `${CLAUDE_PLUGIN_ROOT}` in tikz support files was never substituted (now `${CLAUDE_SKILL_DIR}` in SKILL.md; test C12); the editor *chooses* two clashing referee dispositions with a stated reason instead of a "weighted draw" with no weights; `/validate-bib` fetches Crossref with `curl | jq` instead of WebFetch, which drops the fields it compares; capitalised pressure lines reworded with their reasons kept.

## agentic-paper 1.0.2 — 2026-10-10

- **Every name the skills mention now exists, and every report has one writer.** Found by Claude Code's new `/doctor prompt-audit`. Skills dispatched a `domain-reviewer` agent that never existed (ours is `agentic-paper:domain-referee`) and named upstream-only skills (`/slide-excellence`, `/lit-review`, `/commit`, …). `/seven-pass-review` handed lens files to agents that only write their own fixed report — all seven lenses are now general-purpose. Pointers to rule files that template v0.5.0 folded into `AGENTS.md` now name the `AGENTS.md` section.
- **Agents list the tool they use.** The editor, both referees and the proofreader write report files but listed only read tools. Their `memory: project` already granted Read, Write and Edit (sub-agents docs), so this changes no capability; `Write` is now explicit and each agent names the one file it writes. Not writing the manuscript is an instruction, not a tool restriction — `memory:` grants Edit. The claim verifier stays without Write and without memory.
- **Smaller fixes:** lecture-slide wording left in the proofreading path; exit codes promised by model-run skills (they report PASS/FAIL); a `MEMORY.md` reference in the verifier, which has no memory; `/review-paper` describing its adversarial mode two ways; the editor's FATAL table reusing the word "addressable" for a different thing (renamed "fixable"; every decision outcome unchanged).
- Tests C8–C10 fail on 1.0.1 and pass now.
- **The deep-review skills run at your effort level again.** `/seven-pass-review`, `/respond-to-referees` and `/audit-reproducibility` pinned `effort: high`. A skill's `effort` overrides the session's, so in a repo running at `xhigh` they reasoned *less*. The pins are gone; test C7 fails on any skill or agent that pins effort or a model — the same reason D43 rejected upstream's agent pins.

## agentic-paper 1.0.1 — 2026-09-23

- **The claim verifier is dispatched fresh, never forked.** Since Claude Code 2.1.232 a `fork` subagent inherits the whole conversation. Five `claim-verifier` dispatch sites said `context=fork` and called that a fresh context — the one dispatch that would hand the verifier the draft it must not see, undoing Chain-of-Verification. Every site now dispatches the named subagent (which starts fresh) with an explicit never-fork warning; the referee, editor, lens and per-script reviewers are fresh subagents too. Test C6 fails on the old wording and passes on the new.
- **humanizer v2.9.1 → v3.0.0**, byte-identical. The no-fabrication rule is intact; v3 adds a self-check that counts a *dropped* claim — including rankings and "at once" claims — as an error, which protects a paper's priority claims.
- **From pedrohcgs v2.5.1:** de-econ edits to the referee and editor agents; `disallowed-tools` on the read-only `proofread` and `verify-claims`; the verifier's pinned-number rule (a value read back from a tracked artifact is not verification); the referee-response obligation ledger. `allowed-tools` names the `Agent` tool, keeping `Task` for older Claude Code.

## agentic-paper 1.0.0 — 2026-07-28

First release: 10 skills, 5 agents, texlab LSP.
