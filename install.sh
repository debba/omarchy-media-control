#!/usr/bin/env bash
set -euo pipefail

PLUGIN_ID="debba.media-control"
PLUGIN_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
INSTALL_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/omarchy/plugins/$PLUGIN_ID"
SECTION="${1:-right}"

omarchy plugin validate "$PLUGIN_DIR"
mkdir -p -- "$(dirname -- "$INSTALL_DIR")"

if [[ -e "$INSTALL_DIR" || -L "$INSTALL_DIR" ]]; then
  if [[ ! -L "$INSTALL_DIR" || "$(readlink -f -- "$INSTALL_DIR")" != "$PLUGIN_DIR" ]]; then
    echo "install.sh: $INSTALL_DIR exists and is not this repository's symlink" >&2
    exit 1
  fi
else
  ln -s -- "$PLUGIN_DIR" "$INSTALL_DIR"
fi

omarchy-shell shell rescanPlugins
for _ in {1..50}; do
  if omarchy plugin list --json 2>/dev/null | jq -e --arg id "$PLUGIN_ID" 'any(.[]; .id == $id)' >/dev/null; then
    break
  fi
  sleep 0.1
done

if ! omarchy plugin list --json 2>/dev/null | jq -e --arg id "$PLUGIN_ID" 'any(.[]; .id == $id)' >/dev/null; then
  echo "install.sh: Omarchy did not discover $PLUGIN_ID" >&2
  exit 1
fi

omarchy plugin enable "$PLUGIN_ID" --section "$SECTION"

printf 'Installed %s\n  source: %s\n  link:   %s\n' "$PLUGIN_ID" "$PLUGIN_DIR" "$INSTALL_DIR"
