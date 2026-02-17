import Cocoa
import CoreGraphics

/// Renders NRRD volume data as a preview image
class NRRDRenderer {
    
    // Distinct colors for mask labels (RGBA)
    private static let labelColors: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [
        (0.12, 0.47, 0.71, 1.0),  // Blue
        (1.00, 0.50, 0.05, 1.0),  // Orange
        (0.17, 0.63, 0.17, 1.0),  // Green
        (0.84, 0.15, 0.16, 1.0),  // Red
        (0.58, 0.40, 0.74, 1.0),  // Purple
        (0.55, 0.34, 0.29, 1.0),  // Brown
        (0.89, 0.47, 0.76, 1.0),  // Pink
        (0.50, 0.50, 0.50, 1.0),  // Gray
        (0.74, 0.74, 0.13, 1.0),  // Olive
        (0.09, 0.75, 0.81, 1.0),  // Cyan
        (0.68, 0.78, 0.91, 1.0),  // Light blue
        (1.00, 0.73, 0.47, 1.0),  // Peach
        (0.60, 0.87, 0.54, 1.0),  // Light green
        (1.00, 0.60, 0.60, 1.0),  // Salmon
        (0.77, 0.69, 0.84, 1.0),  // Lavender
    ]
    
    static func renderPreview(from nrrd: NRRDFile, size: CGSize = CGSize(width: 800, height: 600)) -> NSImage? {
        // Detect if this is a mask (integer labels) or continuous data
        let uniqueValues = Set(nrrd.data.filter { $0 != 0 }.map { Int($0) })
        let isMask = uniqueValues.count <= 50 && uniqueValues.allSatisfy { $0 >= 0 && $0 < 1000 }
        
        if nrrd.shape.count == 3 {
            return render3DVolume(nrrd, size: size, isMask: isMask)
        } else if nrrd.shape.count == 2 {
            return render2DSlice(nrrd.data, width: nrrd.width, height: nrrd.height, size: size, isMask: isMask)
        }
        
        return nil
    }
    
    private static func render3DVolume(_ nrrd: NRRDFile, size: CGSize, isMask: Bool) -> NSImage? {
        let w = nrrd.width
        let h = nrrd.height
        let d = nrrd.depth
        
        // Create preview showing 3 orthogonal slices
        let sliceZ = d / 2  // Axial (middle)
        let sliceY = h / 2  // Coronal
        let sliceX = w / 2  // Sagittal
        
        // Extract slices
        let axialSlice = extractAxialSlice(nrrd.data, w: w, h: h, d: d, z: sliceZ)
        let coronalSlice = extractCoronalSlice(nrrd.data, w: w, h: h, d: d, y: sliceY)
        let sagittalSlice = extractSagittalSlice(nrrd.data, w: w, h: h, d: d, x: sliceX)
        
        // Compute layout: 3 slices in a row with labels
        let margin: CGFloat = 10
        let labelHeight: CGFloat = 25
        let totalWidth = size.width - margin * 4
        let sliceWidth = totalWidth / 3
        let sliceHeight = size.height - margin * 2 - labelHeight
        
        let image = NSImage(size: size)
        image.lockFocus()
        
        // Background
        NSColor.black.setFill()
        NSRect(origin: .zero, size: size).fill()
        
        // Draw title
        let titleAttrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: NSColor.white,
            .font: NSFont.systemFont(ofSize: 14, weight: .medium)
        ]
        let title = "NRRD: \(w)×\(h)×\(d)"
        title.draw(at: NSPoint(x: margin, y: size.height - 22), withAttributes: titleAttrs)
        
        // Draw slices
        let sliceY0 = margin
        
        if let axialImg = renderSliceImage(axialSlice, width: w, height: h, isMask: isMask) {
            let axialRect = NSRect(x: margin, y: sliceY0, width: sliceWidth, height: sliceHeight)
            axialImg.draw(in: axialRect)
            drawSliceLabel("Axial (z=\(sliceZ))", at: NSPoint(x: margin, y: sliceY0 + sliceHeight + 2))
        }
        
        if let coronalImg = renderSliceImage(coronalSlice, width: w, height: d, isMask: isMask) {
            let coronalRect = NSRect(x: margin * 2 + sliceWidth, y: sliceY0, width: sliceWidth, height: sliceHeight)
            coronalImg.draw(in: coronalRect)
            drawSliceLabel("Coronal (y=\(sliceY))", at: NSPoint(x: margin * 2 + sliceWidth, y: sliceY0 + sliceHeight + 2))
        }
        
