# Electron Cash

This new README contains step-by-step instructions for install Electron Cash on a Raspberry Pi (arm64 architecture) running Ubuntu 22.04.

# Electron Cash - Build Instructions for Ubuntu 22.04 on Raspberry Pi

This guide provides step-by-step instructions for building Electron Cash from source on Ubuntu 22.04 running on Raspberry Pi (ARM64 architecture).

These steps have been tested on a Raspberry Pi 4 B with 4GB of memory and a 32GB SD card. *These should be considered minimal requirements*.

## Prerequisites and System Setup

### 1. Update System
```bash
sudo apt update && sudo apt upgrade -y
```

### 2. Install Essential Build Tools and Dependencies
```bash
sudo apt install -y \
    git \
    python3 \
    python3-pip \
    python3-dev \
    python3-setuptools \
    build-essential \
    libtool \
    automake \
    autotools-dev \
    autoconf \
    pkg-config \
    libssl-dev \
    libffi-dev \
    libusb-1.0-0-dev \
    libudev-dev \
    python3-requests \
    gettext \
    wget \
    curl \
    cmake \
    g++ \
    gcc \
    make \
    libopencv-dev \
    libopencv-contrib-dev
```

### 3. Install PyQt5 System Packages (Critical for Raspberry Pi)
```bash
sudo apt install -y \
    python3-pyqt5 \
    python3-pyqt5.qtsvg \
    python3-pyqt5.qtmultimedia \
    python3-pyqt5.qtwebkit \
    qt5-style-plugins \
    qt5-gtk-platformtheme \
    libqt5gui5 \
    libqt5core5a \
    libqt5widgets5 \
    libqt5svg5 \
    libqt5multimedia5
```

### 4. Install Qt Development Tools (for libsecp256k1 build)
```bash
sudo apt install -y \
    qt5-qmake \
    qtbase5-dev \
    qttools5-dev \
    qttools5-dev-tools \
    libqt5svg5-dev \
    python3-sip-dev \
    python3-sip
```

## Clone and Setup Repository

### 5. Clone Repository and Initialize Submodules
```bash
git clone https://github.com/christroutner/Electron-Cash
cd Electron-Cash
git submodule update --init --recursive
```

## Python Dependencies Installation

### 6. Upgrade pip and setuptools
```bash
pip3 install --user --upgrade pip setuptools wheel
```

### 7. Install Core Python Dependencies
```bash
pip3 install --user -r contrib/requirements/requirements.txt
```

### 8. Install GUI Dependencies (PyQt5 from system packages)
```bash
# Skip PyQt5 installation via pip - use system packages instead
pip3 install --user pycryptodomex psutil cryptography
```

### 9. Install Hardware Wallet Support (Optional)
```bash
sudo apt-get install swig libpcsclite-dev
pip3 install --user -r contrib/requirements/requirements-hw.txt
```

### 10. Handle QR Code Scanning Dependencies
```bash
# Try to install zxing-cpp for QR scanning
pip3 install --user zxing-cpp>=2.3.0

# If that fails (common on Raspberry Pi), continue without it
# QR scanning will be limited but the app will work
```

## Build Native Libraries

### 11. Build libsecp256k1 (Highly Recommended)
```bash
# If you encounter libtool issues, clean and rebuild
cd contrib/secp256k1
./autogen.sh
cd ../..

# Build libsecp256k1
./contrib/make_secp
```

**If libsecp256k1 build fails:**
- The app will work without it but be slower
- CashShuffle will be disabled
- You can skip this step and continue

### 12. Build ZBar for QR Scanning (Alternative to zxing-cpp)
```bash
sudo apt install autopoint libtool-bin
./contrib/make_zbar
```

### 13. Create Translations (Optional)
```bash
sudo apt install -y python3-requests gettext
./contrib/make_locale
```

### 14. Compile Qt Icons (if needed)
```bash
sudo apt install -y pyqt5-dev-tools
pyrcc5 icons.qrc -o electroncash_gui/qt/icons.py
```

## Testing and Running

### 15. Test Electron Cash Installation
```bash
# Test command line mode first
python3 ./electron-cash --help

# Test GUI mode
python3 ./electron-cash
```

### 16. Create Desktop Integration (Optional)
```bash
# Make the script executable
chmod +x electron-cash

# Install system-wide (optional)
sudo python3 setup.py install
```
### 17. Install Tor for use with Cash Fusion
```bash
sudo apt install tor
```

## Build AppImage

To build a distributable AppImage for arm64 architecture (Raspberry Pi), see the [AppImage README](./contrib/build-linux/README.md).