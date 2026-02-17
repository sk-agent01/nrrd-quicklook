# NRRD Quick Look Preview for macOS

Preview .nrrd 3D mask files in Finder with Quick Look.

## Features

- Renders 3D masks with distinct colors per label
- Shows axial, coronal, and sagittal views
- Displays shape info and legend

## Installation

### 1. Install Python dependencies

```bash
pip3 install -r requirements.txt
```

### 2. Test the preview generator

```bash
python3 nrrd_preview.py your_file.nrrd -o preview.jpg
open preview.jpg
```

### 3. Install Quick Look generator

```bash
# Build and install
./install_qlgenerator.sh

# Reload Quick Look
qlmanage -r
qlmanage -r cache
```

### 4. Test Quick Look

```bash
qlmanage -p your_file.nrrd
```

## Usage

Once installed, just press Space on any .nrrd file in Finder to preview.

## Uninstall

```bash
rm -rf ~/Library/QuickLook/NRRDPreview.qlgenerator
qlmanage -r
```
