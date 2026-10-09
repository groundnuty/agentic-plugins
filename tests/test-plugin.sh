#!/usr/bin/env bash
# test-plugin.sh — the agentic-plugins marketplace test suite.
#
# Five groups, in cost order (cheap structural checks first, the live install last):
#   A  manifests            claude plugin validate (plugin + marketplace, --strict), plus the
#                           vendor-neutral .agents/plugins/marketplace.json symlink Codex resolves
#   B  frontmatter lint     our own — `claude plugin validate` does NOT catch the banned
#                           plugin-agent fields (v0.3 plan review, m1), so we check them here;
#                           also the tikz write-path-first description guard (B6)
#   C  D5 namespacing       zero bare-name / zero stale-scaffold-path references
#   D  version agreement    claude plugin tag --dry-run (Phase-0 carry-item 4: the CLI already
#                           IS the tag<->version guard; don't write one)
#   E  functional           real directory-marketplace install into a scratch consumer, verified
#                           with the Phase-0 project-scoped predicate, then skills+agents asserted
#
# Usage:  bash tests/test-plugin.sh [--no-install]
#   --no-install   skip group E (it mutates machine plugin state and needs the `claude` CLI)
#
# Exit: 0 all green · 1 a test failed · 2 environment problem.

set -uo pipefail

MKT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
PLUGIN_NAME="agentic-paper"
PLUGIN_DIR="$MKT_ROOT/$PLUGIN_NAME"
MKT_NAME="agentic-plugins"

# The 10 skills and 5 agents this plugin ships. Every name here must be namespaced at every
# reference site inside the plugin (D5). Keep in sync with skills/ and agents/ — group B asserts it.
SKILLS=(review-paper verify-claims proofread seven-pass-review respond-to-referees
        audit-reproducibility analyze-paper humanizer tikz validate-bib)
AGENTS=(claim-verifier domain-referee methods-referee editor proofreader)
# memory: project on exactly these four. claim-verifier is deliberately absent: it is the CoVe
# fresh-context verifier, and project memory would defeat the independence the mechanism buys.
MEMORY_AGENTS=(domain-referee methods-referee editor proofreader)
# Fields plugins-reference lists as unsupported in plugin-shipped agent frontmatter.
BANNED_AGENT_FIELDS=(permissionMode mcpServers hooks)
# Names that came over from the upstream project but were never shipped here (C9c). A reference
# to one reads as an instruction to run something that does not exist.
DEAD_SLASH_NAMES=(slide-excellence lit-review research-ideation compile-latex extract-tikz commit)
DEAD_AGENT_NAMES=(domain-reviewer)
# Rule files a consumer repo no longer has (C10). Template v0.5.0 composes every always-on rule
# into the project's AGENTS.md (init.sh compose_agents_rules) and moves project-conventions.md
# below its managed region; CLAUDE.md is retired outright (D59). Path-scoped rules
# (operations, pdf-processing, latex-bibtex-discipline, …) still exist and are NOT listed here.
RETIRED_RULES=(post-flight-verification knowledge-work-structure project-conventions autonomous-work
               pr-discipline session-logging reading-before-editing citation-discipline
               prompt-shaping writing-quality humanize-prose cross-artifact-review
               proofreading-protocol code-craft testing-discipline CLAUDE)

# The one file exempt from group C. It is byte-identical to upstream blader/humanizer v3.0.0 and
# carries upstream's own install instructions (`npx skills add blader/humanizer`, the resulting
# `/humanizer:humanizer` name). C4 verifies that byte-identity, so the exemption cannot hide drift.
VENDORED_EXEMPT="skills/humanizer/README.md"
HUMANIZER_UPSTREAM="https://github.com/blader/humanizer.git"
HUMANIZER_REF="v3.0.0"
HUMANIZER_FILES=(SKILL.md README.md LICENSE)

PASS=0; FAIL=0; SKIP=0
RUN_INSTALL=1
[ "${1:-}" = "--no-install" ] && RUN_INSTALL=0

ok()   { PASS=$((PASS+1)); printf '  \033[32mPASS\033[0m  %s\n' "$1"; }
bad()  { FAIL=$((FAIL+1)); printf '  \033[31mFAIL\033[0m  %s\n' "$1"; [ -n "${2:-}" ] && printf '        %s\n' "$2"; }
skip() { SKIP=$((SKIP+1)); printf '  \033[33mSKIP\033[0m  %s\n' "$1"; }
group(){ printf '\n\033[1m%s\033[0m\n' "$1"; }
die()  { printf '\033[31mENV ERROR:\033[0m %s\n' "$1" >&2; exit 2; }

[ -d "$PLUGIN_DIR" ] || die "plugin not found at $PLUGIN_DIR"
command -v python3 >/dev/null || die "python3 required (frontmatter YAML parsing)"

HAVE_CLAUDE=0
command -v claude >/dev/null && HAVE_CLAUDE=1

# join an array with |, for use inside an ERE alternation
join_alt() { local IFS='|'; printf '%s' "$*"; }

