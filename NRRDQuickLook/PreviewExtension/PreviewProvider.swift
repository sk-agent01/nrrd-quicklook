import Cocoa
import Quartz
import QuickLookUI

class PreviewProvider: QLPreviewProvider {
    
    func providePreview(for request: QLFilePreviewRequest) async throws -> QLPreviewReply {
        let fileURL = request.fileURL
        
        // Create temp output path for the preview image
        let tempDir = FileManager.default.temporaryDirectory
        let outputURL = tempDir.appendingPathComponent("nrrd_preview_\(UUID().uuidString).jpg")
        
        // Find the Python script in the app bundle or user's PATH
        let pythonScript = findPythonScript()
        
        // Run the Python preview generator
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["python3", pythonScript, fileURL.path, "-o", outputURL.path, "--dpi", "150"]
        
        let pipe = Pipe()
        process.standardError = pipe
        
        try process.run()
        process.waitUntilExit()
        
        guard process.terminationStatus == 0,
              FileManager.default.fileExists(atPath: outputURL.path) else {
            throw NSError(domain: "NRRDPreview", code: 1, 
                         userInfo: [NSLocalizedDescriptionKey: "Failed to generate preview"])
        }
        
        // Load the generated image
        guard let image = NSImage(contentsOf: outputURL) else {
            throw NSError(domain: "NRRDPreview", code: 2,
                         userInfo: [NSLocalizedDescriptionKey: "Failed to load preview image"])
        }
        
        // Clean up temp file
        try? FileManager.default.removeItem(at: outputURL)
        
        let reply = QLPreviewReply(dataOfContentType: .jpeg, contentSize: image.size) { replyToUpdate in
            let imageData = image.tiffRepresentation
            let bitmap = NSBitmapImageRep(data: imageData!)
            return bitmap!.representation(using: .jpeg, properties: [.compressionFactor: 0.9])!
        }
        
        return reply
    }
    
    private func findPythonScript() -> String {
        // Check common locations
        let locations = [
            Bundle.main.path(forResource: "nrrd_preview", ofType: "py"),
            NSHomeDirectory() + "/.local/bin/nrrd-preview",
            "/usr/local/bin/nrrd-preview",
            "/opt/homebrew/bin/nrrd-preview"
        ]
        
        for location in locations {
            if let path = location, FileManager.default.fileExists(atPath: path) {
                return path
            }
        }
        
        // Fallback to bundled script
        return Bundle.main.path(forResource: "nrrd_preview", ofType: "py") ?? "nrrd_preview.py"
    }
}
