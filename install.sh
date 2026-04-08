#!/usr/bin/env bash
# shint installer — adds shint to your .bashrc
set -euo pipefail

SHINT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SHINT_SCRIPT="$SHINT_DIR/shint.bash"
BASHRC="${HOME}/.bashrc"
MARKER="# shint"

echo "shint installer"
echo "==============="
echo ""

# ─── Check bash version ─────────────────────────────────────────────
current_bash="${BASH_VERSION%%(*}"
bash_major="${current_bash%%.*}"

if [[ "$bash_major" -lt 4 ]]; then
    echo "WARNING: your current bash is $BASH_VERSION."
    echo "shint requires bash 4.0+."
    echo ""
    if command -v /opt/homebrew/bin/bash &>/dev/null; then
        echo "You have a modern bash at /opt/homebrew/bin/bash. To switch:"
        echo "  sudo sh -c 'grep -qxF /opt/homebrew/bin/bash /etc/shells || echo /opt/homebrew/bin/bash >> /etc/shells'"
        echo "  chsh -s /opt/homebrew/bin/bash"
    elif command -v /usr/local/bin/bash &>/dev/null; then
        echo "You have a modern bash at /usr/local/bin/bash. To switch:"
        echo "  sudo sh -c 'grep -qxF /usr/local/bin/bash /etc/shells || echo /usr/local/bin/bash >> /etc/shells'"
        echo "  chsh -s /usr/local/bin/bash"
    else
        echo "Install modern bash first: brew install bash"
    fi
    echo ""
fi

# ─── Check dependencies ─────────────────────────────────────────────
echo "Dependencies:"
ok=true
for cmd in carapace fzf; do
    if command -v "$cmd" &>/dev/null; then
        printf "  %-10s %s\n" "$cmd" "$(command -v "$cmd")"
    else
        printf "  %-10s MISSING — brew install %s\n" "$cmd" "$cmd"
        ok=false
    fi
done
echo ""
$ok || { echo "Install missing dependencies first."; exit 1; }

# ─── Add to .bashrc ─────────────────────────────────────────────────
if grep -qF "$MARKER" "$BASHRC" 2>/dev/null; then
    echo "shint is already in $BASHRC — skipping."
else
    cat >> "$BASHRC" << EOF

$MARKER
source "$SHINT_SCRIPT"
EOF
    echo "Added shint to $BASHRC"
fi

echo ""
echo "Done! Restart your terminal or run: source $BASHRC"