# ERE-portable word guards. grep -P is unavailable on stock macOS, so instead of lookaround we
# bracket the match with explicit "not a path/identifier character" classes. This is what keeps
# `/tmp/tikz-baseline.txt` (a real shell path in tikz/SKILL.md) and `/humanizer:humanizer`
# (upstream's own namespaced name) from reading as bare-name references.
NOT_BEFORE='(^|[^[:alnum:]_/:.-])'
NOT_AFTER='($|[^[:alnum:]_/:.-])'

# ---------------------------------------------------------------------------------------------
group "A · manifests — claude plugin validate"

if [ "$HAVE_CLAUDE" -eq 0 ]; then
  skip "A1 claude plugin validate $PLUGIN_NAME (claude CLI not on PATH)"
  skip "A2 claude plugin validate . --strict (claude CLI not on PATH)"
else
  out=$(cd "$MKT_ROOT" && claude plugin validate "$PLUGIN_NAME" 2>&1); rc=$?
  [ $rc -eq 0 ] && ok "A1 plugin manifest validates" \
                || bad "A1 plugin manifest validates" "$out"

  out=$(cd "$MKT_ROOT" && claude plugin validate "$PLUGIN_NAME" --strict 2>&1); rc=$?
  [ $rc -eq 0 ] && ok "A2 plugin manifest validates --strict" \
                || bad "A2 plugin manifest validates --strict" "$out"

  out=$(cd "$MKT_ROOT" && claude plugin validate . --strict 2>&1); rc=$?
  [ $rc -eq 0 ] && ok "A3 marketplace manifest validates --strict" \
                || bad "A3 marketplace manifest validates --strict" "$out"
fi

# plugin.json is the single source of version truth (Phase-0 U9 rider: plugin.json wins at install
# time without warning, so a duplicate in the marketplace entry can only drift).
ver=$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1])).get("version",""))' \
        "$PLUGIN_DIR/.claude-plugin/plugin.json" 2>/dev/null)
[ -n "$ver" ] && ok "A4 plugin.json declares a version ($ver)" \
              || bad "A4 plugin.json declares a version"

dup=$(python3 - "$MKT_ROOT/.claude-plugin/marketplace.json" "$PLUGIN_NAME" <<'PY'
import json,sys
m=json.load(open(sys.argv[1]))
print(next((("version" in p) for p in m.get("plugins",[]) if p.get("name")==sys.argv[2]), False))
PY
)
[ "$dup" = "False" ] && ok "A5 marketplace entry carries no duplicate version (U9 rider)" \
                     || bad "A5 marketplace entry carries no duplicate version (U9 rider)" \
                            "remove \"version\" from the $PLUGIN_NAME entry — plugin.json wins silently"

# A6/A7 — the vendor-neutral marketplace path. Codex (Agent Plugins 1.0; TSC = OpenAI/Microsoft/
# Amazon/Cursor/Vercel) resolves `.agents/plugins/marketplace.json` FIRST and only falls back to
# `.claude-plugin/marketplace.json` through a compat branch its own source calls "legacy". A
# symlink serves the neutral path while keeping exactly one file as the source of truth — verified
# empirically: `codex plugin marketplace add <dir>` resolves and installs through the neutral name.
# The link must stay RELATIVE, or it breaks the moment the tree is cloned or moved.
NEUTRAL_MKT="$MKT_ROOT/.agents/plugins/marketplace.json"
CANON_MKT="$MKT_ROOT/.claude-plugin/marketplace.json"

