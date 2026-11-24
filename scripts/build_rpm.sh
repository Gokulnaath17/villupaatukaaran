#!/usr/bin/env bash
# scripts/build_rpm.sh
# Builds a Fedora/RPM package using Podman (no host system changes needed).
# Optionally uploads the .rpm to an existing GitHub Release and cleans up.
#
# Usage:
#   bash scripts/build_rpm.sh [VERSION] [--release] [--clean]
#
# Flags:
#   --release   Upload the .rpm to the matching GitHub Release tag (requires gh)
#   --clean     Remove all build artefacts and the Podman image when done
#
# Examples:
#   bash scripts/build_rpm.sh                        # build only
#   bash scripts/build_rpm.sh 1.3.0                  # build specific version
#   bash scripts/build_rpm.sh --release              # build + push to GitHub
#   bash scripts/build_rpm.sh --release --clean      # build + push + cleanup

set -euo pipefail

# ─── Defaults ────────────────────────────────────────────────────────────────
PKG_NAME="villupaatukaaran"
ARCH="x86_64"
CONTAINER_IMAGE="fedora:42"
DO_RELEASE=false
DO_CLEAN=false

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# ─── Argument parsing ─────────────────────────────────────────────────────────
VERSION_ARG=""
for arg in "$@"; do
  case "$arg" in
    --release) DO_RELEASE=true ;;
    --clean)   DO_CLEAN=true ;;
    --*)       echo "Unknown flag: $arg"; exit 1 ;;
    *)         VERSION_ARG="$arg" ;;
  esac
done

# ─── Resolve version ──────────────────────────────────────────────────────────
if [[ -n "$VERSION_ARG" ]]; then
  VERSION="${VERSION_ARG#v}"
else
  VERSION=$(grep '^version:' "$PROJECT_ROOT/pubspec.yaml" | awk '{print $2}' | cut -d'+' -f1)
fi

BUNDLE_DIR="$PROJECT_ROOT/build/linux/x64/release/bundle"
OUTPUT_DIR="$PROJECT_ROOT/build/linux/x64/release"
RPM_FILE="${OUTPUT_DIR}/${PKG_NAME}-${VERSION}-1.${ARCH}.rpm"

# ─── Banner ───────────────────────────────────────────────────────────────────
echo "╔═══════════════════════════════════════════════╗"
echo "║   Villupaatukaaran RPM Builder v${VERSION}   "
echo "╚═══════════════════════════════════════════════╝"
echo ""

# ─── Pre-flight checks ────────────────────────────────────────────────────────
# Prefer podman, fall back to docker
if command -v podman &>/dev/null; then
  CONTAINER_CMD="podman"
elif command -v docker &>/dev/null; then
  CONTAINER_CMD="docker"
else
  echo "✗ Neither podman nor docker found. Install one to continue."
  exit 1
fi
echo "→ Using container runtime: $CONTAINER_CMD"

if [[ ! -d "$BUNDLE_DIR" ]]; then
  echo "✗ Flutter release bundle not found at: $BUNDLE_DIR"
  echo "  Run first: flutter build linux --release"
  exit 1
fi

if [[ ! -f "$PROJECT_ROOT/assets/icons/app_icon.png" ]]; then
  echo "✗ App icon not found at assets/icons/app_icon.png"
  exit 1
fi

# ─── Create a source tarball of the bundle ────────────────────────────────────
echo "→ Creating source tarball from Flutter bundle…"
TARBALL_NAME="${PKG_NAME}-${VERSION}.tar.gz"
TARBALL_PATH="/tmp/${TARBALL_NAME}"
# Wrap bundle inside a versioned directory so rpmbuild %setup can extract it
TMPBUNDLE="$(mktemp -d)"
mkdir -p "${TMPBUNDLE}/${PKG_NAME}-${VERSION}"
cp -a "${BUNDLE_DIR}/." "${TMPBUNDLE}/${PKG_NAME}-${VERSION}/"
tar -czf "$TARBALL_PATH" -C "$TMPBUNDLE" "${PKG_NAME}-${VERSION}"
rm -rf "$TMPBUNDLE"

