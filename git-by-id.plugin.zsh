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

if [[ -d "${0:h}/functions" ]] ; then 
    # if the plugin has been split into functions, add the functions directory to the fpath
    fpath+=( "${0:h}/functions/" )
else
    fpath+=( "${0:h}" )
fi

autoload -Uz git-by-id

alias gi='git t'
alias git='git-by-id'
