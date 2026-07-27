# Vendored third-party skill — attribution

`humanizer` is **not ours**. It is redistributed here under the MIT License.

| | |
| :-- | :-- |
| **Upstream** | https://github.com/blader/humanizer |
| **Version** | `v2.9.1` (git tag) |
| **Author** | Siqi Chen |
| **License** | MIT — full text in [`LICENSE`](LICENSE) |

## What we redistribute, and why it is byte-identical

`SKILL.md`, `README.md` and `LICENSE` in this directory are **byte-identical to upstream
`v2.9.1`**. That is deliberate: publishing a third-party MIT skill inside our marketplace plugin
makes us a redistributor, and an unmodified copy is the only kind whose provenance a reader can
check without trusting us. Verify it yourself:

```bash
git clone --depth 1 --branch v2.9.1 https://github.com/blader/humanizer.git /tmp/hz
for f in SKILL.md README.md LICENSE; do diff -q "/tmp/hz/$f" "$f" || echo "DRIFTED: $f"; done
```

`tests/test-plugin.sh` asserts this byte-identity, so a silent edit fails the suite.

## Two consequences of not modifying it

1. **The invocation name here is `/agentic-paper:humanizer`.** Upstream's `README.md` documents
   `npx skills add blader/humanizer`, `/plugin marketplace add blader/humanizer`, and the
   resulting `/humanizer:humanizer` name. None of that applies to this copy — it arrives with the
   `agentic-paper` plugin and needs no separate install. Those upstream strings are the one
   documented exception to this plugin's D5 namespacing rule.
2. **We ship a subset.** Upstream `v2.9.1` also carries `AGENTS.md`, `agents/openai.yaml` and
   `scripts/validate-package.py` — upstream's own cross-harness packaging, unreferenced by
   `SKILL.md`. They are omitted as irrelevant to a Claude Code plugin, not stripped for content.

## Bumping the pin

`v2.9.1` is a **tag**, and `git clone --branch` cannot check out a SHA — so the pin is only as
strong as upstream's tag. To bump: re-clone at the new tag, replace all three files wholesale,
update the version in this file, and re-run the suite. Do not hand-merge: byte-identity is the
property being maintained.
