#!/bin/zsh

set -euo pipefail

PATH="/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"
BREW_BIN="/opt/homebrew/bin/brew"
XRAY_BIN="/opt/homebrew/opt/xray/bin/xray"
CONFIG="/opt/homebrew/etc/xray/config.json"
ASSET_DIR="/opt/homebrew/share/xray"
GEOIP_URL="https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geoip.dat"
GEOSITE_URL="https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geosite.dat"

tmpdir="$(mktemp -d)"
cleanup() {
  rm -rf "$tmpdir"
}
trap cleanup EXIT

echo "[$(date '+%Y-%m-%d %H:%M:%S')] update started"

curl -fsSL "$GEOIP_URL" -o "$tmpdir/geoip.dat"
curl -fsSL "$GEOSITE_URL" -o "$tmpdir/geosite.dat"

# Validate config against the freshly downloaded rule data before swapping files.
XRAY_LOCATION_ASSET="$tmpdir" "$XRAY_BIN" run -test -config "$CONFIG" >/dev/null

mv "$tmpdir/geoip.dat" "$ASSET_DIR/geoip.dat"
mv "$tmpdir/geosite.dat" "$ASSET_DIR/geosite.dat"

"$BREW_BIN" services restart xray >/dev/null

echo "[$(date '+%Y-%m-%d %H:%M:%S')] update completed"
