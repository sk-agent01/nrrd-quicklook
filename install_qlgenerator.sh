#!/bin/bash
# Install NRRD Quick Look preview generator for macOS
# Note: Modern macOS (10.15+) requires notarized Quick Look extensions
# This script sets up the Python previewer as a command-line tool

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="$HOME/.local/bin"
PREVIEW_SCRIPT="$INSTALL_DIR/nrrd-preview"

echo "Installing NRRD Preview..."

# Create install directory
mkdir -p "$INSTALL_DIR"

# Install Python dependencies
echo "Installing Python dependencies..."
pip3 install --user pynrrd matplotlib numpy

# Copy and make executable
cp "$SCRIPT_DIR/nrrd_preview.py" "$PREVIEW_SCRIPT"
chmod +x "$PREVIEW_SCRIPT"

echo "Installed to: $PREVIEW_SCRIPT"
echo ""
echo "Usage:"
echo "  nrrd-preview /path/to/file.nrrd"
echo "  nrrd-preview /path/to/file.nrrd -o output.jpg"
echo ""
echo "Add to PATH if needed:"
echo "  export PATH=\"\$HOME/.local/bin:\$PATH\""
