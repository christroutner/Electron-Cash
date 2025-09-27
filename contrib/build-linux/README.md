# Building Electron Cash AppImage for Raspberry Pi (ARM64)

This guide provides instructions for building an AppImage of Electron Cash specifically for Raspberry Pi (ARM64 architecture).

⚠️ **Prerequisites**: This guide assumes you have already successfully installed and run Electron Cash on your Raspberry Pi following the main README instructions. All required dependencies should already be installed.

## Overview

The standard AppImage build system is designed for x86_64 architecture. Building for ARM64 requires creating ARM64-specific build files and modifying the build process.

## Step 1: Install Docker (if not already installed)

Since you already have Electron Cash running, Docker might not be installed. Install it now:

```bash
# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Add your user to the docker group
sudo usermod -aG docker $USER

# Log out and log back in, or run:
newgrp docker

# Verify Docker installation
docker --version
```

## Step 2: Create ARM64-Specific Build Files

### Create ARM64 Dockerfile
```bash
cat > contrib/build-linux/appimage/Dockerfile_arm64 << 'EOF'
FROM ubuntu:22.04

ARG UBUNTU_MIRROR=http://ports.ubuntu.com/ubuntu-ports/
ENV UBUNTU_DIST=jammy

# This prevents questions during package installations
ENV DEBIAN_FRONTEND=noninteractive
ENV LC_ALL=C.UTF-8 LANG=C.UTF-8 TZ=America/New_York

RUN echo deb ${UBUNTU_MIRROR} ${UBUNTU_DIST} main restricted universe multiverse > /etc/apt/sources.list && \
    echo deb ${UBUNTU_MIRROR} ${UBUNTU_DIST}-updates main restricted universe multiverse >> /etc/apt/sources.list && \
    echo deb ${UBUNTU_MIRROR} ${UBUNTU_DIST}-backports main restricted universe multiverse >> /etc/apt/sources.list && \
    echo deb ${UBUNTU_MIRROR} ${UBUNTU_DIST}-security main restricted universe multiverse >> /etc/apt/sources.list && \
    apt-get update -q && \
    apt-get install -qy \
        git \
        wget \
        make \
        autotools-dev \
        autoconf \
        libtool \
        xz-utils \
        libffi-dev \
        libncurses5-dev \
        libsqlite3-dev \
        libusb-1.0-0-dev \
        libudev-dev \
        gettext \
        pkg-config \
        libdbus-1-3 \
        libpcsclite-dev \
        swig \
        libxkbcommon-x11-0 \
        libxcb1 \
        libxcb-icccm4 \
        libxcb-image0 \
        libxcb-keysyms1 \
        libxcb-randr0 \
        libxcb-render-util0 \
        libxcb-render0 \
        libxcb-shape0 \
        libxcb-shm0 \
        libxcb-sync1 \
        libxcb-util1 \
        libxcb-xfixes0 \
        libxcb-xinerama0 \
        libxcb-xkb1 \
        libx11-xcb1 \
        autopoint \
        zlib1g-dev \
        libfreetype6 \
        libfontconfig1 \
        libssl-dev \
        gcc \
        g++ \
        rustc \
        cargo \
        squashfs-tools \
        python3 \
        python3-pip \
        python3-dev \
        python3-venv \
        python3-pyqt5 \
        python3-pyqt5.qtsvg \
        python3-pyqt5.qtmultimedia \
        qt5-qmake \
        qtbase5-dev \
        qttools5-dev \
        qttools5-dev-tools \
        libqt5svg5-dev \
        python3-sip-dev \
        python3-sip \
        && \
    rm -rf /var/lib/apt/lists/* && \
    apt-get autoremove -y && \
    apt-get clean

# This is to enable nightly features in the release configuration
ENV RUSTC_BOOTSTRAP=1
# Enable trim-paths feature in cargo 1.75+ to make sure pip paths
# do not end up in binaries making them not reproducible
ENV CARGO_TRIM_PATHS=all
ENV CARGO_UNSTABLE_TRIM_PATHS=true
EOF
```

