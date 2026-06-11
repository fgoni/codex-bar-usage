#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE="$ROOT/Assets/AppIcon.svg"
OUTPUT="$ROOT/Assets/AppIcon.icns"
ICONSET="$ROOT/Assets/AppIcon.iconset"
TMPDIR="$(mktemp -d)"

cleanup() {
  rm -rf "$TMPDIR" "$ICONSET"
}
trap cleanup EXIT

/usr/bin/qlmanage -t -s 1024 -o "$TMPDIR" "$SOURCE" >/dev/null 2>&1
SOURCE_PNG="$TMPDIR/AppIcon.svg.png"

if [[ ! -f "$SOURCE_PNG" ]]; then
  echo "Failed to render $SOURCE" >&2
  exit 1
fi

rm -rf "$ICONSET"
mkdir -p "$ICONSET"

make_icon() {
  local name="$1"
  local size="$2"
  /usr/bin/sips -s format png -z "$size" "$size" "$SOURCE_PNG" --out "$ICONSET/$name" >/dev/null
}

make_icon icon_16x16.png 16
make_icon icon_16x16@2x.png 32
make_icon icon_32x32.png 32
make_icon icon_32x32@2x.png 64
make_icon icon_128x128.png 128
make_icon icon_128x128@2x.png 256
make_icon icon_256x256.png 256
make_icon icon_256x256@2x.png 512
make_icon icon_512x512.png 512
make_icon icon_512x512@2x.png 1024

/usr/bin/iconutil -c icns "$ICONSET" -o "$OUTPUT"
echo "Wrote $OUTPUT"