# ─── Copy icons so the container can access them ─────────────────────────────
ICONS_TMP="$(mktemp -d)"
cp "$PROJECT_ROOT/assets/icons/app_icon.png"     "${ICONS_TMP}/app_icon.png"
cp "$PROJECT_ROOT/assets/icons/app_icon_128.png" "${ICONS_TMP}/app_icon_128.png"
cp "$PROJECT_ROOT/assets/icons/app_icon_256.png" "${ICONS_TMP}/app_icon_256.png"
cp "$PROJECT_ROOT/assets/icons/app_icon_512.png" "${ICONS_TMP}/app_icon_512.png"

# ─── Generate .spec file ──────────────────────────────────────────────────────
SPEC_PATH="/tmp/${PKG_NAME}.spec"
cat > "$SPEC_PATH" << SPECEOF
Name:           ${PKG_NAME}
Version:        ${VERSION}
Release:        1%{?dist}
Summary:        Dedicated Tamil folk and classical music streaming client
License:        MIT
URL:            https://github.com/gokulnaatheswaran/villupaatukaaran

# Binary release — no compilation needed
Source0:        ${TARBALL_NAME}

BuildArch:      ${ARCH}
AutoReqProv:    no

Requires:       gtk3
Requires:       mpv-libs

%description
Villupaatukaaran is a modern desktop music streaming application inspired
by the ancient art of Villupaatu (the musical bow). Built with Flutter,
MediaKit/libmpv, Innertube, and yt-dlp. Stream Tamil songs, albums and
playlists without login or ads.

%prep
%setup -q

%build
# Binary release — nothing to compile

%install
install -dm 755 %{buildroot}/opt/${PKG_NAME}
install -dm 755 %{buildroot}%{_bindir}
install -dm 755 %{buildroot}%{_datadir}/applications
install -dm 755 %{buildroot}%{_datadir}/pixmaps
install -dm 755 %{buildroot}%{_datadir}/icons/hicolor/128x128/apps
install -dm 755 %{buildroot}%{_datadir}/icons/hicolor/256x256/apps
install -dm 755 %{buildroot}%{_datadir}/icons/hicolor/512x512/apps

# Copy the Flutter bundle
cp -a . %{buildroot}/opt/${PKG_NAME}/

# Wrapper symlink
ln -sf /opt/${PKG_NAME}/${PKG_NAME} %{buildroot}%{_bindir}/${PKG_NAME}

# Icons (copied into the container via /icons volume)
install -m 644 /icons/app_icon.png     %{buildroot}%{_datadir}/pixmaps/${PKG_NAME}.png
install -m 644 /icons/app_icon_128.png %{buildroot}%{_datadir}/icons/hicolor/128x128/apps/${PKG_NAME}.png
install -m 644 /icons/app_icon_256.png %{buildroot}%{_datadir}/icons/hicolor/256x256/apps/${PKG_NAME}.png
install -m 644 /icons/app_icon_512.png %{buildroot}%{_datadir}/icons/hicolor/512x512/apps/${PKG_NAME}.png

# Desktop entry
cat > %{buildroot}%{_datadir}/applications/com.harmonymusic.${PKG_NAME}.desktop << 'DESKTOP'
[Desktop Entry]
Version=1.0
Type=Application
Name=Villupaatukaaran
GenericName=Tamil Music Player
Comment=Dedicated Tamil Folk & Regional Music Streaming Client
Exec=/opt/${PKG_NAME}/${PKG_NAME} %U
Icon=${PKG_NAME}
Terminal=false
Categories=AudioVideo;Audio;Player;Music;
Keywords=music;tamil;villupaatu;audio;player;streaming;
StartupWMClass=${PKG_NAME}
DESKTOP

%post
gtk-update-icon-cache -f -t %{_datadir}/icons/hicolor &>/dev/null || true

%postun
gtk-update-icon-cache -f -t %{_datadir}/icons/hicolor &>/dev/null || true

