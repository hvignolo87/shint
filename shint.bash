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

    # Get suggestions from carapace
    local suggestions
    suggestions=$(carapace "$cmd" fish "${tokens[@]}" 2>/dev/null)

    # If last token is empty, also fetch flags and merge both lists
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

    [[ -z "$suggestions" ]] && return

    # Filter carapace errors
    suggestions=$(printf '%s\n' "$suggestions" | grep -v '^ERR' | grep -v '^_$')
    [[ -z "$suggestions" ]] && return

    # If current token exactly matches a suggestion, advance to next level.
    # e.g. "dbt run" → "run" matches exactly → show flags for "dbt run"
    local current_token="${tokens[${#tokens[@]}-1]}"
    if [[ -n "$current_token" ]] && printf '%s\n' "$suggestions" | cut -f1 | grep -qxF "$current_token"; then
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

    # Count
    local count
    count=$(printf '%s\n' "$suggestions" | wc -l | tr -d ' ')

    # Current token (for fzf query and insert)
    local current="${tokens[${#tokens[@]}-1]}"

    # Single result → insert directly
    if [[ "$count" -eq 1 ]]; then
        local value prefix
        value=$(printf '%s' "$suggestions" | cut -f1)
        prefix="${before%"$current"}"
        READLINE_LINE="${prefix}${value} "
        READLINE_POINT=${#READLINE_LINE}
        return
    fi

    # Multiple → fzf picker
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
        $SHINT_FZF_OPTS \
    ) || return

    local value prefix
    value=$(printf '%s' "$selected" | cut -f1)
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
