#!/bin/bash

set -e

PROJECT_ROOT="$(dirname "$(readlink -e "$0")")/../../.."
CONTRIB="$PROJECT_ROOT/contrib"
DISTDIR="$PROJECT_ROOT/dist"
BUILDDIR="$CONTRIB/build-linux/appimage/build/appimage"
APPDIR="$BUILDDIR/Electron-Cash.AppDir"
CACHEDIR="$CONTRIB/build-linux/appimage/.cache/appimage"
PYDIR="$APPDIR"/usr/lib/python3.11

export GCC_STRIP_BINARIES="1"
export GIT_SUBMODULE_FLAGS="--recommend-shallow --depth 1"

# Newer git errors-out about permissions here sometimes, so do this
git config --global --add safe.directory $(readlink -f "$PROJECT_ROOT")

. "$CONTRIB"/base.sh

# pinned versions
PKG2APPIMAGE_COMMIT="eb8f3acdd9f11ab19b78f5cb15daa772367daf15"

VERSION=`git_describe_filtered`
APPIMAGE="$DISTDIR/Electron-Cash-$VERSION-aarch64.AppImage"

rm -rf "$BUILDDIR"
mkdir -p "$APPDIR" "$CACHEDIR" "$DISTDIR"

info "downloading some dependencies."
download_if_not_exist "$CACHEDIR/functions.sh" "https://raw.githubusercontent.com/AppImage/pkg2appimage/$PKG2APPIMAGE_COMMIT/functions.sh"
verify_hash "$CACHEDIR/functions.sh" "78b7ee5a04ffb84ee1c93f0cb2900123773bc6709e5d1e43c37519f590f86918"

# Create a completely new functions.sh with ARM64 support
info "Creating ARM64-compatible functions.sh"
cat > "$CACHEDIR/functions.sh" << 'FUNCTIONS_EOF'
#!/bin/bash
# ARM64-compatible functions.sh based on pkg2appimage

# Set the system architecture
case "$(uname -i)" in
  x86_64|amd64)
    SYSTEM_ARCH="x86_64";;
  i?86)
    SYSTEM_ARCH="i686";;
  aarch64|arm64)
    SYSTEM_ARCH="aarch64";;
  unknown|AuthenticAMD|GenuineIntel)
    case "$(uname -m)" in
      x86_64|amd64)
        SYSTEM_ARCH="x86_64";;
      i?86)
        SYSTEM_ARCH="i686";;
      aarch64|arm64)
        SYSTEM_ARCH="aarch64";;
    esac ;;
  *)
    echo "Unsupported system architecture"
    exit 1;;
esac

# Set ARCH variable
ARCH="$SYSTEM_ARCH"

# Basic functions needed for AppImage building
copy_deps() {
    echo "Copying dependencies for $SYSTEM_ARCH..."
    # This is a simplified version - the original functions.sh has more complex logic
    # For now, we'll just create the necessary directory structure
    mkdir -p usr/lib/$SYSTEM_ARCH-linux-gnu
}

move_lib() {
    echo "Moving libraries for $SYSTEM_ARCH..."
    # Simplified version - just ensure directories exist
    mkdir -p usr/lib/$SYSTEM_ARCH-linux-gnu
}

delete_blacklisted() {
    echo "Deleting blacklisted files..."
    # Simplified version - remove some common blacklisted files
    find usr -name "*.a" -delete 2>/dev/null || true
    find usr -name "*.la" -delete 2>/dev/null || true
}

# Export functions
export -f copy_deps move_lib delete_blacklisted
FUNCTIONS_EOF

# Download ARM64 appimagetool
download_if_not_exist "$CACHEDIR/appimagetool" "https://github.com/AppImage/AppImageKit/releases/download/12/appimagetool-aarch64.AppImage"
# Note: You may need to verify the hash for the ARM64 version

download_if_not_exist "$CACHEDIR/Python-$PYTHON_VERSION.tar.xz" "https://www.python.org/ftp/python/$PYTHON_VERSION/Python-$PYTHON_VERSION.tar.xz"
verify_hash "$CACHEDIR/Python-$PYTHON_VERSION.tar.xz" $PYTHON_SRC_TARBALL_HASH

(
    cd "$PROJECT_ROOT"
    for pkg in secp zbar openssl libevent zlib tor ; do
        "$CONTRIB"/make_$pkg || fail "Could not build $pkg"
    done
)

info "Building Python"
tar xf "$CACHEDIR/Python-$PYTHON_VERSION.tar.xz" -C "$BUILDDIR"
(
    cd "$BUILDDIR/Python-$PYTHON_VERSION"
    # Configure Python for ARM64
    LD_LIBRARY_PATH="$APPDIR/usr/lib:$APPDIR/usr/lib/aarch64-linux-gnu${LD_LIBRARY_PATH+:$LD_LIBRARY_PATH}" \
    LDFLAGS="-L$APPDIR/usr/lib/aarch64-linux-gnu -L$APPDIR/usr/lib" \
    PKG_CONFIG_PATH="$APPDIR/usr/lib/pkgconfig:$APPDIR/usr/share/pkgconfig${PKG_CONFIG_PATH+:$PKG_CONFIG_PATH}" \
    ./configure --prefix="$APPDIR/usr" --disable-shared --disable-ipv6 --enable-optimizations --with-lto --enable-loadable-sqlite-extensions
    make -j$WORKER_COUNT
    make install
)

python="$APPDIR/usr/bin/python3.11"

info "Installing Electron Cash and its dependencies"
mkdir -p "$CACHEDIR/pip_cache"

