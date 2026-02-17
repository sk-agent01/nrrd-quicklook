import Cocoa
import Quartz
import QuickLookUI

class PreviewProvider: QLPreviewProvider {
    
    func providePreview(for request: QLFilePreviewRequest) async throws -> QLPreviewReply {
        let fileURL = request.fileURL
        
        // Parse NRRD file natively
        let nrrd = try NRRDParser.parse(url: fileURL)
        
        // Render preview image
        guard let previewImage = NRRDRenderer.renderPreview(from: nrrd, size: CGSize(width: 800, height: 500)) else {
            throw NSError(domain: "NRRDPreview", code: 1,
                         userInfo: [NSLocalizedDescriptionKey: "Failed to render preview"])
        }
        
        // Convert to JPEG data
        guard let tiffData = previewImage.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let jpegData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.9]) else {
            throw NSError(domain: "NRRDPreview", code: 2,
                         userInfo: [NSLocalizedDescriptionKey: "Failed to encode preview"])
        }
        
        let reply = QLPreviewReply(dataOfContentType: .jpeg, contentSize: previewImage.size) { _ in
            return jpegData
        }
        
        return reply
    }
}
