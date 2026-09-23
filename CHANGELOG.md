# Changelog — agentic-plugins

## agentic-paper 1.0.1 — 2026-09-23

- **The claim verifier is dispatched fresh, never forked.** Since Claude Code 2.1.232 a `fork` subagent inherits the whole conversation. Five `claim-verifier` dispatch sites said `context=fork` and called that a fresh context — the one dispatch that would hand the verifier the draft it must not see, undoing Chain-of-Verification. Every site now dispatches the named subagent (which starts fresh) with an explicit never-fork warning; the referee, editor, lens and per-script reviewers are fresh subagents too. Test C6 fails on the old wording and passes on the new.
- **humanizer v2.9.1 → v3.0.0**, byte-identical. The no-fabrication rule is intact; v3 adds a self-check that counts a *dropped* claim — including rankings and "at once" claims — as an error, which protects a paper's priority claims.
- **From pedrohcgs v2.5.1:** de-econ edits to the referee and editor agents; `disallowed-tools` on the read-only `proofread` and `verify-claims`; the verifier's pinned-number rule (a value read back from a tracked artifact is not verification); the referee-response obligation ledger. `allowed-tools` names the `Agent` tool, keeping `Task` for older Claude Code.

## agentic-paper 1.0.0 — 2026-07-28

First release: 10 skills, 5 agents, texlab LSP.
