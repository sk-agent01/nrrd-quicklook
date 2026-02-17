# NRRD QuickLook

A macOS Quick Look extension for previewing [NRRD](http://teem.sourceforge.net/nrrd/format.html) (Nearly Raw Raster Data) files directly in Finder.

![Preview](preview.png)

## Features

- 🔍 Native Quick Look integration - press Space in Finder to preview
- 🎨 Colored labels for segmentation masks
- 📊 Grayscale rendering for continuous data
- 🖼️ Multi-view display: axial, coronal, and sagittal slices
- ⚡ Self-contained - no Python or external dependencies

## Supported Formats

- Raw and gzip-compressed NRRD files
- Data types: uint8, int8, uint16, int16, uint32, int32, float32, float64
- 2D and 3D volumes

## Installation

1. Download `NRRDQuickLook-macos.zip` from [Releases](../../releases)
2. Unzip and move `NRRDQuickLook.app` to `/Applications`
3. Open the app once (it will close immediately - this registers the extension)
4. Go to **System Settings → Extensions → Quick Look**
5. Enable **NRRDQuickLook**

## Building from Source

Requires Xcode 15+ and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```bash
cd NRRDQuickLook
xcodegen generate
xcodebuild -scheme NRRDQuickLook -configuration Release
```

## License

MIT