nprobs=""
[ -L "$NEUTRAL_MKT" ] || nprobs="$nprobs not-a-symlink"
# -e follows the link, so a dangling link fails here rather than passing vacuously downstream
[ -e "$NEUTRAL_MKT" ] || nprobs="$nprobs dangling-or-missing"
if [ -z "$nprobs" ]; then
  case "$(readlink "$NEUTRAL_MKT")" in
    /*) nprobs="$nprobs absolute-link" ;;
  esac
  # realpath via python3: BSD readlink on stock macOS has no -f, and this suite must run there
  rp() { python3 -c 'import os,sys;print(os.path.realpath(sys.argv[1]))' "$1"; }
  real_n=$(rp "$NEUTRAL_MKT"); real_c=$(rp "$CANON_MKT")
  [ "$real_n" = "$real_c" ] || nprobs="$nprobs resolves-to:$real_n(want:$real_c)"
fi
[ -z "$nprobs" ] \
  && ok "A6 .agents/plugins/marketplace.json is a relative symlink to the .claude-plugin file" \
  || bad "A6 vendor-neutral marketplace path broken" \
         "$nprobs — Codex checks .agents/ first; .claude-plugin/ is its 'legacy' fallback"

if ! command -v jq >/dev/null; then
  skip "A7 both marketplace paths parse to identical JSON (jq not on PATH)"
elif [ ! -e "$NEUTRAL_MKT" ] || [ ! -e "$CANON_MKT" ]; then
  bad "A7 both marketplace paths parse to identical JSON" "one of the two paths does not resolve"
else
  jn=$(jq -S . "$NEUTRAL_MKT" 2>&1); rcn=$?
  jc=$(jq -S . "$CANON_MKT" 2>&1); rcc=$?
  if [ $rcn -ne 0 ] || [ $rcc -ne 0 ]; then
    bad "A7 a marketplace path does not parse as JSON" "$jn $jc"
  elif [ -z "$jn" ] || [ -z "$jc" ]; then
    # empty-vs-empty would compare equal, which is how a broken path passes vacuously
    bad "A7 a marketplace path parsed to empty JSON" "neutral:${#jn} bytes canonical:${#jc} bytes"
  elif [ "$jn" = "$jc" ]; then
    ok "A7 both marketplace paths parse to identical JSON (jq -S)"
  else
    bad "A7 the two marketplace paths disagree" \
        "$(diff <(printf '%s\n' "$jc") <(printf '%s\n' "$jn") | head -20)"
  fi
fi

# ---------------------------------------------------------------------------------------------
group "B · frontmatter lint — the fields claude plugin validate does not check (m1)"

lint=$(python3 - "$PLUGIN_DIR" "${BANNED_AGENT_FIELDS[*]}" "${AGENTS[*]}" "${MEMORY_AGENTS[*]}" "${SKILLS[*]}" <<'PY'
import pathlib, re, sys, json
try:
    import yaml
except ImportError:
    print(json.dumps({"envskip": True})); sys.exit(0)
root = pathlib.Path(sys.argv[1])
banned, agents = sys.argv[2].split(), sys.argv[3].split()
mem_expected, skills = set(sys.argv[4].split()), sys.argv[5].split()
errs = []
def fm_of(p):
    m = re.match(r"^---\n(.*?)\n---\n", p.read_text(), re.S)
    if not m:
        errs.append(f"{p.relative_to(root)}: no YAML frontmatter"); return None
    try: return yaml.safe_load(m.group(1)) or {}
    except yaml.YAMLError as e:
        errs.append(f"{p.relative_to(root)}: invalid YAML: {e}"); return None
names, mem = [], set()
for p in sorted((root/"agents").glob("*.md")):
    fm = fm_of(p)
    if fm is None: continue
    for b in banned:
        if b in fm: errs.append(f"{p.relative_to(root)}: BANNED field '{b}'")
    n = fm.get("name")
    if not n: errs.append(f"{p.relative_to(root)}: no 'name'")
    else: names.append(n)
    if fm.get("memory") == "project": mem.add(n)
if sorted(names) != sorted(agents):
    errs.append(f"agent set: expected {sorted(agents)} got {sorted(names)}")
if mem != mem_expected:
    errs.append(f"memory:project set: expected {sorted(mem_expected)} got {sorted(mem)}")
cv = root/"agents"/"claim-verifier.md"
if cv.exists() and "deliberately NO memory: project" not in cv.read_text():
    errs.append("claim-verifier.md: lost the comment documenting its deliberate lack of memory:project")
sk = []
for p in sorted(root.glob("skills/*/SKILL.md")):
    fm = fm_of(p)
    if fm is None: continue
    n = fm.get("name") or p.parent.name
    sk.append(n)
    if not fm.get("description"): errs.append(f"{p.relative_to(root)}: no 'description'")
    for b in banned:
        if b in fm: errs.append(f"{p.relative_to(root)}: skill carries banned field '{b}'")
if sorted(sk) != sorted(skills):
    errs.append(f"skill set: expected {sorted(skills)} got {sorted(sk)}")
print(json.dumps({"errors": errs}))
PY
)

if printf '%s' "$lint" | grep -q '"envskip"'; then
  skip "B1-B4 frontmatter lint (python yaml module unavailable)"
else
  nerr=$(printf '%s' "$lint" | python3 -c 'import json,sys;print(len(json.load(sys.stdin)["errors"]))')
  if [ "$nerr" -eq 0 ]; then
    ok "B1 no banned frontmatter fields (${BANNED_AGENT_FIELDS[*]}) in any agent"
    ok "B2 all agent + SKILL.md frontmatter parses as YAML"
    ok "B3 memory:project on exactly ${#MEMORY_AGENTS[@]} agents; claim-verifier's absence documented"
    ok "B4 shipped skill/agent sets match the declared inventory"
  else
    printf '%s' "$lint" | python3 -c \
      'import json,sys;[print("        "+e) for e in json.load(sys.stdin)["errors"]]'
    bad "B1-B4 frontmatter lint ($nerr problem(s))"
  fi
fi

# grep backstop, independent of the YAML parser: the banned fields must not appear as frontmatter
# keys at all. Scoped to the frontmatter block so prose mentioning "hooks" cannot trip it.
banned_hits=$(python3 - "$PLUGIN_DIR" "${BANNED_AGENT_FIELDS[*]}" <<'PY'
import pathlib,re,sys
root=pathlib.Path(sys.argv[1]); banned=sys.argv[2].split(); hits=[]
for p in sorted((root/"agents").glob("*.md")):
    m=re.match(r"^---\n(.*?)\n---\n", p.read_text(), re.S)
    if not m: continue
    for i,line in enumerate(m.group(1).splitlines(),2):
        for b in banned:
            if re.match(rf"\s*{b}\s*:", line):
                hits.append(f"{p.relative_to(root)}:{i}: {line.strip()}")
print("\n".join(hits))
PY
)
[ -z "$banned_hits" ] && ok "B5 grep backstop: no banned key appears in any agent frontmatter" \
                      || bad "B5 grep backstop: banned key present" "$banned_hits"

