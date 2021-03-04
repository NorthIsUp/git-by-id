#!/usr/bin/env zsh
#
# No plugin manager is needed to use this file. All that is needed is adding:
#   source {where-unpacked}/git-by-id.plugin.zsh
# to ~/.zshrc.
#

# According to the standard:
# http://zdharma.org/Zsh-100-Commits-Club/Zsh-Plugin-Standard.html
0="${ZERO:-${${0:#$ZSH_ARGZERO}:-${(%):-%N}}}"
0="${${(M)0:#/*}:-$PWD/$0}"

if [[ $PMSPEC != *f* ]] {
    fpath+=( "${0:h}" )
}

print -u2 "loading git-by-id"

autoload git-by-id
print -u2 "loaded ${+functions[git-by-id]}"

@zsh-plugin-run-on-update '__git-bid-teardown --no-setup'
