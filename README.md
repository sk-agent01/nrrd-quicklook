# NRRD Quick Look for macOS

Press **spacebar** on .nrrd files in Finder to preview 3D masks with colored labels.

![Preview example](preview.jpg)

## Features

- Native macOS Quick Look integration (spacebar preview)
- Renders 3D masks with distinct colors per label
- Shows axial, coronal, and sagittal views
- Displays shape info and legend

## Installation

### Prerequisites

```bash
# Install Python dependencies
pip3 install pynrrd matplotlib numpy

# Install xcodegen (for building the Xcode project)
brew install xcodegen
```

### Build the App

```bash
cd NRRDQuickLook

# Generate Xcode project
xcodegen generate

# Open in Xcode
open NRRDQuickLook.xcodeproj

# Build: Product → Build (Cmd+B)
# Or from command line:
xcodebuild -scheme NRRDQuickLook -configuration Release
```

### Install

1. Copy `NRRDQuickLook.app` to `/Applications/`
2. Launch it once to register the Quick Look extension
3. Go to **System Settings → Privacy & Security → Extensions → Quick Look**
4. Enable "NRRD Preview"

### Test

```bash
# Reset Quick Look
qlmanage -r
qlmanage -r cache

# Test preview
qlmanage -p /path/to/your/file.nrrd
```

Or just press **spacebar** on a .nrrd file in Finder!

## Standalone CLI Usage

You can also use the Python script directly:

```bash
python3 nrrd_preview.py input.nrrd -o preview.jpg
```

## Troubleshooting

### Preview not working?

1. Make sure Python dependencies are installed: `pip3 list | grep pynrrd`
2. Check extension is enabled in System Settings
3. Try: `qlmanage -r && qlmanage -r cache`
4. Reboot if needed

### "Python not found" error?

The extension looks for `python3` in standard locations. Make sure it's in your PATH.

## How It Works

1. Quick Look extension receives the .nrrd file path
2. Calls Python script to render preview
3. Returns JPEG image to Quick Look

## Uninstall

```bash
rm -rf /Applications/NRRDQuickLook.app
qlmanage -r
```
