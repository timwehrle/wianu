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
DEVICE_PATH=""

detach_image() {
  local attempt

  for attempt in 1 2 3 4 5; do
    if [[ "$attempt" == 5 ]]; then
      echo "Volume is still busy; forcing detach of temporary image $DEVICE_PATH" >&2
      if hdiutil detach "$DEVICE_PATH" -force; then
        MOUNTED=0
        return 0
      fi
    elif hdiutil detach "$DEVICE_PATH"; then
      MOUNTED=0
      return 0
    fi

    # Detach can fail after unmounting the volume or ejecting the device.
    if hdiutil info -plist > "$WORK_DIR/attachments.plist" \
      && ! grep -Eq "<string>${DEVICE_PATH}(s[0-9]+)*</string>" "$WORK_DIR/attachments.plist"; then
      MOUNTED=0
      return 0
    fi

    if [[ "$attempt" != 5 ]]; then
      echo "Waiting for $DEVICE_PATH to detach (attempt $attempt of 5)…" >&2
      sleep "$((attempt * 2))"
    fi
  done

  echo "Could not detach $DEVICE_PATH; keeping $WORK_DIR for inspection" >&2
  return 1
}

cleanup() {
  if [[ "$MOUNTED" == 1 ]]; then
    detach_image || return
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
hdiutil attach -readwrite -nobrowse -mountpoint "$MOUNT_PATH" \
  -plist "$WORK_DIR/editable.dmg" > "$WORK_DIR/attachment.plist"
DEVICE_PATH="$MOUNT_PATH"
MOUNTED=1
ATTACHED_DEVICE="$(/usr/libexec/PlistBuddy -c 'Print :system-entities:0:dev-entry' "$WORK_DIR/attachment.plist")"
[[ "$ATTACHED_DEVICE" =~ ^(/dev/disk[0-9]+)(s[0-9]+)*$ ]] || {
  echo "Unexpected image device: $ATTACHED_DEVICE" >&2; exit 1;
}
DEVICE_PATH="${BASH_REMATCH[1]}"

osascript "$REPO_ROOT/Packaging/dmg-layout.applescript" "$MOUNT_PATH"

sync
if ! detach_image; then
  trap - EXIT
  exit 1
fi
hdiutil convert "$WORK_DIR/editable.dmg" -format UDZO -o "$OUTPUT_PATH"
hdiutil verify "$OUTPUT_PATH"
echo "Created $OUTPUT_PATH"