### Create ARM64 Build Script
```bash
cat > contrib/build-linux/appimage/build_arm64.sh << 'EOF'
#!/bin/bash

here=$(dirname "$0")
test -n "$here" -a -d "$here" || (echo "Cannot determine build dir. FIXME!" && exit 1)

GIT_SUBMODULE_SKIP=1
. "$here"/../../base.sh # functions we use below (fail, et al)
unset GIT_SUBMODULE_SKIP

if [ ! -z "$1" ]; then
    REV="$1"
else
    fail "Please specify a release tag or branch to build (eg: master or 4.0.0, etc)"
fi

if [ ! -d 'contrib' ]; then
    fail "Please run this script form the top-level Electron Cash git directory"
fi

pushd .

docker_version=`docker --version`

if [ "$?" != 0 ]; then
    echo ''
    echo "Please install docker by issuing the following commands:"
    echo ''
    echo '$ curl -fsSL https://get.docker.com -o get-docker.sh'
    echo '$ sudo sh get-docker.sh'
    echo ''
    fail "Docker is required to build AppImage"
fi

set -e

info "Using docker: $docker_version"

# Only set SUDO if its not been set already
if [ -z ${SUDO+x} ] ; then
    SUDO=""  # on macOS (and others?) we don't do sudo for the docker commands ...
    if [ $(uname) = "Linux" ]; then
        # .. on Linux we do
        SUDO="sudo"
    fi
fi

DOCKER_SUFFIX=arm64

info "Creating docker image ..."
$SUDO docker build --progress plain -t electroncash-appimage-builder-img-$DOCKER_SUFFIX \
    -f contrib/build-linux/appimage/Dockerfile_$DOCKER_SUFFIX \
    --build-arg UBUNTU_MIRROR=$UBUNTU_MIRROR \
    contrib/build-linux/appimage \
    || fail "Failed to create docker image"

# This is the place where we checkout and put the exact revision we want to work
# on. Docker will run mapping this directory to /opt/electroncash
FRESH_CLONE=`pwd`/contrib/build-linux/fresh_clone
FRESH_CLONE_DIR=$FRESH_CLONE/$GIT_DIR_NAME

(
    $SUDO rm -fr $FRESH_CLONE && \
        mkdir -p $FRESH_CLONE && \
        cd $FRESH_CLONE  && \
        git clone $GIT_REPO && \
        cd $GIT_DIR_NAME && \
        git checkout $REV
) || fail "Could not create a fresh clone from git"

mkdir "$FRESH_CLONE_DIR/contrib/build-linux/home" || fail "Failed to create home directory"

(
    # NOTE: We propagate forward the GIT_REPO override to the container's env,
    # just in case it needs to see it.
    $SUDO docker run $DOCKER_RUN_TTY \
    -e HOME="/opt/electroncash/contrib/build-linux/home" \
    -e GIT_REPO="$GIT_REPO" \
    -e BUILD_DEBUG="$BUILD_DEBUG" \
    --name electroncash-appimage-builder-cont-$DOCKER_SUFFIX \
    -v $FRESH_CLONE_DIR:/opt/electroncash:delegated \
    --rm \
    --workdir /opt/electroncash/contrib/build-linux/appimage \
    -u $(id -u $USER):$(id -g $USER) \
    electroncash-appimage-builder-img-$DOCKER_SUFFIX \
    ./_build_arm64.sh $REV
) || fail "Build inside docker container failed"

popd

info "Copying built files out of working clone..."
mkdir -p dist/
cp -fpvR $FRESH_CLONE_DIR/dist/* dist/ || fail "Could not copy files"

info "Removing $FRESH_CLONE ..."
$SUDO rm -fr $FRESH_CLONE

echo ""
info "Done. Built AppImage has been placed in dist/"
EOF

chmod +x contrib/build-linux/appimage/build_arm64.sh
```