%files
/opt/${PKG_NAME}/
%{_bindir}/${PKG_NAME}
%{_datadir}/applications/com.harmonymusic.${PKG_NAME}.desktop
%{_datadir}/pixmaps/${PKG_NAME}.png
%{_datadir}/icons/hicolor/128x128/apps/${PKG_NAME}.png
%{_datadir}/icons/hicolor/256x256/apps/${PKG_NAME}.png
%{_datadir}/icons/hicolor/512x512/apps/${PKG_NAME}.png

%changelog
* $(date "+%a %b %d %Y") Gokul <https://github.com/gokulnaatheswaran> - ${VERSION}-1
- Release ${VERSION}
SPECEOF

# ─── Build inside Podman container ───────────────────────────────────────────
echo "→ Pulling container image (${CONTAINER_IMAGE}) if not cached…"
$CONTAINER_CMD pull --quiet "${CONTAINER_IMAGE}"

echo "→ Building RPM inside container…"
$CONTAINER_CMD run --rm \
  --volume "${TARBALL_PATH}:/root/rpmbuild/SOURCES/${TARBALL_NAME}:ro,z" \
  --volume "${SPEC_PATH}:/root/rpmbuild/SPECS/${PKG_NAME}.spec:ro,z" \
  --volume "${ICONS_TMP}:/icons:ro,z" \
  --volume "${OUTPUT_DIR}:/out:z" \
  "${CONTAINER_IMAGE}" \
  bash -c "
    set -euo pipefail
    dnf install -y --quiet rpm-build gtk3 mpv-libs 2>/dev/null
    mkdir -p /root/rpmbuild/{BUILD,RPMS,SRPMS,SOURCES,SPECS}
    rpmbuild -bb /root/rpmbuild/SPECS/${PKG_NAME}.spec
    find /root/rpmbuild/RPMS -name '*.rpm' -exec cp {} /out/ \;
    echo 'RPM build complete.'
  "

# ─── Confirm output ──────────────────────────────────────────────────────────
if [[ ! -f "$RPM_FILE" ]]; then
  echo "✗ Expected RPM not found: $RPM_FILE"
  echo "  Check the files in: $OUTPUT_DIR"
  ls "$OUTPUT_DIR"/*.rpm 2>/dev/null || true
  exit 1
fi

echo ""
echo "✅ RPM built: $(basename "$RPM_FILE")  ($(du -sh "$RPM_FILE" | cut -f1))"
echo "   Path: $RPM_FILE"

# ─── Upload to GitHub Release ─────────────────────────────────────────────────
if [[ "$DO_RELEASE" == true ]]; then
  echo ""
  echo "→ Uploading to GitHub Release v${VERSION}…"

  if ! command -v gh &>/dev/null; then
    echo "✗ gh (GitHub CLI) is not installed. Skipping upload."
  else
    TAG="v${VERSION}"
    # Verify the release exists
    if ! gh release view "$TAG" --repo gokulnaatheswaran/villupaatukaaran &>/dev/null; then
      echo "✗ GitHub Release '$TAG' not found. Create it first, then re-run with --release."
      echo "  gh release create $TAG --title 'v${VERSION}' --generate-notes"
    else
      gh release upload "$TAG" "$RPM_FILE" \
        --repo gokulnaatheswaran/villupaatukaaran \
        --clobber
      echo "✅ Uploaded $(basename "$RPM_FILE") to release $TAG"
    fi
  fi
fi

# ─── Cleanup ──────────────────────────────────────────────────────────────────
if [[ "$DO_CLEAN" == true ]]; then
  echo ""
  echo "→ Cleaning up…"
  rm -f "$TARBALL_PATH"
  rm -f "$SPEC_PATH"
  rm -rf "$ICONS_TMP"
  $CONTAINER_CMD rmi "${CONTAINER_IMAGE}" 2>/dev/null && echo "  Removed container image ${CONTAINER_IMAGE}" || true
  echo "✅ Cleanup done."
else
  # Always clean up temp files even without --clean, just not the image
  rm -f "$TARBALL_PATH" "$SPEC_PATH"
  rm -rf "$ICONS_TMP"
fi

echo ""