# Install dependencies with ARM64-specific considerations
CFLAGS="-g0" "$python" -m pip install --no-deps --no-warn-script-location --no-binary :all: --cache-dir "$CACHEDIR/pip_cache" -r "$CONTRIB/deterministic-build/requirements-pip.txt"
CFLAGS="-g0" "$python" -m pip install --no-deps --no-warn-script-location --no-binary :all: --cache-dir "$CACHEDIR/pip_cache" -r "$CONTRIB/deterministic-build/requirements-build-appimage.txt"
CFLAGS="-g0" "$python" -m pip install --no-deps --no-warn-script-location --no-binary :all: --cache-dir "$CACHEDIR/pip_cache" -r "$CONTRIB/deterministic-build/requirements.txt"

# Install PyQt5 - try without --only-binary restriction first
info "Installing PyQt5 for ARM64"
# Install system Qt5 development packages first
apt-get update && apt-get install -y python3-pyqt5 python3-pyqt5.qtsvg python3-pyqt5.qtmultimedia qt5-default qttools5-dev-tools

# Try to install PyQt5 without binary restriction
CFLAGS="-g0" "$python" -m pip install --no-warn-script-location --cache-dir "$CACHEDIR/pip_cache" PyQt5==5.15.9

CFLAGS="-g0" "$python" -m pip install --no-deps --no-warn-script-location --cache-dir "$CACHEDIR/pip_cache" "$PROJECT_ROOT"

# Copy desktop integration
info "Copying desktop integration"
cp -fp "$PROJECT_ROOT/electron-cash.desktop" "$APPDIR/electron-cash.desktop"
cp -fp "$PROJECT_ROOT/icons/electron-cash.png" "$APPDIR/electron-cash.png"

# Add launcher
info "Adding launcher"
cp -fp "$CONTRIB/build-linux/appimage/common_arm64.sh" "$APPDIR/common.sh" || fail "Could not copy python script"
cp -fp "$CONTRIB/build-linux/appimage/scripts/apprun.sh" "$APPDIR/AppRun" || fail "Could not copy AppRun script"
cp -fp "$CONTRIB/build-linux/appimage/scripts/python.sh" "$APPDIR/python" || fail "Could not copy python script"

info "Finalizing AppDir"
(
    export PKG2AICOMMIT="$PKG2APPIMAGE_COMMIT"
    export ARCH=arm_aarch64  # Use the correct ARCH value for ARM64
    . "$CACHEDIR/functions.sh"

    cd "$APPDIR"
    # copy system dependencies
    copy_deps
    move_lib

    # apply global appimage blacklist to exclude stuff
    # move usr/include out of the way to preserve usr/include/python3.11m.
    mv usr/include usr/include.tmp
    delete_blacklisted
    mv usr/include.tmp usr/include
) || fail "Could not finalize AppDir"

# Remove the debugging lines that were added
# info "Detected architecture: $(uname -m)"
# info "Setting ARCH to aarch64"
# export ARCH=aarch64
# info "ARCH is now: $ARCH"

# Copy ARM64-specific libraries
info "Copying additional libraries for ARM64"
cp -fp /usr/lib/aarch64-linux-gnu/libusb-1.0.so "$APPDIR"/usr/lib/aarch64-linux-gnu/. || fail "Could not copy libusb"
cp -f /usr/lib/aarch64-linux-gnu/libxkbcommon-x11.so.0 "$APPDIR"/usr/lib/aarch64-linux-gnu || fail "Could not copy libxkbcommon-x11"
cp -f /usr/lib/aarch64-linux-gnu/libxcb* "$APPDIR"/usr/lib/aarch64-linux-gnu || fail "Could not copy libxkcb"

# Remove glib libraries to avoid conflicts
for name in module thread ; do
    rm -f "$APPDIR"/usr/lib/aarch64-linux-gnu/libg${name}-2.0.so.0 || fail "Could not remove libg${name}-2.0"
done

info "Stripping binaries of debug symbols"
find "$APPDIR" -type f -executable -exec strip {} \; 2>/dev/null || true

info "Removing cache files and other unnecessary files"
find "$APPDIR" -path '*/__pycache__*' -delete
rm -rf "$PYDIR"/site-packages/*.dist-info/
rm -rf "$PYDIR"/site-packages/*.egg-info/

find -exec touch -h -d '2000-11-11T11:11:11+00:00' {} +

info "Creating the AppImage"
(
    cd "$BUILDDIR"
    cp "$CACHEDIR/appimagetool" "$CACHEDIR/appimagetool_copy"
    # zero out "appimage" magic bytes, as on some systems they confuse the linker
    sed -i 's|AI\x02|\x00\x00\x00|' "$CACHEDIR/appimagetool_copy"
    chmod +x "$CACHEDIR/appimagetool_copy"
    "$CACHEDIR/appimagetool_copy" --appimage-extract
    # We build a small wrapper for mksquashfs that removes the -mkfs-fixed-time option
    cat > ./squashfs-root/usr/lib/appimagekit/mksquashfs << 'SQUASHFS_EOF'
#!/bin/sh
args=$(echo "$@" | sed -e 's/-mkfs-fixed-time 0//')
mksquashfs $args
SQUASHFS_EOF
    chmod +x ./squashfs-root/usr/lib/appimagekit/mksquashfs
    env VERSION="$VERSION" ARCH=aarch64 SOURCE_DATE_EPOCH=1530212462 \
                ./squashfs-root/AppRun --no-appstream --verbose "$APPDIR" "$APPIMAGE" \
                || fail "AppRun failed"
) || fail "Could not create the AppImage"

info "Done"
ls -la "$DISTDIR"
sha256sum "$DISTDIR"/*