#!/usr/bin/env bash
# scripts/package-release.sh
# Builds a release tar.gz + sha256 checksum asset for GitHub Releases.
# Run from the project root before tagging a GitHub Release.
#
# Usage:
#   bash scripts/package-release.sh
#
# Output (in dist/):
#   villupaatukaaran-linux-x64.tar.gz
#   villupaatukaaran-linux-x64.tar.gz.sha256

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$PROJECT_ROOT/dist"
BUNDLE_DIR="$PROJECT_ROOT/build/linux/x64/release/bundle"
ASSET_NAME="villupaatukaaran-linux-x64.tar.gz"

# Extract version from pubspec.yaml
VERSION=$(grep '^version:' "$PROJECT_ROOT/pubspec.yaml" | awk '{print $2}' | cut -d'+' -f1)

echo "╔═══════════════════════════════════════════════╗"
echo "║   Villupaatukaaran Release Packager v$VERSION   "
echo "╚═══════════════════════════════════════════════╝"
echo ""

# ─── Build release bundle ─────────────────────────────────────────────────────
echo "→ Building Flutter Linux release…"
cd "$PROJECT_ROOT"
flutter build linux --release

# ─── Bundle updater script ────────────────────────────────────────────────────
echo "→ Bundling updater script…"
mkdir -p "$BUNDLE_DIR/bin"
cp "$PROJECT_ROOT/bin/villupaatukaaran-updater.sh" "$BUNDLE_DIR/bin/"
chmod +x "$BUNDLE_DIR/bin/villupaatukaaran-updater.sh"

# ─── Create dist directory ────────────────────────────────────────────────────
mkdir -p "$DIST_DIR"
ARCHIVE_PATH="$DIST_DIR/$ASSET_NAME"

# ─── Create tar.gz archive ────────────────────────────────────────────────────
echo "→ Creating archive $ASSET_NAME…"
# Archive the bundle contents directly (not a wrapping directory)
# so extraction produces the same flat layout: binary + lib/ + data/ + bin/
tar -czf "$ARCHIVE_PATH" -C "$BUNDLE_DIR" .

# ─── Generate SHA-256 checksum ────────────────────────────────────────────────
echo "→ Generating SHA-256 checksum…"
sha256sum "$ARCHIVE_PATH" | awk '{print $1}' > "$ARCHIVE_PATH.sha256"

# ─── Summary ──────────────────────────────────────────────────────────────────
ARCHIVE_SIZE=$(du -sh "$ARCHIVE_PATH" | awk '{print $1}')
SHA=$(cat "$ARCHIVE_PATH.sha256")

echo ""
echo "✅ Release assets ready:"
echo "   $ARCHIVE_PATH  ($ARCHIVE_SIZE)"
echo "   $ARCHIVE_PATH.sha256"
echo ""
echo "   SHA-256: $SHA"
echo ""
echo "Next steps:"
echo "  1. git tag -a v$VERSION -m 'Release v$VERSION'"
echo "  2. git push origin v$VERSION"
echo "  3. Upload both files to GitHub Release tag: v$VERSION"
echo "     (github.com/gokulnaath17/villupaatukaaran/releases/new?tag=v$VERSION)"

