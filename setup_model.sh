#!/usr/bin/env bash
# setup_model.sh — One-click model setup for Spasht
#
# This script ensures Python 3 is available, then runs setup_model.py
# which downloads the WhisperKit model into the Xcode project.
#
# Run from the repo root:
#   bash setup_model.sh
#
# Compatible with every Mac out of the box (no prior installs needed).

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo ""
echo "🚀 Spasht — Model Setup"
echo "───────────────────────────────────────────"

# ── Step 1: Find Python 3 ────────────────────────────────────────────────────

PYTHON_CMD=""

for candidate in python3 python; do
    if command -v "$candidate" &>/dev/null; then
        version=$("$candidate" --version 2>&1 | grep -oE '[0-9]+\.[0-9]+' | head -1)
        major=$(echo "$version" | cut -d. -f1)
        if [ "$major" -ge 3 ] 2>/dev/null; then
            PYTHON_CMD="$candidate"
            echo "✅ Found Python $version at: $(command -v $candidate)"
            break
        fi
    fi
done

# ── Step 2: Install Python if missing ────────────────────────────────────────

if [ -z "$PYTHON_CMD" ]; then
    echo "⚠️  Python 3 not found on this machine."
    echo ""

    # Try Homebrew first
    if command -v brew &>/dev/null; then
        echo "📦 Homebrew found — installing Python 3 via Homebrew..."
        brew install python3
        PYTHON_CMD="python3"
        echo "✅ Python 3 installed."
    else
        echo "📦 Homebrew not found — installing Homebrew first..."
        echo "   (This is the standard macOS package manager — safe to install)"
        echo ""
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

        # Add Homebrew to PATH for Apple Silicon Macs
        if [ -f "/opt/homebrew/bin/brew" ]; then
            eval "$(/opt/homebrew/bin/brew shellenv)"
        fi

        echo ""
        echo "📦 Installing Python 3 via Homebrew..."
        brew install python3
        PYTHON_CMD="python3"
        echo "✅ Python 3 installed."
    fi

    echo ""
fi

# ── Step 3: Run the Python setup script ──────────────────────────────────────

echo "───────────────────────────────────────────"
echo "▶  Running setup_model.py with $PYTHON_CMD..."
echo "───────────────────────────────────────────"
echo ""

"$PYTHON_CMD" "$SCRIPT_DIR/setup_model.py"
