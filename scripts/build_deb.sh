#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:-1.2.0}"
VERSION="${VERSION#v}"
ARCH="amd64"
PKG_NAME="villupaatukaaran"
STAGE_DIR="build/deb_staging"
OUTPUT_DIR="build/linux/x64/release"
DEB_FILE="${OUTPUT_DIR}/${PKG_NAME}_${VERSION}_${ARCH}.deb"

echo "Building Debian package for ${PKG_NAME} v${VERSION} (${ARCH})..."

# Clean staging directory
rm -rf "${STAGE_DIR}"
mkdir -p "${STAGE_DIR}/DEBIAN"
mkdir -p "${STAGE_DIR}/opt/${PKG_NAME}"
mkdir -p "${STAGE_DIR}/usr/bin"
mkdir -p "${STAGE_DIR}/usr/share/applications"
mkdir -p "${STAGE_DIR}/usr/share/pixmaps"
mkdir -p "${STAGE_DIR}/usr/share/icons/hicolor/128x128/apps"
mkdir -p "${STAGE_DIR}/usr/share/icons/hicolor/256x256/apps"
mkdir -p "${STAGE_DIR}/usr/share/icons/hicolor/512x512/apps"

# Copy release bundle to /opt/villupaatukaaran/
cp -r build/linux/x64/release/bundle/* "${STAGE_DIR}/opt/${PKG_NAME}/"

# Create symlink in /usr/bin
ln -sf "/opt/${PKG_NAME}/${PKG_NAME}" "${STAGE_DIR}/usr/bin/${PKG_NAME}"

# Copy icons
cp assets/icons/app_icon.png "${STAGE_DIR}/usr/share/pixmaps/${PKG_NAME}.png"
cp assets/icons/app_icon_128.png "${STAGE_DIR}/usr/share/icons/hicolor/128x128/apps/${PKG_NAME}.png"
cp assets/icons/app_icon_256.png "${STAGE_DIR}/usr/share/icons/hicolor/256x256/apps/${PKG_NAME}.png"
cp assets/icons/app_icon_512.png "${STAGE_DIR}/usr/share/icons/hicolor/512x512/apps/${PKG_NAME}.png"

# Create desktop entry
cat << 'EOF' > "${STAGE_DIR}/usr/share/applications/com.harmonymusic.villupaatukaaran.desktop"
[Desktop Entry]
Version=1.0
Type=Application
Name=Villupaatukaaran
GenericName=Tamil Music Player
Comment=Dedicated Tamil Folk & Regional Music Streaming Client
Exec=/opt/villupaatukaaran/villupaatukaaran %U
Icon=villupaatukaaran
Terminal=false
Categories=AudioVideo;Audio;Player;Music;
Keywords=music;tamil;villupaatu;audio;player;streaming;
StartupWMClass=villupaatukaaran
EOF

# Create Debian control file
cat << EOF > "${STAGE_DIR}/DEBIAN/control"
Package: ${PKG_NAME}
Version: ${VERSION}
Section: sound
Priority: optional
Architecture: ${ARCH}
Maintainer: Gokul <https://github.com/gokulnaatheswaran>
Depends: libc6 (>= 2.31), libgtk-3-0 (>= 3.24)
Recommends: libmpv2 | libmpv1
Description: Dedicated Tamil folk and classical music client
 Villupaatukaaran is a modern desktop music streaming application inspired
 by the ancient art of Villupaatu (the musical bow). Built with Flutter,
 MediaKit/libmpv, Innertube, and yt-dlp.
EOF

# Set proper permissions
chmod 755 "${STAGE_DIR}/DEBIAN"
chmod 644 "${STAGE_DIR}/DEBIAN/control"
chmod 755 "${STAGE_DIR}/opt/${PKG_NAME}/${PKG_NAME}"
chmod 644 "${STAGE_DIR}/usr/share/applications/com.harmonymusic.villupaatukaaran.desktop"

# Build deb package
dpkg-deb --build --root-owner-group "${STAGE_DIR}" "${DEB_FILE}"

echo "Debian package created successfully: ${DEB_FILE}"
ls -lh "${DEB_FILE}"

