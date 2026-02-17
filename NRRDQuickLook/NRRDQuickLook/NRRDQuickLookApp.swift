import SwiftUI

@main
struct NRRDQuickLookApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "cube.transparent")
                .font(.system(size: 64))
                .foregroundColor(.blue)
            
            Text("NRRD Quick Look")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Preview .nrrd files with spacebar in Finder")
                .font(.title3)
                .foregroundColor(.secondary)
            
            Divider()
                .padding(.vertical)
            
            VStack(alignment: .leading, spacing: 12) {
                Label("Quick Look extension installed", systemImage: "checkmark.circle.fill")
                    .foregroundColor(.green)
                
                Label("Supports .nrrd and .nhdr files", systemImage: "doc.fill")
                
                Label("Renders 3D masks with colored labels", systemImage: "paintpalette.fill")
            }
            .font(.body)
            
            Spacer()
            
            Text("Requires: python3, pynrrd, matplotlib, numpy")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(40)
        .frame(width: 400, height: 350)
    }
}
