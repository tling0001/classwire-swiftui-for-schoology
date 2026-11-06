import SwiftUI
import AVKit

/// Native playback surface for supported Schoology video and audio attachments.
struct SchoologyMediaAttachmentPlayer: View {
    let url: URL
    let title: String

    @Environment(\.dismiss) private var dismiss
    @State private var player: AVPlayer?

    private var isAudio: Bool {
        ["mp3", "m4a", "aac", "wav", "aiff", "aif", "flac", "ogg", "oga", "opus", "wma", "caf"]
            .contains(url.pathExtension.lowercased())
    }

    var body: some View {
        NavigationStack {
            Group {
                if let player {
                    if isAudio {
                        VStack(spacing: 18) {
                            Image(systemName: "waveform")
                                .font(.system(size: 58, weight: .light))
                                .foregroundStyle(.secondary)
                                .accessibilityHidden(true)
                            Text(title)
                                .font(.headline)
                                .multilineTextAlignment(.center)
                            VideoPlayer(player: player)
                                .frame(height: 84)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .padding(24)
                        .frame(maxWidth: 520, maxHeight: .infinity)
                    } else {
                        VideoPlayer(player: player)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                } else {
                    ProgressView("Preparing media…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle(title)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        player?.pause()
                        dismiss()
                    }
                }
            }
        }
        .task {
            guard player == nil else { return }
            let preparedPlayer = AVPlayer(url: url)
            player = preparedPlayer
            preparedPlayer.play()
        }
        .onDisappear { player?.pause() }
        #if os(macOS)
        .frame(minWidth: 560, minHeight: 360)
        .schoologyFittedSheet()
        #else
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        #endif
    }
}
