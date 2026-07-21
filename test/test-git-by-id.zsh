#!/usr/bin/env zsh
# Integration smoke test for git-by-id's status parser and exit-code contract.
# Runs the real wrapper against a throwaway repo. Not a framework — just asserts.
emulate -L zsh
# set -u  # plugin reads unset vars by design

typeset -i fails=0
plugin_dir=${0:A:h:h}

pass() { print -P "  %F{green}✓%f $1" }
fail() { print -P "  %F{red}✗%f $1" ; (( fails++ )) }
check() { [[ "$2" == "$3" ]] && pass "$1 ($2)" || fail "$1: expected [$3], got [$2]" }

tmp=$(mktemp -d)
trap 'rm -rf $tmp' EXIT
cd $tmp
git init -q
git config user.email t@example.com
git config user.name  tester
git config status.showUntrackedFiles all   # don't inherit a runner's global "no"
git config commit.gpgsign false            # tests must not depend on a signing agent
git commit -q --allow-empty -m init

# ── build a known working tree ─────────────────────────────────────────────
print tracked          > tracked.txt ; git add tracked.txt ; git commit -qm add
print "modified body" >> tracked.txt              # [unstaged] modified
print staged           > staged.txt  ; git add staged.txt   # [staged]   new file
print utf8             > "café.txt"                # [untracked] non-ASCII name

# ── load the wrapper exactly as a user would ───────────────────────────────
fpath=( $plugin_dir $fpath )
autoload -Uz git-by-id
alias git='git-by-id'

print -P "%F{cyan}git status parse:%f"
git status --info >/dev/null 2>&1     # first call also runs setup
git status        >/dev/null 2>&1
status_rc=$?

check "clean-tree contract: dirty status exits 0"  $status_rc 0
check "staged bucket has the new file"    "${GIT_IDS_STAGED[(r)staged.txt]}"   staged.txt
check "unstaged bucket has the modified"  "${GIT_IDS_UNSTAGED[(r)tracked.txt]}" tracked.txt
# UTF-8 filename must be stored decoded (core.quotePath=false), not as "caf\303\251.txt"
check "utf8 untracked stored decoded"     "${GIT_IDS[(r)café.txt]}"            café.txt
# no ANSI escapes leaked into stored ids (extendedglob strip works)
if [[ "${(j::)GIT_IDS}" == *$'\033'* ]] { fail "ANSI escape leaked into GIT_IDS" } else { pass "no ANSI escapes in stored ids" }

print -P "%F{cyan}add-by-id + branch numbering:%f"
# The status parse above assigned ids; stage the one mapped to tracked.txt.
git status >/dev/null 2>&1
tid=
for k v in ${(kv)GIT_IDS}; do [[ $v == tracked.txt ]] && tid=$k; done
git add $tid >/dev/null 2>&1
check "git add <id> stages the mapped file" "$(command git diff --cached --name-only | grep -c '^tracked.txt$')" 1

# First branch must export $g1 (the post-increment off-by-one fix).
command git branch feat/x >/dev/null 2>&1
git branch >/dev/null 2>&1
[[ -n ${g1:-} ]] && pass "first branch exports \$g1 (=$g1)" || fail "first branch \$g1 unset (post-increment regression)"

# `git tag -v <name>` must VERIFY (and fail), never CREATE the tag (zparseopts -E bug).
git tag -v zzz-verify-me >/dev/null 2>&1
[[ -z "$(command git tag -l zzz-verify-me)" ]] && pass "git tag -v did not create a tag" || fail "git tag -v CREATED a tag (-v was stripped)"

# ── clean tree really returns 0 ────────────────────────────────────────────
git stash -q 2>/dev/null ; git checkout -q -- . 2>/dev/null ; rm -f "café.txt"
git status >/dev/null 2>&1
check "clean-tree status exits 0" $? 0

print
(( fails )) && { print -P "%F{red}$fails assertion(s) failed%f"; exit 1 } || { print -P "%F{green}all assertions passed%f"; exit 0 }
