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

## Step 2: Build the AppImage

Now you can build the AppImage for ARM64:

```bash
# Build the AppImage (replace 'master' with your desired tag/branch)
CPU_COUNT=2 ./contrib/build-linux/appimage/build_arm64.sh master
```

## Step 4: Test the AppImage

Once built, test the AppImage:

```bash
# Test the AppImage
./dist/Electron-Cash-*-aarch64.AppImage --help

# Run the GUI
./dist/Electron-Cash-*-aarch64.AppImage
```
