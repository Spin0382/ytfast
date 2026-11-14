#!/usr/bin/env bash
# Builds the local .deb from an already built binary.
#
#   cargo build --release --locked
#   packaging/deb/build-deb.sh
#
# VERSION can be overridden in the environment; it is the Debian version of
# this package, not the crate version: the crate stays at upstream's, so
# Cargo.lock and the updater's version comparison keep working.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BIN="${BIN:-$ROOT/target/release/youtfast}"
VERSION="${VERSION:-0.8.0+h264.1-1}"
PKG="youtfast"
ARCH="amd64"
OUT="${OUT:-$ROOT/dist}"

if [ ! -x "$BIN" ]; then
  echo "missing $BIN: run 'cargo build --release --locked' first" >&2
  exit 1
fi

STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT

install -Dm0755 "$BIN" "$STAGE/usr/bin/$PKG"
install -Dm0644 "$ROOT/packaging/applications/youtfast.desktop" \
  "$STAGE/usr/share/applications/$PKG.desktop"
install -Dm0644 "$ROOT/packaging/icons/youtfast.svg" \
  "$STAGE/usr/share/icons/hicolor/scalable/apps/$PKG.svg"
install -Dm0644 "$ROOT/README.md" "$STAGE/usr/share/doc/$PKG/README.md"
install -Dm0644 "$ROOT/THIRD_PARTY_NOTICES.md" \
  "$STAGE/usr/share/doc/$PKG/THIRD_PARTY_NOTICES.md"
install -Dm0644 "$ROOT/LICENSE" "$STAGE/usr/share/doc/$PKG/copyright"
gzip -9n -c "$ROOT/CHANGELOG.md" > "$STAGE/usr/share/doc/$PKG/changelog.gz"

SIZE_KB="$(du -sk "$STAGE" | cut -f1)"

# The binary links libmpv and the C runtime and loads Wayland, X11, EGL and
# fontconfig at run time, so only these three are hard dependencies. yt-dlp
# (with Python for its own cookie import) fetches the streams; Deno is what
# current yt-dlp needs to solve YouTube's JavaScript challenge.
cat > "$STAGE/DEBIAN/control" <<EOF
Package: $PKG
Version: $VERSION
Architecture: $ARCH
Maintainer: Spin0382 <kenliddz@gmail.com>
Installed-Size: $SIZE_KB
Depends: libc6 (>= 2.39), libgcc-s1, libmpv2
Recommends: yt-dlp, python3, deno
Section: video
Priority: optional
Homepage: https://github.com/bcosta19/youtfast
Description: native YouTube desktop client (H.264 build for this machine)
 YouTFast plays, searches and keeps a library from YouTube in an egui
 window, with libmpv for playback: no browser engine, no telemetry and no
 hosted backend.
 .
 This build is tuned for the machine it was made for: it is compiled for the
 AMD A4-5300B (Piledriver, -C target-cpu=bdver2) and asks yt-dlp for H.264
 video with AAC audio first, so the Radeon Oland decodes playback through
 VA-API instead of falling back to the software AV1/VP9 decoders.
EOF

mkdir -p "$OUT"
DEB="$OUT/${PKG}_${VERSION}_${ARCH}.deb"
rm -f "$DEB"
dpkg-deb --root-owner-group --build "$STAGE" "$DEB" >/dev/null
echo "built $DEB"