        if let sagittalImg = renderSliceImage(sagittalSlice, width: h, height: d, isMask: isMask) {
            let sagittalRect = NSRect(x: margin * 3 + sliceWidth * 2, y: sliceY0, width: sliceWidth, height: sliceHeight)
            sagittalImg.draw(in: sagittalRect)
            drawSliceLabel("Sagittal (x=\(sliceX))", at: NSPoint(x: margin * 3 + sliceWidth * 2, y: sliceY0 + sliceHeight + 2))
        }
        
        image.unlockFocus()
        return image
    }
    
    private static func drawSliceLabel(_ text: String, at point: NSPoint) {
        let attrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: NSColor.lightGray,
            .font: NSFont.systemFont(ofSize: 11)
        ]
        text.draw(at: point, withAttributes: attrs)
    }
    
    private static func extractAxialSlice(_ data: [Float], w: Int, h: Int, d: Int, z: Int) -> [Float] {
        var slice = [Float](repeating: 0, count: w * h)
        for y in 0..<h {
            for x in 0..<w {
                slice[y * w + x] = data[z * (w * h) + y * w + x]
            }
        }
        return slice
    }
    
    private static func extractCoronalSlice(_ data: [Float], w: Int, h: Int, d: Int, y: Int) -> [Float] {
        var slice = [Float](repeating: 0, count: w * d)
        for z in 0..<d {
            for x in 0..<w {
                slice[z * w + x] = data[z * (w * h) + y * w + x]
            }
        }
        return slice
    }
    
    private static func extractSagittalSlice(_ data: [Float], w: Int, h: Int, d: Int, x: Int) -> [Float] {
        var slice = [Float](repeating: 0, count: h * d)
        for z in 0..<d {
            for y in 0..<h {
                slice[z * h + y] = data[z * (w * h) + y * w + x]
            }
        }
        return slice
    }
    
    private static func renderSliceImage(_ slice: [Float], width: Int, height: Int, isMask: Bool) -> NSImage? {
        guard width > 0 && height > 0 else { return nil }
        
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        
        if isMask {
            // Render as colored labels
            for i in 0..<min(slice.count, width * height) {
                let label = Int(slice[i])
                let pixelIndex = i * 4
                
                if label == 0 {
                    // Background - transparent/black
                    pixels[pixelIndex] = 0
                    pixels[pixelIndex + 1] = 0
                    pixels[pixelIndex + 2] = 0
                    pixels[pixelIndex + 3] = 255
                } else {
                    let colorIndex = (label - 1) % labelColors.count
                    let color = labelColors[colorIndex]
                    pixels[pixelIndex] = UInt8(color.0 * 255)
                    pixels[pixelIndex + 1] = UInt8(color.1 * 255)
                    pixels[pixelIndex + 2] = UInt8(color.2 * 255)
                    pixels[pixelIndex + 3] = 255
                }
            }
        } else {
            // Render as grayscale with auto-windowing
            let minVal = slice.min() ?? 0
            let maxVal = slice.max() ?? 1
            let range = maxVal - minVal
            
            for i in 0..<min(slice.count, width * height) {
                let normalized = range > 0 ? (slice[i] - minVal) / range : 0
                let gray = UInt8(min(255, max(0, normalized * 255)))
                let pixelIndex = i * 4
                pixels[pixelIndex] = gray
                pixels[pixelIndex + 1] = gray
                pixels[pixelIndex + 2] = gray
                pixels[pixelIndex + 3] = 255
            }
        }
        
        // Create CGImage
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        
        guard let provider = CGDataProvider(data: Data(pixels) as CFData),
              let cgImage = CGImage(
                width: width,
                height: height,
                bitsPerComponent: 8,
                bitsPerPixel: 32,
                bytesPerRow: width * 4,
                space: colorSpace,
                bitmapInfo: bitmapInfo,
                provider: provider,
                decode: nil,
                shouldInterpolate: false,
                intent: .defaultIntent
              ) else {
            return nil
        }
        
        return NSImage(cgImage: cgImage, size: NSSize(width: width, height: height))
    }
    
    private static func render2DSlice(_ data: [Float], width: Int, height: Int, size: CGSize, isMask: Bool) -> NSImage? {
        guard let sliceImg = renderSliceImage(data, width: width, height: height, isMask: isMask) else {
            return nil
        }
        
        let image = NSImage(size: size)
        image.lockFocus()
        
        NSColor.black.setFill()
        NSRect(origin: .zero, size: size).fill()
        
        // Draw centered
        let scale = min(size.width / CGFloat(width), size.height / CGFloat(height)) * 0.9
        let scaledWidth = CGFloat(width) * scale
        let scaledHeight = CGFloat(height) * scale
        let x = (size.width - scaledWidth) / 2
        let y = (size.height - scaledHeight) / 2
        
        sliceImg.draw(in: NSRect(x: x, y: y, width: scaledWidth, height: scaledHeight))
        
        image.unlockFocus()
        return image
    }
}