# B6 — the tikz description must LEAD with the write path. Empirically grounded: with the old
# repair-first lead ("Audit and fix … a downstream repair tool — not a safety net"), Codex asked to
# DRAFT a new figure reasoned that agentic-paper:tikz "is mainly for auditing and repairing an
# existing TikZ figure, not drafting one from scratch" and declined to load the skill — so the
# PREVENTION.md rules that v0.3 deliberately moved INTO this skill never fired. Mere PRESENCE of a
# write-path phrase is not the guard (the old string had one, buried in the last clause): this
# asserts ORDER — write path before repair path — and that the old lead framing is gone.
tikz_guard=$(python3 - "$PLUGIN_DIR/skills/tikz/SKILL.md" <<'PY'
import re, sys
txt = open(sys.argv[1]).read()
m = re.match(r"^---\n(.*?)\n---\n", txt, re.S)
probs, desc = [], ""
if not m:
    probs.append("no YAML frontmatter")
else:
    d = re.search(r"^description:[ \t]*(\S.*)$", m.group(1), re.M)
    if not d:
        probs.append("no single-line description")
    else:
        desc = d.group(1).strip()
low = desc.lower()
write  = re.search(r"before (writing|drafting|creating)", low)
# deliberately NOT a bare /repair|fix/: the prevention clause legitimately says "beats TikZ
# repaired twice", which would satisfy a loose regex and leave this half of B6 green even if the
# whole repair clause were deleted. These alternatives can only come from the repair clause.
repair = re.search(r"repair path|audit|labels overlap|arrows cross", low)
if not write:
    probs.append("no write-path signal — want /before (writing|drafting|creating)/")
if not repair:
    probs.append("lost the repair-path signal — want /repair path|audit|labels overlap|arrows cross/")
if write and repair and write.start() > repair.start():
    probs.append(f"write-path signal at char {write.start()} trails repair-path signal "
                 f"at char {repair.start()} — the repair-first framing is what Codex tripped on")
if re.search(r"downstream repair tool|not a safety net", low):
    probs.append("still carries the repair-first lead framing")
print("\n".join(probs))
PY
)
[ -z "$tikz_guard" ] \
  && ok "B6 tikz description leads with the write path and still covers repair" \
  || bad "B6 tikz description misframes the skill (models will skip it when drafting)" "$tikz_guard"

# ---------------------------------------------------------------------------------------------
group "C · D5 namespacing — zero bare names, zero stale scaffold paths"

SKILL_ALT="$(join_alt "${SKILLS[@]}")"
AGENT_ALT="$(join_alt "${AGENTS[@]}")"

# C1 — bare skill invocation. `/name` unless it is part of a longer path or already namespaced.
# The exemption is matched as a path SUFFIX, not anchored with `^\./`: some greps (ugrep, and any
# `grep` alias) omit the `./` prefix on a recursive scan, which would make an anchored filter fail
# silently and this assertion pass or fail for the wrong reason.
[ -f "$PLUGIN_DIR/$VENDORED_EXEMPT" ] \
  && ok "C0 the group-C exemption target exists ($VENDORED_EXEMPT)" \
  || bad "C0 exemption target missing" "$VENDORED_EXEMPT — a rename would silently widen the exemption"

bare=$(cd "$PLUGIN_DIR" && grep -rnE "${NOT_BEFORE}/(${SKILL_ALT})${NOT_AFTER}" . 2>/dev/null \
         | grep -vF "$VENDORED_EXEMPT:")
[ -z "$bare" ] && ok "C1 no bare /skill-name references (${#SKILLS[@]} names checked)" \
               || bad "C1 bare /skill-name references found" "$(printf '%s' "$bare" | head -20)"

# C2 — hard agent dispatch. A literal string match with no model in the loop: this is the site
# that breaks *silently* if left bare (v0.3 plan review, M2).
disp=$(cd "$PLUGIN_DIR" && grep -rnE "subagent_type=(${AGENT_ALT})" . 2>/dev/null)
[ -z "$disp" ] && ok "C2 every subagent_type= dispatch is namespaced" \
               || bad "C2 un-namespaced subagent_type= dispatch" "$disp"

# C3 — stale scaffold paths for content this plugin now owns. Deliberately NOT a blanket ban on
# `.claude/`: session-reports/, references/journal-profiles.md, rules/*.md and
# templates/journal-profile-template.md are real project paths the plugin correctly points at.
stale=$(cd "$PLUGIN_DIR" && grep -rnE \
          "claude/skills/(${SKILL_ALT})|claude/agents/(${AGENT_ALT})|claude/rules/tikz-snippets" . \
          2>/dev/null)
