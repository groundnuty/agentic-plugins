# agentic-plugins

Capability plugins for [agentic-repo-template](https://github.com/groundnuty/agentic-repo-template) (v0.3+).

Install (from a template repo — `init.sh`/`upgrade.sh` do this for paper tiers):

```bash
claude plugin marketplace add groundnuty/agentic-plugins --scope project
claude plugin install agentic-paper@agentic-plugins --scope project
```

Offline note: after one online `marketplace add`, installs work from the local clone.
Release ritual: `claude plugin tag --dry-run` must pass, then `claude plugin tag --push`.
