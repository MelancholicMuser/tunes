#!/usr/bin/env bash
# Installation script for tunes

set -e

INSTALL_DIR="${DESTDIR:-$HOME/.local/bin}"

echo " Installing tunes..."

# Ensure target directory exists
mkdir -p "$INSTALL_DIR"

# Copy script & set permissions
cp tunes "$INSTALL_DIR/tunes"
chmod +x "$INSTALL_DIR/tunes"

echo " Successfully installed tunes to $INSTALL_DIR/tunes"

# Check if INSTALL_DIR is in PATH
if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
  echo ""
  echo "⚠️  Note: $INSTALL_DIR is not currently in your \$PATH."
  echo "   Add the following line to your shell profile (~/.bashrc or ~/.zshrc):"
  echo "     export PATH=\"\$HOME/.local/bin:\$PATH\""
fi

echo ""
echo "🎉 Setup complete! Try running: tunes help"
