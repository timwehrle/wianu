#!/bin/bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "Usage: bash Scripts/create-dmg.sh /path/to/Wianu.app /path/to/Wianu.dmg" >&2
  exit 1
fi

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_PATH="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
OUTPUT_DIR="$(dirname "$2")"
mkdir -p "$OUTPUT_DIR"
OUTPUT_PATH="$(cd "$OUTPUT_DIR" && pwd)/$(basename "$2")"
[[ -d "$APP_PATH/Contents" && "$(basename "$APP_PATH")" == Wianu.app ]] || {
  echo "Expected a Wianu.app bundle: $APP_PATH" >&2; exit 1;
}
[[ ! -e "$OUTPUT_PATH" ]] || { echo "Output already exists: $OUTPUT_PATH" >&2; exit 1; }

WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/wianu-dmg.XXXXXX")"
MOUNT_PATH="$WORK_DIR/mounted"
MOUNTED=0

cleanup() {
  if [[ "$MOUNTED" == 1 ]]; then
    hdiutil detach "$MOUNT_PATH" >/dev/null || return
  fi
  rm -rf "$WORK_DIR"
}

trap cleanup EXIT

mkdir -p "$WORK_DIR/staging/.background"
ditto "$APP_PATH" "$WORK_DIR/staging/Wianu.app"
ln -s /Applications "$WORK_DIR/staging/Applications"
cp "$REPO_ROOT/Packaging/dmg-background.png" "$WORK_DIR/staging/.background/background.png"

hdiutil create -volname Wianu -srcfolder "$WORK_DIR/staging" \
  -fs HFS+ -format UDRW "$WORK_DIR/editable.dmg"
hdiutil attach -readwrite -nobrowse -mountpoint "$MOUNT_PATH" "$WORK_DIR/editable.dmg"
MOUNTED=1

osascript "$REPO_ROOT/Packaging/dmg-layout.applescript" "$MOUNT_PATH"

sync
hdiutil detach "$MOUNT_PATH"
MOUNTED=0
hdiutil convert "$WORK_DIR/editable.dmg" -format UDZO -o "$OUTPUT_PATH"
hdiutil verify "$OUTPUT_PATH"
echo "Created $OUTPUT_PATH"
