# Building Electron Cash AppImage for Raspberry Pi (ARM64)

This guide provides instructions for building an AppImage of Electron Cash specifically for Raspberry Pi (ARM64 architecture).

⚠️ **Prerequisites**: This guide assumes you have already successfully installed and run Electron Cash on your Raspberry Pi following the main README instructions. All required dependencies should already be installed.


## Build the AppImage

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