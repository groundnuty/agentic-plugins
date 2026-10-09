# Changelog — agentic-plugins

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
