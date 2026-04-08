#!/usr/bin/env bash
# shint — fzf-powered autocomplete for bash, using carapace as data engine
#
# Requires: bash 4.0+, carapace, fzf
# Install deps: brew install carapace fzf
#
# Usage: add to .bashrc:
#   source ~/.shint/shint.bash
#
# Config (set before sourcing):
#   SHINT_HEIGHT="~40%"    # fzf picker height
#   SHINT_FZF_OPTS=""      # extra fzf flags

SHINT_HEIGHT="${SHINT_HEIGHT:-~40%}"
SHINT_FZF_OPTS="${SHINT_FZF_OPTS:-}"

# Commands where directory history suggestions are useful
_SHINT_DIR_CMDS="cd ls cp mv rm mkdir rmdir cat vim nvim nano less head tail chmod chown touch code find tree"

# ─── Extract directory paths from bash history ───────────────────────
_shint_history_dirs() {
    local home="$HOME" cwd="$PWD"

    # Phase 1: extract and normalize paths entirely in awk (no subshells).
    # Produces a deduplicated list of candidate paths, most recent first.
    local candidates
    candidates=$({
        # cd arguments (most reliable)
        grep '^cd ' ~/.bash_history 2>/dev/null | awk '{print $2}'
        # All path-like tokens
        grep -oE '(/?~?\.{0,2}/[^ ]+)' ~/.bash_history 2>/dev/null
    } | tac | awk -v home="$home" -v cwd="$cwd" '
    {
        p = $0
        sub(/\/+$/, "", p)              # strip trailing slashes
        gsub(/\/\/+/, "/", p)           # collapse double slashes
        gsub(/\/\.\//, "/", p)          # collapse /./
        gsub(/\/\.$/, "", p)            # strip trailing /.
        sub(/^~/, home, p)              # expand ~

        # Resolve relative paths against cwd
        if (p !~ /^\//) p = cwd "/" p

        # If it looks like a file (has extension after last /), take dirname
        base = p; sub(/.*\//, "", base)
        if (base ~ /\.[a-zA-Z0-9]+$/) sub(/\/[^\/]+$/, "", p)

        if (p != "" && !seen[p]++) print p
    }')

    # Phase 2: validate and normalize (only ~100-300 unique paths, fast)
    printf '%s\n' "$candidates" | while IFS= read -r p; do
        [[ -d "$p" ]] && (cd "$p" && pwd)
    done | awk '!seen[$0]++'
}

# ─── Completion function ─────────────────────────────────────────────
_shint_complete() {
    local line="$READLINE_LINE"
    local point="$READLINE_POINT"
    local before="${line:0:$point}"

    [[ -z "$before" ]] && return

    # Tokenize: split by spaces
    local -a tokens
    read -ra tokens <<< "$before"
    [[ ${#tokens[@]} -eq 0 ]] && return

    # Carapace needs an empty token to know we want the NEXT argument.
    # "dbt" → add space + empty token → carapace shows subcommands
    # "dbt " → add empty token → same
    # "dbt r" → don't add → carapace filters subcommands by "r"
    if [[ "$before" =~ [[:space:]]$ ]]; then
        tokens+=("")
    elif [[ ${#tokens[@]} -eq 1 ]]; then
        before="$before "
        tokens+=("")
    fi

    local cmd="${tokens[0]}"

    # Resolve aliases to their underlying command
    # e.g. "l" → "ls", so carapace and dir-cmd detection work
    local resolved_cmd="$cmd"
    if type -t "$cmd" 2>/dev/null | grep -q alias; then
        resolved_cmd=$(alias "$cmd" 2>/dev/null | sed -E "s/^alias [^=]+='?//" | sed -E "s/'?$//" | awk '{print $1}')
    fi

    # Get suggestions from carapace (try resolved command if alias)
    local suggestions
    suggestions=$(carapace "$cmd" fish "${tokens[@]}" 2>/dev/null)
    if [[ -z "$suggestions" && "$resolved_cmd" != "$cmd" ]]; then
        suggestions=$(carapace "$resolved_cmd" fish "${tokens[@]}" 2>/dev/null)
    fi

    # Also fetch flags if last token is empty
    if [[ "${tokens[${#tokens[@]}-1]}" == "" ]]; then
        local flag_suggestions
        tokens[${#tokens[@]}-1]="-"
        flag_suggestions=$(carapace "$cmd" fish "${tokens[@]}" 2>/dev/null)
        tokens[${#tokens[@]}-1]=""
        if [[ -n "$flag_suggestions" ]]; then
            if [[ -n "$suggestions" ]]; then
                suggestions="${suggestions}"$'\n'"${flag_suggestions}"
            else
                suggestions="$flag_suggestions"
            fi
        fi
    fi

    # Filter carapace errors
    if [[ -n "$suggestions" ]]; then
        suggestions=$(printf '%s\n' "$suggestions" | grep -v '^ERR' | grep -v '^_$')
    fi

    # Check if this is a path-oriented command
    local is_dir_cmd=false
    local c
    for c in $_SHINT_DIR_CMDS; do
        [[ "$cmd" == "$c" || "$resolved_cmd" == "$c" ]] && { is_dir_cmd=true; break; }
    done

    # If carapace returned nothing and it's not a dir command, bail out
    [[ -z "$suggestions" ]] && ! $is_dir_cmd && return

    # If current token exactly matches a suggestion, advance to next level
    local current_token="${tokens[${#tokens[@]}-1]}"
    if [[ -n "$current_token" ]] && [[ -n "$suggestions" ]] && \
       printf '%s\n' "$suggestions" | cut -f1 | grep -qxF -- "$current_token"; then
        local next_suggestions
        tokens+=("")
        next_suggestions=$(carapace "$cmd" fish "${tokens[@]}" 2>/dev/null)
        if [[ -z "$next_suggestions" ]]; then
            tokens[${#tokens[@]}-1]="-"
            next_suggestions=$(carapace "$cmd" fish "${tokens[@]}" 2>/dev/null)
            tokens[${#tokens[@]}-1]=""
        fi
        if [[ -n "$next_suggestions" ]]; then
            suggestions="$next_suggestions"
            before="$before "
        else
            unset 'tokens[${#tokens[@]}-1]'
        fi
    fi

    # Current token (for fzf query and insert)
    local current="${tokens[${#tokens[@]}-1]}"

    # Styled separator bars (bold black on yellow, 30 chars, centered)
    local _sep_subs=$'\033[1;30;43m         Subcommands          \033[0m'
    local _sep_opts=$'\033[1;30;43m           Options            \033[0m'
    local _sep_cwds=$'\033[1;30;43m      Current directory       \033[0m'
    local _sep_hist=$'\033[1;30;43m     Recent directories       \033[0m'

    # Split suggestions into flags (start with -) and non-flags
    local flags_group="" nonflag_group=""
    if [[ -n "$suggestions" ]]; then
        flags_group=$(printf '%s\n' "$suggestions" | grep '^-')
        nonflag_group=$(printf '%s\n' "$suggestions" | grep -v '^-')
    fi

    # For dir commands, also fetch history directories
    local hist_group=""
    if $is_dir_cmd && [[ "$current" != -* ]]; then
        hist_group=$(_shint_history_dirs)
    fi

    # Build grouped list with separators when there are multiple groups
    local has_flags=false has_nonflag=false has_hist=false
    [[ -n "$flags_group" ]] && has_flags=true
    [[ -n "$nonflag_group" ]] && has_nonflag=true
    [[ -n "$hist_group" ]] && has_hist=true

    # Count how many groups we have
    local group_count=0
    $has_flags && ((group_count++))
    $has_nonflag && ((group_count++))
    $has_hist && ((group_count++))

    if [[ "$group_count" -gt 1 ]]; then
        # Multiple groups → add separators
        local built=""
        if $has_nonflag; then
            local nonflag_label="$_sep_subs"
            $is_dir_cmd && nonflag_label="$_sep_cwds"
            built="${nonflag_label}"$'\n'"${nonflag_group}"
        fi
        if $has_flags; then
            [[ -n "$built" ]] && built="${built}"$'\n'
            built="${built}${_sep_opts}"$'\n'"${flags_group}"
        fi
        if $has_hist; then
            [[ -n "$built" ]] && built="${built}"$'\n'
            built="${built}${_sep_hist}"$'\n'"${hist_group}"
        fi
        # Deduplicate values across groups (keep separator lines)
        suggestions=$(printf '%s\n' "$built" | awk -F'\t' '/^\033\[1;30;43m/ {print; next} !seen[$1]++')
    fi

    [[ -z "$suggestions" ]] && return

    # Count (exclude separator lines)
    local count
    count=$(printf '%s\n' "$suggestions" | grep -cv $'^\033\\[1;30;43m')

    # Single result → insert directly
    if [[ "$count" -eq 1 ]]; then
        local value prefix
        value=$(printf '%s\n' "$suggestions" | grep -v $'^\033\\[1;30;43m' | head -1 | cut -f1)
        prefix="${before%"$current"}"
        READLINE_LINE="${prefix}${value} "
        READLINE_POINT=${#READLINE_LINE}
        return
    fi

    # Multiple → fzf picker
    local -a fzf_extra=()
    [[ "$group_count" -gt 1 ]] && fzf_extra+=(--ansi)

    local selected
    selected=$(printf '%s\n' "$suggestions" | fzf \
        --delimiter=$'\t' \
        --with-nth=1.. \
        --nth=1 \
        --query="$current" \
        --height="$SHINT_HEIGHT" \
        --layout=reverse \
        --border \
        --no-sort \
        --tabstop=30 \
        "${fzf_extra[@]}" \
        $SHINT_FZF_OPTS \
    ) || return

    local value prefix
    value=$(printf '%s' "$selected" | cut -f1)
    # Ignore separator lines (contain ANSI codes)
    [[ "$value" == *$'\033'* ]] && return
    prefix="${before%"$current"}"
    READLINE_LINE="${prefix}${value} "
    READLINE_POINT=${#READLINE_LINE}
}

# ─── Init ────────────────────────────────────────────────────────────
_shint_init() {
    local bash_major="${BASH_VERSINFO[0]}"
    if [[ "$bash_major" -lt 4 ]]; then
        echo "shint: requires bash 4.0+ (you have $BASH_VERSION)" >&2
        echo "  macOS ships bash 3.2. Install modern bash: brew install bash" >&2
        echo "  Then switch: chsh -s /opt/homebrew/bin/bash" >&2
        return 1
    fi

    local missing=()
    command -v carapace &>/dev/null || missing+=("carapace")
    command -v fzf &>/dev/null || missing+=("fzf")
    if [[ ${#missing[@]} -gt 0 ]]; then
        echo "shint: missing: ${missing[*]}. Install with: brew install ${missing[*]}" >&2
        return 1
    fi

    # Bind function to \200, then redirect Tab to \200 via macro.
    # This avoids conflicts with bash's built-in completion system.
    bind -x '"\200": _shint_complete'
    bind '"\C-i": "\200"'
}

_shint_init