[ -z "$stale" ] && ok "C3 no stale .claude/{skills,agents,rules/tikz-snippets} paths" \
                || bad "C3 stale scaffold paths found" "$stale"

# C4 — the group-C exemption is only sound while the vendored copy is genuinely upstream.
if [ "$RUN_INSTALL" -eq 0 ]; then
  skip "C4 humanizer byte-identity vs upstream $HUMANIZER_REF (--no-install: needs network)"
elif ! command -v git >/dev/null; then
  skip "C4 humanizer byte-identity vs upstream $HUMANIZER_REF (git not on PATH)"
else
  hz=$(mktemp -d)
  if git clone --quiet --depth 1 --branch "$HUMANIZER_REF" "$HUMANIZER_UPSTREAM" "$hz/up" 2>/dev/null; then
    drift=""
    for f in "${HUMANIZER_FILES[@]}"; do
      cmp -s "$hz/up/$f" "$PLUGIN_DIR/skills/humanizer/$f" || drift="$drift $f"
    done
    [ -z "$drift" ] \
      && ok "C4 humanizer ${HUMANIZER_FILES[*]} byte-identical to upstream $HUMANIZER_REF" \
      || bad "C4 vendored humanizer drifted from upstream $HUMANIZER_REF" \
             "drifted:$drift — the C1 exemption for $VENDORED_EXEMPT is no longer sound"
  else
    skip "C4 humanizer byte-identity (could not reach $HUMANIZER_UPSTREAM)"
  fi
  rm -rf "$hz"
fi

# C5 — every relative markdown link resolves inside the plugin. This is the M3 class: an installed
# plugin cannot reach outside its own directory, so `../../rules/...` is a dangling link, not a
# scaffold reference. Catches both a bad move and a bad rewrite.
broken=$(python3 - "$PLUGIN_DIR" <<'PY'
import re, pathlib, sys
root = pathlib.Path(sys.argv[1]); bad = []
for p in sorted(root.rglob("*.md")):
    for m in re.finditer(r"\]\(([^)#][^)]*)\)", p.read_text()):
        t = m.group(1)
        if t.startswith(("http", "mailto:", "#")): continue
        if not (p.parent / t).resolve().exists():
            bad.append(f"{p.relative_to(root)} -> {t}")
print("\n".join(bad))
PY
)
[ -z "$broken" ] && ok "C5 every relative markdown link resolves inside the plugin (M3)" \
                 || bad "C5 broken relative links" "$broken"

