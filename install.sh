#!/usr/bin/env bash
# Installation script for tunes
#   ./install.sh                 install to ~/.local/bin
#   DESTDIR=/usr/local/bin ./install.sh
#   ./install.sh --uninstall     remove the script (your data in ~/.local/share/tunes is kept)

set -euo pipefail

INSTALL_DIR="${DESTDIR:-$HOME/.local/bin}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ "${1:-}" == "--uninstall" ]]; then
  rm -f "$INSTALL_DIR/tunes"
  echo "Removed $INSTALL_DIR/tunes"
  echo "Your listening data was kept in ~/.local/share/tunes (delete it yourself if you want a clean slate)."
  exit 0
fi

echo "Installing tunes..."
mkdir -p "$INSTALL_DIR"
cp "$HERE/tunes" "$INSTALL_DIR/tunes"
chmod +x "$INSTALL_DIR/tunes"
echo "Installed: $INSTALL_DIR/tunes"

if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
  echo
  echo "Note: $INSTALL_DIR is not in your \$PATH."
  echo "  Add this to ~/.bashrc or ~/.zshrc:"
  echo "    export PATH=\"$INSTALL_DIR:\$PATH\""
fi

echo
"$INSTALL_DIR/tunes" doctor || {
  echo
  echo "Some required tools are missing — install them with the hints above, then run: tunes doctor"
}

echo
echo "Done! Run:  tunes           (interactive menu)"
echo "            tunes help      (all commands)"
echo "Tab-completion (optional):  echo 'eval \"\$(tunes completion)\"' >> ~/.bashrc"
