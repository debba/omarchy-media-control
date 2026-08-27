#!/usr/bin/env bash
set -euo pipefail

PLUGIN_ID="debba.media-control"
PLUGIN_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
INSTALL_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/omarchy/plugins/$PLUGIN_ID"

if omarchy plugin list --json 2>/dev/null | jq -e --arg id "$PLUGIN_ID" 'any(.[]; .id == $id and .enabled)' >/dev/null; then
  omarchy plugin disable "$PLUGIN_ID"
fi

if [[ -L "$INSTALL_DIR" && "$(readlink -f -- "$INSTALL_DIR")" == "$PLUGIN_DIR" ]]; then
  rm -- "$INSTALL_DIR"
elif [[ -e "$INSTALL_DIR" || -L "$INSTALL_DIR" ]]; then
  echo "uninstall.sh: not removing unrelated path $INSTALL_DIR" >&2
fi

omarchy-shell shell rescanPlugins
printf 'Uninstalled %s\n' "$PLUGIN_ID"