# C7 — no skill or agent pins effort or a model (1.0.2). Skill `effort` OVERRIDES the session
# level, so `effort: high` in a repo running at xhigh made the deep-review skills think LESS.
# D43 rejected upstream's agent pins for the same reason: they override the user's choice.
pins=$(for f in "$PLUGIN_DIR"/skills/*/SKILL.md "$PLUGIN_DIR"/agents/*.md; do
         case "$f" in */skills/humanizer/*) continue ;; esac
         awk -v f="${f#"$PLUGIN_DIR"/}" 'NR==1 && /^---/ {fm=1; next} fm && /^---/ {exit}
           fm && (/^effort:/ || (/^model:/ && !/^model: *inherit *$/)) {print f ": " $0}' "$f"
       done)
[ -z "$pins" ] && ok "C7 no skill or agent pins effort or a model (they inherit the session's)" \
               || bad "C7 effort/model pinned in frontmatter" "$pins"

# C6 — "fork" never means "fresh" (1.0.1). Since Claude Code 2.1.232 a `fork` subagent inherits the
# whole conversation. Our CoVe dispatches used to say `context=fork` and call that a fresh context,
# which invites the one dispatch that hands the verifier the draft it must not see.
forkctx=$(grep -rnE 'context[=:] ?fork' "$PLUGIN_DIR" --include='*.md' | grep -v '/skills/humanizer/')
[ -z "$forkctx" ] && ok "C6a no context=fork anywhere" || bad "C6a context=fork present" "$forkctx"
forkfresh=$(grep -rniE '\bfork(ed)?\b' "$PLUGIN_DIR" --include='*.md' | grep -v '/skills/humanizer/' \
            | grep -viE 'never (use |dispatch it as )?(the |a )?`?fork|not the `fork`|never a fork')
[ -z "$forkfresh" ] && ok "C6b every mention of fork is a prohibition" || bad "C6b fork used as a positive instruction" "$forkfresh"
nowarn=""
while IFS= read -r site; do
  f=${site%%:*}; ln=$(printf '%s' "$site" | cut -d: -f2)
  sed -n "$((ln > 3 ? ln - 3 : 1)),$((ln + 3))p" "$f" | grep -qiE 'never.{0,40}fork' || nowarn="$nowarn$site"$'\n'
done < <(grep -rnE 'subagent_type[=:] ?agentic-paper:claim-verifier' "$PLUGIN_DIR" --include='*.md')
[ -z "$nowarn" ] && ok "C6c every claim-verifier dispatch carries the never-fork warning" \
                 || bad "C6c claim-verifier dispatch without the never-fork warning" "$nowarn"

# C8 — an agent told to write a file holds the tool for it (1.0.2). The editor, both referees and
# the proofreader were told "Write to …/desk_review.md" with tools: Read, Grep, Glob — a report
# that cannot be saved. The claim-verifier is the opposite case: it must stay read-only and
# memoryless, because it is the fresh-context CoVe verifier.
agent_tools=$(python3 - "$PLUGIN_DIR" <<'PY'
import pathlib, re, sys
root = pathlib.Path(sys.argv[1])
# "Write to `path`", "Save each report to `path`", "Append to `desk_review.md`": a write verb,
# up to three words, then to/into and a backticked target.
intent = re.compile(r"\b(write|save|append)s?\b([ \t]+\w+){0,3}?[ \t]+(to|into)[ \t]+`[^`\n]+`", re.I)
miss, cv = [], []
for p in sorted((root / "agents").glob("*.md")):
    m = re.match(r"^---\n(.*?)\n---\n(.*)$", p.read_text(), re.S)
    if not m: continue
    fm, body = m.group(1), m.group(2)
    t = re.search(r"^tools:[ \t]*(.*)$", fm, re.M)
    tools = {x.strip() for x in t.group(1).split(",")} if t else set()
    hit = intent.search(body)
    if hit and "Write" not in tools:
        miss.append(f"A|agents/{p.name}: says \"{hit.group(0)}\" but tools: {', '.join(sorted(tools))}")
    if p.name == "claim-verifier.md":
        for w in sorted(tools & {"Write", "Edit", "MultiEdit", "NotebookEdit"}):
            cv.append(f"B|agents/{p.name}: has {w} in tools")
        if re.search(r"^memory\s*:", fm, re.M):
            cv.append(f"B|agents/{p.name}: has a memory: field")
print("\n".join(miss + cv))
PY
)
# one line per hit, tagged A| or B| by sub-test
c8a=$(printf '%s\n' "$agent_tools" | sed -n 's/^A|//p')
c8b=$(printf '%s\n' "$agent_tools" | sed -n 's/^B|//p')
[ -z "$c8a" ] && ok "C8a every agent told to write a file has Write in tools:" \
              || bad "C8a agent told to write a file it has no tool for" "$c8a"
[ -z "$c8b" ] && ok "C8b claim-verifier has no Write/Edit tool and no memory: (fresh-context CoVe)" \
              || bad "C8b claim-verifier can write or remember" "$c8b"

# C9 — every agent and skill a file names is one this plugin ships (1.0.2). Upstream text named
# /slide-excellence, /lit-review, /commit, a "domain-reviewer" agent, … none of which exist here.
# The shipped sets are read from disk (agents/*.md name:, skills/*/SKILL.md), not from the arrays
# above, so this cannot agree with a stale inventory. Humanizer is vendored upstream text.
unshipped=$(python3 - "$PLUGIN_DIR" "${DEAD_SLASH_NAMES[*]}" "${DEAD_AGENT_NAMES[*]}" <<'PY'
import pathlib, re, sys
root = pathlib.Path(sys.argv[1])
dead_slash, dead_agent = sys.argv[2].split(), sys.argv[3].split()
agents = set()
for p in (root / "agents").glob("*.md"):
    m = re.search(r"^name:[ \t]*(\S+)", p.read_text(), re.M)
    if m: agents.add(m.group(1))
skills = {p.parent.name for p in root.glob("skills/*/SKILL.md")}
builtin = {"general-purpose", "Explore", "Plan"}
out = {"a": [], "b": [], "c": []}
for p in sorted(root.rglob("*.md")):
    rel = p.relative_to(root).as_posix()
    if rel.startswith("skills/humanizer/"): continue
    for n, line in enumerate(p.read_text().splitlines(), 1):
        for m in re.finditer(r"agentic-paper:([A-Za-z0-9_-]+)", line):
            if m.group(1) not in agents | skills:
                out["a"].append(f"A|{rel}:{n}: agentic-paper:{m.group(1)}")
        for m in re.finditer(r"subagent_type\s*[=:]\s*`?([A-Za-z0-9_:.-]+)", line):
            v = m.group(1).rstrip(".")   # a sentence-final period is not part of the name
            if v not in builtin and not (v.startswith("agentic-paper:") and v.split(":", 1)[1] in agents):
                out["b"].append(f"B|{rel}:{n}: subagent_type {v}")
        for d in dead_slash:
            if re.search(rf"(?<![\w/:.-])/{re.escape(d)}(?![\w/:-]|\.\w)", line):
                out["c"].append(f"C|{rel}:{n}: /{d}")
        for d in dead_agent:
            if re.search(rf"(?<![\w-]){re.escape(d)}(?![\w-])", line):
                out["c"].append(f"C|{rel}:{n}: {d}")
print("\n".join(out["a"] + out["b"] + out["c"]))
PY
)
c9a=$(printf '%s\n' "$unshipped" | sed -n 's/^A|//p')
c9b=$(printf '%s\n' "$unshipped" | sed -n 's/^B|//p')
c9c=$(printf '%s\n' "$unshipped" | sed -n 's/^C|//p')
[ -z "$c9a" ] && ok "C9a every agentic-paper:<name> names a shipped skill or agent" \
              || bad "C9a agentic-paper:<name> that this plugin does not ship" "$c9a"