### Create ARM64 Internal Build Script
```bash
cat > contrib/build-linux/appimage/_build_arm64.sh << 'EOF'
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
    popd
)

python="$APPDIR/usr/bin/python3.11"

info "Installing Electron Cash and its dependencies"
mkdir -p "$CACHEDIR/pip_cache"

# Install dependencies with ARM64-specific considerations
CFLAGS="-g0" "$python" -m pip install --no-deps --no-warn-script-location --no-binary :all: --cache-dir "$CACHEDIR/pip_cache" -r "$CONTRIB/deterministic-build/requirements-pip.txt"
CFLAGS="-g0" "$python" -m pip install --no-deps --no-warn-script-location --no-binary :all: --cache-dir "$CACHEDIR/pip_cache" -r "$CONTRIB/deterministic-build/requirements-build-appimage.txt"
CFLAGS="-g0" "$python" -m pip install --no-deps --no-warn-script-location --no-binary :all: --cache-dir "$CACHEDIR/pip_cache" -r "$CONTRIB/deterministic-build/requirements.txt"

# For PyQt5, we'll use system packages instead of pip binaries
# Install PyQt5 system packages in the container
apt-get update && apt-get install -y python3-pyqt5 python3-pyqt5.qtsvg python3-pyqt5.qtmultimedia

CFLAGS="-g0" "$python" -m pip install --no-deps --no-warn-script-location --cache-dir "$CACHEDIR/pip_cache" "$PROJECT_ROOT"

# Copy desktop integration
info "Copying desktop integration"
cp -fp "$PROJECT_ROOT/electron-cash.desktop" "$APPDIR/electron-cash.desktop"
cp -fp "$PROJECT_ROOT/icons/electron-cash.png" "$APPDIR/electron-cash.png"

# Add launcher
info "Adding launcher"
cp -fp "$CONTRIB/build-linux/appimage/scripts/common_arm64.sh" "$APPDIR/common.sh" || fail "Could not copy python script"
cp -fp "$CONTRIB/build-linux/appimage/scripts/apprun.sh" "$APPDIR/AppRun" || fail "Could not copy AppRun script"
cp -fp "$CONTRIB/build-linux/appimage/scripts/python.sh" "$APPDIR/python" || fail "Could not copy python script"

info "Finalizing AppDir"
(
    export PKG2AICOMMIT="$PKG2APPIMAGE_COMMIT"
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
    cat > ./squashfs-root/usr/lib/appimagekit/mksquashfs << 'EOF'
#!/bin/sh
args=\$(echo "\$@" | sed -e 's/-mkfs-fixed-time 0//')
mksquashfs \$args
EOF
    env VERSION="$VERSION" ARCH=aarch64 SOURCE_DATE_EPOCH=1530212462 \
                ./squashfs-root/AppRun --no-appstream --verbose "$APPDIR" "$APPIMAGE" \
                || fail "AppRun failed"
) || fail "Could not create the AppImage"

info "Done"
ls -la "$DISTDIR"
sha256sum "$DISTDIR"/*
EOF

chmod +x contrib/build-linux/appimage/_build_arm64.sh
```

### Create ARM64 Common Script
```bash
cat > contrib/build-linux/appimage/scripts/common_arm64.sh << 'EOF'
set -e

PYTHON="${APPDIR}/usr/bin/python3.11"

export LD_LIBRARY_PATH="${APPDIR}/usr/lib/:${APPDIR}/usr/lib/aarch64-linux-gnu${LD_LIBRARY_PATH+:$LD_LIBRARY_PATH}"
export PATH="${APPDIR}/usr/bin:${PATH}"
export LDFLAGS="-L${APPDIR}/usr/lib/aarch64-linux-gnu -L${APPDIR}/usr/lib"
EOF
```

## Step 3: Build the AppImage

Now you can build the AppImage for ARM64:

```bash
# Build the AppImage (replace 'master' with your desired tag/branch)
./contrib/build-linux/appimage/build_arm64.sh master
```

## Step 4: Test the AppImage

Once built, test the AppImage:

```bash
# Make the AppImage executable
chmod +x dist/Electron-Cash-*-aarch64.AppImage

# Test the AppImage
./dist/Electron-Cash-*-aarch64.AppImage --help

# Run the GUI
./dist/Electron-Cash-*-aarch64.AppImage
```

## Troubleshooting

### Common Issues and Solutions

1. **Docker Permission Issues**
   ```bash
   # If you get permission denied errors
   sudo usermod -aG docker $USER
   newgrp docker
   ```

2. **ARM64 AppImageTool Not Found**
   - The ARM64 version of appimagetool might not be available
   - You may need to build it from source or use the x86_64 version with emulation

3. **Library Path Issues**
   - If libraries aren't found, check the LD_LIBRARY_PATH in the common script
   - Ensure ARM64 library paths are correctly set

4. **Build Timeouts**
   - ARM64 builds can take 2-4 hours depending on your Raspberry Pi model
   - Consider using a more powerful ARM64 system for faster builds

## Distribution

The built AppImage can be distributed to other Raspberry Pi systems:

```bash
# The AppImage is self-contained and doesn't require installation
# Users can simply make it executable and run it:
chmod +x Electron-Cash-*-aarch64.AppImage
./Electron-Cash-*-aarch64.AppImage
```

## FAQ

### How can I see what is included in the AppImage?
Execute the binary as follows: `./Electron-Cash*.AppImage --appimage-extract`

### How long does the build take?
- Building on Raspberry Pi 4: 2-4 hours
- Building on Raspberry Pi 5: 1-2 hours
- Consider using a more powerful ARM64 system for faster builds

### Can I build for other ARM64 systems?
Yes, the resulting AppImage should work on any ARM64 Linux system, not just Raspberry Pi.