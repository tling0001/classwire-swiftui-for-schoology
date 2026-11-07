import SwiftUI

struct ClassWireDemoResourcePreviewView: View {
    @Environment(\.dismiss) private var dismiss
    let resourceName: String
    @State private var savedToDemo = false

    private var fileExtension: String {
        URL(fileURLWithPath: resourceName).pathExtension.lowercased()
    }

    private var symbol: String {
        switch fileExtension {
        case "png", "jpg", "jpeg", "gif": "photo"
        case "mp4", "mov", "m4v": "play.rectangle"
        case "mp3", "m4a", "wav": "waveform"
        case "pdf": "doc.richtext"
        case "ppt", "pptx": "rectangle.on.rectangle"
        case "doc", "docx": "doc.text"
        default: "doc"
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                Image(systemName: symbol)
                    .font(.system(size: 64, weight: .light))
                    .foregroundStyle(SchoologyStyle.blue)
                    .frame(maxWidth: .infinity, minHeight: 190)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 16))
                VStack(alignment: .leading, spacing: 8) {
                    Text(resourceName).font(.title3.bold())
                    Text("Sample resource preview").foregroundStyle(.secondary)
                    Text("This preview represents the document, image, presentation, or media viewer. The original school file is not downloaded in demo mode.")
                        .font(.callout)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Button(savedToDemo ? "Saved in demo" : "Download sample", systemImage: savedToDemo ? "checkmark.circle.fill" : "arrow.down.circle") {
                    savedToDemo = true
                }
                .buttonStyle(.borderedProminent)
                .disabled(savedToDemo)
                Text("No file is written to disk. The download action is simulated.")
                    .font(.footnote).foregroundStyle(.secondary)
                Spacer()
            }
            .padding()
            .navigationTitle("Preview")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