[ -z "$c9b" ] && ok "C9b every subagent_type is a shipped agentic-paper agent or a built-in type" \
              || bad "C9b subagent_type names an agent nobody ships" "$c9b"
[ -z "$c9c" ] && ok "C9c no upstream-only skill or agent names (${#DEAD_SLASH_NAMES[@]} slash + ${#DEAD_AGENT_NAMES[@]} agent)" \
              || bad "C9c references to skills/agents this plugin does not ship" "$(printf '%s' "$c9c" | head -20)"

# C10 — no pointer to a rule file the consumer repo no longer has (1.0.2). Since template v0.5.0
# that text lives in the project's AGENTS.md; point there by section name instead. Matches the
# bare filename too: review-paper cited `knowledge-work-structure.md` with no directory.
RETIRED_ALT="$(join_alt "${RETIRED_RULES[@]}")"
retired=$(grep -rnE "(^|[^[:alnum:]_.-])(${RETIRED_ALT})\.md" "$PLUGIN_DIR" --include='*.md' \
            | grep -v '/skills/humanizer/' | sed "s#^$PLUGIN_DIR/##")
[ -z "$retired" ] && ok "C10 no pointer to a rule file v0.5.0 moved into AGENTS.md (${#RETIRED_RULES[@]} names)" \
                  || bad "C10 pointers to retired rule files" "$retired"

# ---------------------------------------------------------------------------------------------
group "D · version agreement — claude plugin tag --dry-run (Phase-0 carry-item 4)"

if [ "$HAVE_CLAUDE" -eq 0 ]; then
  skip "D1 claude plugin tag --dry-run (claude CLI not on PATH)"
else
  # --force skips the dirty-tree and tag-exists checks, which are release-time concerns; what this
  # asserts is the plugin.json <-> marketplace-entry version agreement.
  out=$(cd "$PLUGIN_DIR" && claude plugin tag --dry-run --force . 2>&1); rc=$?
  if [ $rc -eq 0 ]; then
    ok "D1 plugin tag --dry-run agrees on version ($ver)"
  else
    # a dirty tree / existing tag is not a version disagreement — report it as such
    if printf '%s' "$out" | grep -qi "version mismatch"; then
      bad "D1 plugin.json <-> marketplace version mismatch" "$out"
    else
      bad "D1 plugin tag --dry-run failed" "$out"
    fi
  fi
fi

# ---------------------------------------------------------------------------------------------
group "E · functional — real install into a scratch consumer"

if [ "$RUN_INSTALL" -eq 0 ]; then
  skip "E1-E3 functional install (--no-install)"
elif [ "$HAVE_CLAUDE" -eq 0 ]; then
  skip "E1-E3 functional install (claude CLI not on PATH)"
elif ! command -v jq >/dev/null; then
  skip "E1-E3 functional install (jq required by the verify predicate)"
