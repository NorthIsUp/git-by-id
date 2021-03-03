#compdef git-bid=git
# code: language=zsh
#!/usr/bin/env zsh

# Author: Adam Hitchcock
# https://github.com/NorthIsUp/git-by-id

setopt re_match_pcre

# ------------------------------- git-bid-setup ------------------------------ #
(( __GIT_BY_ID_SETUP )) || {
    typeset -g  \
        GIT_IDS_PREFIX_VAR="${GIT_IDS_PREFIX_VAR:-g}" \
        GIT_IDS_CMD=git

    if (( !$+commands[$GIT_IDS_CMD] )) {
        print -u2 "can not find git command"
        exit 1
    }

    compdef git-bid=git git-by-id=git

    local in_pager=0
    [[ "$($commands[$GIT_IDS_CMD] config --get core.pager 2>/dev/null)" =~ 'git-bid-color' ]] && in_pager=1

    # setup git alias support
    typeset -Ag __GIT_BID_ALIASES
    local a _aliases
        
    _aliases=$($commands[$GIT_IDS_CMD] config --get-regexp alias | awk '
        function find_alias(a) { if (a in alias) return find_alias(alias[a]); else return a }
        match($0, /^alias.(\w+)\s+(\w+)/, a) { alias[a[1]]=a[2] }
        match($0, /^alias.(\w+)\s+!.*:\s*git\s+(\w+)/, a) { alias[a[1]]=a[2] }
        END { for(i in alias) print i" "find_alias(i); }')
    for a in ${(f)_aliases} ; {
        __GIT_BID_ALIASES[${a% *}]="${a#* }"
    }

    typeset -rgi \
        __GIT_BY_ID_SETUP=1 \
        __GIT_BY_ID_COLOR_PAGER=$in_pager

    source $functions_source[git-bid] 'git-bid-setup'
}

# ---------------------------------- run it ---------------------------------- #
if [[ "$1" == 'refunc' ]] {
    gx __git-bid-teardown
    return $status
} elif [[ "$1" != 'git-bid-setup' ]] {
    export LINES
    # disable color for now
    if (( 0 && $+functions[git-bid-color] )) {
        if [[ "$1" == diff ]] {
            git-by-id "$@" 2> >(git-bid-color stderr)
        } elif (( $+functions[git-bid-color] )) {
            git-by-id "$@" > >(git-bid-color stdout) 2> >(git-bid-color stderr)
        }
    } else {
        git-by-id "$@"
    }
    return $status
}

(( $+functions[__git-bid-teardown] )) || function __git-bid-teardown() {
    function_path="$functions_source[git-bid]"
    local bid_funcs=(${(k)functions[(I)git-by-id*]} ${(k)functions[(I)git-bid*]})
    print -Pu2 "%F{yellow}unloading functions%F{white}:" "\n  %F{white}- %F{yellow}"${^bid_funcs}"%f"
    gx unset _GIT_BID_ALIASES
    gx unfunction $bid_funcs
    gx autoload git-bid
    gx source $function_path 'git-bid-setup'
}

# --------------------------------- polyfill --------------------------------- #
(( $+functions[log-error] )) || function log-error() {
    xlg "%F{red}$@%f"
}

(( $+functions[log-debug] )) || function log-debug() {
    xlg "%F{grey}$@%f"
}

(( $+functions[gx] )) || function gx() {
    # helper to log a command to stderr
    xlg "%B$1%b ${@:2}"
    "$@"
}

(( $+functions[xlg] )) || function xlg() {
    print -Pu2 "+> $@"
}

# ----------------------------- helper funcitons ----------------------------- #
(( $+functions[git-bid-color] )) || function git-bid-color() {
    [[ "$1" == stderr ]] && extra="a = STDERRIZE(a);"
    gawk -i stdlib.awk -v outfile="/dev/$1" '
    function foo(hello) { return "there"; }
    function recolor(expression, colorize) { a = gensub(expression, colorize, "g", a); }
    BEGIN {
        M1="\\1"
        M2="\\2"

        # git
        recolors["(CONFLICT)"] = RED(M1)
        recolors["(fatal:)(.*)"] = BRIGHT_RED(M1)RED(M2)
        recolors["(Continuing in [[:digit:].]+ seconds)"] = YELLOW(M1)
        recolors["(Everything up-to-date)"] = GREEN(M1)

        # pre-commit
        recolors["(Passed)$"] = GREEN(M1)
        recolors["(Skipped)$"] = YELLOW(M1)
        recolors["(.*Failed)$"] = RED(M1)

        # branches
        recolors["(master)"] = MAGENTA(M1);
        recolors["(main)"] = MAGENTA(M1);
    }
    {
        a = $0
        for (expr in recolors) {
            a = gensub(expr, recolors[expr], "g", a)
        }
        '$extra'
        print(a) > outfile;
    }' -
}

(( $+functions[git-bid-config] )) || function git-bid-config() {
    __config_ret=$($GIT_IDS_CMD config $@ 2>/dev/null)
    print "$__config_ret"
}

(( $+functions[git-bid-shell-usage] )) || function git-bid-shell-usage() {
    # Setup for shell
    cat <<- EOF
	# add the following to an init script
	alias git="git-bid"
	alias gi="git"
	EOF
}


(( $+functions[git-bid-clean-vars] )) || function git-bid-clean-vars() {
    typeset -g \
        GIT_IDS_COUNT=0

    typeset -Ag \
        GIT_IDS=() \
        GIT_IDS_STAGED=() \
        GIT_IDS_UNMERGED=() \
        GIT_IDS_UNSTAGED=() \
        GIT_IDS_UNTRACKED=() \
        GIT_IDS_BRANCHES=()

    unset -m "${GIT_IDS_PREFIX_VAR}[0-9]##"
}

# ------------------------------- git-bid-tgit ------------------------------- #
(( $+functions[git-bid-tgit] )) || function git-bid-tgit() {
    # handle `gi t` and `git git`
    local _g=$fg[green] _m=$fg[magenta] _w=$fg[white] _r=$fg[red] _rc=$reset_color \
        msg args

    [[ "${@:3}" ]] && local extra=" $_m${@:3}$_rc"
    case $1 {
        (t)
            msg="${_w}[${_g}gi ${_r}t${_m}${2#t} ${_w}-> ${_g}git ${_m}${2#t}${_w}]$_rc$extra$_rc"
            args=("${2#t}" "${@:3}")
            ;;
        (git)
            msg="${_w}[${_g}git ${_r}git ${_m}${2} ${_w}-> ${_g}git ${_m}${2}${_w}]$_rc$extra$_rc"
            args=("${@:2}")
            ;;
    }

    xlg "$msg"
    git-bid $args
}

# ------------------------------ git-bid-stash ------------------------------ #
(( $+functions[git-bid-stash] )) || function git-bid-stash() {
    if [[ $1 == stash && $2 == pop ]] {
        # handle stah pop -> git stash pop --quiet &&
        $cmd "$@" --quiet
        shift
    } elif [[ $1 == stash ]] {
        $cmd "$@"
        return $status
    }

    git-bid-number "$@[2,-1]"
}

# ----------------------------- git-bid-checkout ----------------------------- #
(( $+functions[git-bid-checkout] )) || function git-bid-checkout() {
    local bi
    if [[ ${bi:=${@[(i)-b]}} -le ${#@} ]] {
        # check for -b group/project-next
        (( bi++ ))
        local co_branch=${@[$bi]}
        if [[ "$co_branch" =~ "next" ]] {
            local \
                group="$(whoami)" \
                project='' \
                flavor=''

            if [[ "$co_branch" =~ "^next-?(.*)$" ]] {
                flavor="$match[1]"
            } elif [[ "$co_branch" =~ "^(.*)/next-?(.*)$" ]] {
                group="$match[1]"
                flavor="$match[2]"
            } elif [[ "$co_branch" =~ "^(.*)/(.*)-next-?(.*)$" ]] {
                group="$match[1]"
                project="$match[2]"
                flavor="$match[3]"
            }

            local config_key="git-bid.${group}-${project}"
            local counter=${$(git-bid-config "$config_key"):-0}

            git-bid-config --add --int "$config_key" $(( ++counter ))

            [[ "$project" ]] && project="$project-"
            [[ "$flavor" ]] && flavor="-$flavor"

            co_branch="$group/$project$counter$flavor"

            xlg "next branch: %F{magenta}$co_branch%f"

            args=($@)
            args[$bi]="$co_branch"
            set - $args

        }
    }

    # run the git checkout command
    git-bid-number-expand --byid-execute --byid-branch $cmd "$@"
    local co_status=$status
    case "$co_status" {
        ( 0 )
            return 0
            ;;
        ( 128 )
            __git-bid-handle-accidental-branch "$@"
            co_status=$status
            ;;
    }
    if (( co_status )) && [[ "$bi" && "$config_key" && "$counter" ]] {
        # decrement the counter if we failed to make the branch
        git-bid-config --add --int "$" $(( --counter ))
    }
    return $co_status
}

(( $+functions[__git-bid-handle-accidental-branch] )) || function __git-bid-handle-accidental-branch() {
    # if status is 128 check to see if this was an "accidental branch creation"
    result=$(git-bid-number-expand --byid-execute --byid-branch $cmd "$@" 2>&1)
    if [[ "$result" =~ "fatal: A branch named '(.*)' already exists." ]] {
        local branch="${match[1]}"
        local sleep_time=$(printf '%.1f' $(($(git-bid-config help.autocorrect) / 10.0)) )

        msg=(
            "%F{$_orange}WARNING%f: You tried to make a branch that already exists."
            "Continuing in $sleep_time seconds, assuming that you meant 'checkout'."
        )
        print -Pu2 ${(j:\n:)msg}

        sleep $sleep_time

        gx $cmd $1 "$branch"
        return $status
    }
    return 0
}

# ------------------------------- git-bid-push ------------------------------- #
(( $+functions[git-bid-push] )) || function git-bid-push() {
    if [[ -t 1 && "$($cmd branch --show-current)" == "master" ]] {
        local should_push
        until [[ "${should_push:l}" =~ '(y|yes|n|no)$' ]] {
            read should_push\?"Push to master? [y/N]?"
            [[ ${${should_push:-no}:l} =~ '^(n|no|exit)$' ]] && return 1
        }
    }
    $cmd $@
}

# ---------------------------------------------------------------------------- #
#                               number functions                               #
# ---------------------------------------------------------------------------- #

# ------------------------------- number expand ------------------------------ #
(( $+functions[git-bid-number-expand] )) || function git-bid-number-expand() {
    # Allows expansion of numbered shortcuts, ranges of shortcuts, or standard paths.
    # Return a string which can be `eval`ed like: eval args="$(scmb_expand_args "$@")"
    # Numbered shortcut variables are produced by various commands, such as:
    # * git_status_shortcuts()    - git status implementation
    # * git_show_affected_files() - shows files affected by a given SHA1, etc.

    # Check for --relative param
    local \
        branch \
        execute \
        relative \
        remove \
        args=() \
        cmd \
        i

    zparseopts -E -D -- \
        -byid-branch=branch \
        -byid-execute=execute \
        -byid-relative=relative \
        -byid-remove=remove \


    function prel() {
        local p="${GIT_IDS[$1]}"
        [[ $relative ]] && p=${p#$PWD/}

        if [[ "$remove" || "$branch" ]] {
            # just keep going, the branch/file doesn't need to exist
        } elif [[ "$p" && ! -e "$p" ]] {
            log-error "'$p' doesn't seem to exist"
            return 1
        }

        log-debug "[$1] -> $p"
        args+="$p"
    }

    for arg in "$@"; do
        if [[ "$arg" =~ ^[0-9]{0,4}$ ]] {
            # Substitute $e{*} variables for any integers
            if [[ -e "$arg" ]] {
                # Don't expand files or directories with numeric names
                args+="$arg"
            } else {
                prel $arg
            }
        } elif [[ "$arg" =~ ^[0-9]+(-|,|\.\.)[0-9]+$ ]] {
            # Expand ranges into $e{*} variables
            for i in {${arg/${match[1]}/..}}; {
                prel $i
            }
        } else {
            # Otherwise, treat $arg as a normal string.
            args+="$arg"
        }
    done

    cmd=( ${(q-)args[@]} )
    if [[ "$execute" ]] {
        gx $cmd
        return $status
    } else {
        print "$cmd"
        return 0
    }

}

# ------------------------------- number branch ------------------------------ #
(( $+functions[git-bid-number-branch] )) || function git-bid-number-branch() {
    git-bid-clean-vars

    # Fall back to normal git branch, if any unknown args given
    if [[ "$($GIT_IDS_CMD branch | wc -l)" -gt 300 ]] || ([[ -n "$@" ]] && [[ "$@" != "-a" ]]); then
        git-bid-number-expand --byid-execute $GIT_IDS_CMD branch "$@"
        return $status
    fi


    #todo
    # add info about commit message: git log master..$branch --oneline | tail -1

    # Use ruby to inject numbers into git branch output
    ruby -e "$( cat <<-EOF
		output = %x($GIT_IDS_CMD branch --color=always ${@})
		line_count = output.lines.to_a.size
		output.lines.each_with_index do |line, i|
		    spaces = (line_count > 9 && i < 9 ? "    " : " ")
		    puts line.sub(/^([ *]{2})/, "\\\1\033[2;37m[\033[0m#{i+1}\033[2;37m]\033[0m" << spaces)
		end
	EOF
    )"


    # Set numbered file shortcut in variable
    local IFS=$'\n'
    for branch in $($GIT_IDS_CMD branch "$@" | sed "s/^[* ]\{2\}//"); do
        (( GIT_IDS_COUNT++ ))
        export $GIT_IDS_PREFIX_VAR$GIT_IDS_COUNT="$branch"
        GIT_IDS+=([$GIT_IDS_COUNT]="$branch")
        GIT_IDS_BRANCHES+=([$GIT_IDS_COUNT]="$branch")

        log-debug "Set \$$GIT_IDS_PREFIX_VAR$GIT_IDS_COUNT    => $file"
    done

}

# ---------------------------------- number ---------------------------------- #
(( $+functions[git-bid-number] )) || function git-bid-number() {
    # Git status --porcelain output
    # X          Y     Meaning
    # -------------------------------------------------
    #          [AMD]   not updated
    # M        [ MD]   updated in index
    # A        [ MD]   added to index
    # D                deleted from index
    # R        [ MD]   renamed in index
    # C        [ MD]   copied in index
    # [MARC]           index and work tree matches
    # [ MARC]     M    work tree changed since index
    # [ MARC]     D    deleted in work tree
    # [ D]        R    renamed in work tree
    # [ D]        C    copied in work tree
    # -------------------------------------------------
    # D           D    unmerged, both deleted
    # A           U    unmerged, added by us
    # U           D    unmerged, deleted by them
    # U           A    unmerged, added by them
    # D           U    unmerged, deleted by us
    # A           A    unmerged, both added
    # U           U    unmerged, both modified
    # -------------------------------------------------
    # ?           ?    untracked
    # !           !    ignored
    # -------------------------------------------------

    local \
        git_args=(-c color.status=always) \
        output=() \
        grouping \
        line section

    git-bid-clean-vars

    zparseopts -E -D -- q=quiet -quiet=quiet

    git_status=( "${(f@)$(/usr/bin/env git $git_args status "$@")}" )
    GIT_IDS_COUNT=0

    local ob="${fg[white]}[" cb="]$reset_color"

    local ansi='\033\[[[:digit:]|;]*m'
    for line in "${(@)git_status}" ; {
        local match=() found_file=
        if [[ -z $line ]] {
        } elif [[ "$line" =~ "^($ansi)\s+\(.*\)" ]] {
        } elif [[ "$line" =~ 'Changes to be committed:' ]] {
            section=GIT_IDS_STAGED
        } elif [[ "$line" =~ 'Changes not staged for commit:' ]] {
            section=GIT_IDS_UNMERGED
        } elif [[ "$line" =~ 'Unmerged paths:' ]] {
            section=GIT_IDS_UNTRACKED
        } elif [[ "$line" =~ 'Untracked files:' ]] {
            section=GIT_IDS_UNTRACKED
        } elif [[ "$line" =~ "(\s+)($ansi)*(.*[deleted|both modified|modified|new file])(:)(\s+)(.*)$" ]] {
            local match_names=( lpad line_color kind colon rpad found_file ) i=0
            for (( i=1 ; i <= ${#match_names} ; i++ ))  local "${match_names[i]}"="$match[$i]"
            [[ "$__trace__" && "$line_color" ]] && print -P "$kind ${line_color}found a color => %f${(q)line_color}"
            case "$kind" {
                (deleted)         kind="%F{red}-$line_color$kind" ;;
                (new*)            kind="%F{green}%B+%b$line_color$kind" ;;
                (both modified)   kind="%F{magenta}%B~%b%F{red}$kind" ;;
                (modified)        kind="%F{yellow}+$line_color$kind" ;;
                (*)               kind="?$line_color$kind" ; xlg "plz handle '$kind'" ;;
            }
            : $(( ++GIT_IDS_COUNT ))
            local id_pad="__id_pad_${#GIT_IDS_COUNT}"  # add padding to the number based on how many files we have seen
            line="$lpad$ob$GIT_IDS_COUNT$cb$id_pad $kind$colon$line_color$rpad$found_file"
        } elif [[ "$line" =~ "(\t)(.*)" ]] {
            local lpad="$match[1]" found_file="$match[2]"
            line="$lpad$ob$(( ++GIT_IDS_COUNT ))$cb $found_file"
        }

        output+="$line"

        if [[ "${found_file}" ]] {
            found_file="${found_file//$'\033'\[([0-9;])#m/}"
            GIT_IDS+=([$GIT_IDS_COUNT]="$found_file")
            typeset -x "${section}[$GIT_IDS_COUNT]"="$found_file"
            export ${GIT_IDS_PREFIX_VAR:=g}$GIT_IDS_COUNT="$found_file"
        }
    }

    if [[ ! "$quiet" && "$output" ]] {
        # escape ` in output, print -P was interpreting them
        output="${(j:\n:)output:gs/\`/\\\\\`/}\n"
        (( GIT_IDS_COUNT >= 10 )) && output=${output//__id_pad_1/__id_pad_2 }
        (( GIT_IDS_COUNT >= 100 )) && output=${output//__id_pad_2/__id_pad_3 }
        (( GIT_IDS_COUNT >= 1000 )) && output=${output//__id_pad_3/__id_pad_4 }
        (( GIT_IDS_COUNT >= 10000 )) && output=${output//__id_pad_4/ }
        output=${output//__id_pad_[0-9]/}

        print -P "$output"

    }
    return $(( !GIT_IDS_COUNT ))
}


# ---------------------------------------------------------------------------- #
#                                   Git By Id                                  #
# ---------------------------------------------------------------------------- #
(( $+functions[git-by-id] )) || function git-by-id() {
    [[ "$__trace__" ]] && set -x || set +x
    print "[$(date)] git-bid $@" >> /usr/local/var/log/git-bid.log
    local \
        extra_args=() \
        cmd=$commands[$GIT_IDS_CMD] \
        unaliased=${__GIT_BID_ALIASES[$1]:-$1} \
        branch

    if (( $+__GIT_BID_ALIASES[$1] )) {
        xlg "%F{white}[%F{green}git %F{magenta}$1 %F{white}-> %F{green}git %F{magenta}$unaliased%F{white}]%f"
    }

    case $unaliased {
        (*by-id-setup)
            git-bid-shell-usage
            ;;
        (t | git)
            git-bid-tgit "$@"
            ;;
        (stash)
            git-bid-stash "$@"
            ;;
        (status)
            git-bid-number "${@[2,-1]}"
            ;;
        (commit | add | merge )  # add verbose args
            extra_args+=--verbose
            ;&
        (commit | blame | add | log | rebase | merge | difftool)
            git-bid-number-expand --byid-execute $cmd $1 $extra_args "${@:2}"
            ;;
        (rm)
            extra_args+=--byid-remove
            ;&
        (diff | rm | reset)
            git-bid-number-expand --byid-execute --byid-relative $cmd $extra_args "$@"
            ;;
        (checkout)  # branch orenited things
            git-bid-checkout "$@"
            ;;
        (branch)
            git-bid-number-branch "${@:2}"
            ;;
        (next)
            # git next BRANCH_BASE EXTRA_PHRASE
            [[ "$2" ]] || {print -u2 "need a branch name" ; exit 1}
            local phrase=("$2-next" "${3// /-}")
            gx git checkout -b "${(@j:-:)phrase:#}"
            ;;
        (fork)
            gh repo fork "${@:2}"
            ;;

        (push)
            git-bid-push "$@"
            ;;
        (refunc|bid-refunc)
            __git-bid-teardown
            ;;
        (*)
            if (( $+commands[git-$1] || $+functions[git-$1] )) {
                # run custom git-* commands directly
                cmd="git-$1" ; shift
            }
            gx $cmd "$@"
            ;;
    }
    return $status
}

# git-by-id "$@" > >(git-bid-color stdout) 2> >(git-bid-color stderr)
