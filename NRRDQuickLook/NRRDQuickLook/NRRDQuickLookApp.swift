import SwiftUI
import UniformTypeIdentifiers

@main
struct NRRDQuickLookApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    @State private var previewImage: NSImage?
    @State private var nrrdInfo: String = ""
    @State private var errorMessage: String?
    @State private var isDragging = false
    
    var body: some View {
        VStack(spacing: 16) {
            if let image = previewImage {
                // Show preview
                VStack(spacing: 8) {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                    Text(nrrdInfo)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Button("Clear") {
                        previewImage = nil
                        nrrdInfo = ""
                        errorMessage = nil
                    }
                    .buttonStyle(.bordered)
                }
            } else {
                // Drop zone
                VStack(spacing: 20) {
                    Image(systemName: "cube.transparent")
                        .font(.system(size: 64))
                        .foregroundColor(isDragging ? .blue : .gray)
                    
                    Text("NRRD Quick Look")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Drop .nrrd file here to preview")
                        .font(.title3)
                        .foregroundColor(.secondary)
                    
                    if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding()
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(8)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Native Swift — no Python required", systemImage: "swift")
                        Label("Supports raw & gzip compressed", systemImage: "doc.zipper")
                        Label("2D and 3D volumes", systemImage: "cube")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }
        }
        .padding(24)
        .frame(minWidth: 500, minHeight: 400)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(isDragging ? Color.blue : Color.clear, lineWidth: 3)
                .background(isDragging ? Color.blue.opacity(0.05) : Color.clear)
        )
        .onDrop(of: [.fileURL], isTargeted: $isDragging) { providers in
            handleDrop(providers: providers)
            return true
        }
    }
    
    private func handleDrop(providers: [NSItemProvider]) {
        guard let provider = providers.first else { return }
        
        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, error in
            guard let data = item as? Data,
                  let url = URL(dataRepresentation: data, relativeTo: nil) else {
                DispatchQueue.main.async {
                    errorMessage = "Could not read dropped file"
                }
                return
            }
            
            loadNRRD(from: url)
        }
    }
    
    private func loadNRRD(from url: URL) {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let nrrd = try NRRDParser.parse(url: url)
                
                guard let image = NRRDRenderer.renderPreview(from: nrrd, size: CGSize(width: 800, height: 600)) else {
                    throw NSError(domain: "NRRD", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to render preview"])
                }
                
                let info = "Shape: \(nrrd.shape.map(String.init).joined(separator: "×")) | Type: \(nrrd.type)"
                
                DispatchQueue.main.async {
                    previewImage = image
                    nrrdInfo = info
                    errorMessage = nil
                }
            } catch {
                DispatchQueue.main.async {
                    errorMessage = "Error: \(error.localizedDescription)"
                    previewImage = nil
                }
            }
        }
    }
}
