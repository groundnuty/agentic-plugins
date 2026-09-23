# Vendored third-party skill — attribution

`humanizer` is **not ours**. It is redistributed here under the MIT License.

| | |
| :-- | :-- |
| **Upstream** | https://github.com/blader/humanizer |
| **Version** | `v3.0.0` (git tag) |
| **Author** | Siqi Chen |
| **License** | MIT — full text in [`LICENSE`](LICENSE) |

## What we redistribute, and why it is byte-identical

`SKILL.md`, `README.md` and `LICENSE` in this directory are **byte-identical to upstream
`v3.0.0`**. That is deliberate: publishing a third-party MIT skill inside our marketplace plugin
makes us a redistributor, and an unmodified copy is the only kind whose provenance a reader can
check without trusting us. Verify it yourself:

```bash
git clone --depth 1 --branch v3.0.0 https://github.com/blader/humanizer.git /tmp/hz
for f in SKILL.md README.md LICENSE; do diff -q "/tmp/hz/$f" "$f" || echo "DRIFTED: $f"; done
```

`tests/test-plugin.sh` asserts this byte-identity, so a silent edit fails the suite.

## Why v3.0.0 (moved from v2.9.1 in agentic-paper 1.0.1)

We pinned v2.9.1 because it added a hard no-fabrication rule. v3.0.0 keeps that rule whole (no added
fact, name, number, date, quote or citation unless the source or the user supplied it) and adds the
check v2.9.1 lacked: its self-review treats a **dropped** claim as an error and names rankings and
simultaneity explicitly. In a paper, "the first to show", "the only method that" and "achieves both
at once" are priority claims, and deleting one silently changes what the paper asserts. The
ranking/simultaneity fix exists in no earlier tag.

## Three consequences of not modifying it

1. **The invocation name here is `/agentic-paper:humanizer`.** Upstream's `README.md` documents
   `npx skills add blader/humanizer`, `/plugin marketplace add blader/humanizer`, and the
   resulting `/humanizer:humanizer` name. None of that applies to this copy — it arrives with the
   `agentic-paper` plugin and needs no separate install. Those upstream strings are the one
   documented exception to this plugin's D5 namespacing rule.
2. **We ship a subset.** Upstream `v3.0.0` also carries `AGENTS.md`, `agents/openai.yaml` and
   `scripts/validate-package.py` — upstream's own cross-harness packaging, unreferenced by
   `SKILL.md`. They are omitted as irrelevant to a Claude Code plugin, not stripped for content.
3. **It is model-invocable.** Upstream's frontmatter has no `disable-model-invocation`, and
   byte-identity means we cannot add it, so Claude may invoke it unasked. Our `humanize-prose` rule
   keeps it advisory: it reports, and the author decides what to apply.

## Bumping the pin

`v3.0.0` is a **tag**, and `git clone --branch` cannot check out a SHA — so the pin is only as
strong as upstream's tag. To bump: re-clone at the new tag, replace all three files wholesale,
update the version in this file, and re-run the suite. Do not hand-merge: byte-identity is the
property being maintained.