else
  PRED="$MKT_ROOT/../spikes/phase0-delivery/plugin_installed_here.sh"
  [ -f "$PRED" ] || PRED=""

  CONSUMER="$(mktemp -d)/consumer"; mkdir -p "$CONSUMER"
  CONSUMER="$(cd "$CONSUMER" && pwd -P)"   # macOS /tmp -> /private/tmp; the CLI records physical
  PLUGIN_ID="$PLUGIN_NAME@$MKT_NAME"

  # snapshot the user settings file: --scope project must not touch it (the template ships an
  # Edit(~/.claude/settings.json) deny, so a plugin step that mutates it breaks our own rules)
  USER_SETTINGS="$HOME/.claude/settings.json"
  before_sha=""
  [ -f "$USER_SETTINGS" ] && before_sha=$(shasum -a 256 "$USER_SETTINGS" | cut -d' ' -f1)
  cleanup_e() {
    ( cd "$CONSUMER" 2>/dev/null && claude plugin uninstall "$PLUGIN_ID" -y >/dev/null 2>&1 )
    ( cd "$CONSUMER" 2>/dev/null && claude plugin marketplace remove "$MKT_NAME" >/dev/null 2>&1 )
    # `plugin uninstall` does NOT garbage-collect the marketplace cache (Phase-0 hygiene finding),
    # so remove it here or every run leaves a stale copy of this plugin on the machine.
    rm -rf "${HOME:?}/.claude/plugins/cache/$MKT_NAME"
    rm -rf "$(dirname "$CONSUMER")"
  }
  trap cleanup_e EXIT

  # B3's sequence: marketplace add --scope project, THEN install --scope project. Never user
  # scope — that would mutate ~/.claude/settings.json, which the template's own deny forbids.
  add=$(cd "$CONSUMER" && claude plugin marketplace add "$MKT_ROOT" --scope project 2>&1); rc=$?
  if [ $rc -ne 0 ]; then
    bad "E1 marketplace add --scope project" "$add"
  else
    ok "E1 marketplace add --scope project"
    ins=$(cd "$CONSUMER" && claude plugin install "$PLUGIN_ID" --scope project 2>&1); rc=$?
    [ $rc -eq 0 ] && ok "E2 install $PLUGIN_ID --scope project" \
                  || bad "E2 install $PLUGIN_ID --scope project" "$ins"

    # B1's predicate: `claude plugin list --json` is machine-global, so a naive "the id appears"
    # check greens every repo on the machine. Filter projectPath == realpath($PWD) AND .enabled.
    if [ -n "$PRED" ]; then
      pout=$(cd "$CONSUMER" && bash "$PRED" "$PLUGIN_ID" 2>&1); rc=$?
      [ $rc -eq 0 ] && ok "E3 project-scoped verify predicate (B1) green here" \
                    || bad "E3 project-scoped verify predicate (B1)" "$pout"
    else
      pout=$(cd "$CONSUMER" && claude plugin list --json 2>/dev/null | jq -r --arg h "$CONSUMER" \
               '[.[] | select((.projectPath // "") == $h) | select(.enabled == true) | .id] | .[]')
      printf '%s\n' "$pout" | grep -qx "$PLUGIN_ID" \
        && ok "E3 enabled at project scope for this repo (inline predicate; spike script absent)" \
        || bad "E3 not enabled at project scope for this repo" "saw: $pout"
    fi

    # E4/E5 — the payload actually registered. Parse the "Skills (N)  a, b, c" inventory lines
    # rather than grepping the whole blob: `proofread` is a substring of the `proofreader` agent and
    # `tikz` appears in the plugin description, so a blob grep would pass vacuously.
    det=$(cd "$CONSUMER" && claude plugin details "$PLUGIN_ID" 2>&1)
    inv_line() { printf '%s\n' "$det" | grep -E "^[[:space:]]*$1 \([0-9]+\)" | head -1 \
                   | sed -E "s/^[[:space:]]*$1 \([0-9]+\)[[:space:]]*//"; }
    inv_has() { printf '%s' ",$(printf '%s' "$1" | tr -d ' ')," | grep -q ",$2,"; }

    skills_inv=$(inv_line Skills)
    missing_s=""
    for s in "${SKILLS[@]}"; do inv_has "$skills_inv" "$s" || missing_s="$missing_s $s"; done
    [ -z "$missing_s" ] \
      && ok "E4 all ${#SKILLS[@]} skills in the component inventory (invoked as /$PLUGIN_NAME:<name>)" \
      || bad "E4 skills missing from the component inventory" \
             "missing:$missing_s | inventory: ${skills_inv:-<no Skills line>}"

    agents_inv=$(inv_line Agents)
    missing_a=""
    for a in "${AGENTS[@]}"; do inv_has "$agents_inv" "$a" || missing_a="$missing_a $a"; done
    [ -z "$missing_a" ] \
      && ok "E5 all ${#AGENTS[@]} agents in the component inventory (as $PLUGIN_NAME:<name>)" \
      || bad "E5 agents missing from the component inventory" \
             "missing:$missing_a | inventory: ${agents_inv:-<no Agents line>}"

    # E5b — the M7/D3 decisions are structural, so assert them on the installed artifact: this
    # plugin ships NO hooks (paper hooks stay scaffold-side to preserve opt-in) and NO MCP servers
    # (they stay in the scaffold's .mcp.json.example), and exactly one LSP server.
    probs=""
    printf '%s\n' "$det" | grep -qE "^[[:space:]]*Hooks \(0\)"       || probs="$probs hooks!=0(M7)"
    printf '%s\n' "$det" | grep -qE "^[[:space:]]*MCP servers \(0\)" || probs="$probs mcp!=0(D3)"
    printf '%s\n' "$det" | grep -qE "^[[:space:]]*LSP servers \(1\)" || probs="$probs lsp!=1"
    printf '%s\n' "$det" | grep -q "texlab"                          || probs="$probs no-texlab"
    [ -z "$probs" ] && ok "E5b installed shape: 0 hooks (M7), 0 MCP servers (D3), 1 LSP (texlab)" \
                    || bad "E5b installed shape wrong" "$probs"

    # E6 — measured, not assumed: --scope project must leave ~/.claude/settings.json byte-identical.
    if [ -z "$before_sha" ]; then
      skip "E6 user settings untouched (no $USER_SETTINGS to compare)"
    else
      after_sha=$(shasum -a 256 "$USER_SETTINGS" | cut -d' ' -f1)
      [ "$before_sha" = "$after_sha" ] \
        && ok "E6 ~/.claude/settings.json byte-identical after the project-scope install" \
        || bad "E6 the install MUTATED ~/.claude/settings.json" \
               "sha $before_sha -> $after_sha; the template denies Edit on that file"
    fi
  fi
fi

# ---------------------------------------------------------------------------------------------
printf '\n\033[1mResult:\033[0m %d passed, %d failed, %d skipped\n' "$PASS" "$FAIL" "$SKIP"
[ "$FAIL" -eq 0 ] || exit 1
exit 0
