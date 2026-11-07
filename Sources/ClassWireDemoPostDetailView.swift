import SwiftUI

struct ClassWireDemoPostDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var isLiked: Bool
    @State private var comments = [
        "Jordan Lee: Thanks for sharing the notes!",
        "Avery Johnson: This helped me prepare for the lab.",
        "Ms. Rivera: Please bring your questions to class."
    ]
    @State private var draftComment = ""
    @State private var pollChoice: String?
    @State private var saved = false

    var body: some View {
        NavigationStack {
            List {
                Section("Biology · Ms. Rivera") {
                    Text("Remember to review the cell structure notes before Friday's lab. Bring your microscope worksheet and be ready to identify the major organelles.")
                    HStack {
                        Button(isLiked ? "Liked" : "Like", systemImage: isLiked ? "hand.thumbsup.fill" : "hand.thumbsup") {
                            isLiked.toggle()
                        }
                        Spacer()
                        Button(saved ? "Saved" : "Save post", systemImage: saved ? "bookmark.fill" : "bookmark") {
                            saved.toggle()
                        }
                    }
                    Label("Cell Structure Notes.pdf", systemImage: "doc.richtext")
                    Label("Microscope Diagram.png", systemImage: "photo")
                }
                Section("Class poll") {
                    ForEach(["I can identify the organelles", "I need more review", "I have questions"], id: \.self) { option in
                        Button {
                            pollChoice = option
                        } label: {
                            HStack {
                                Image(systemName: pollChoice == option ? "largecircle.fill.circle" : "circle")
                                Text(option)
                                Spacer()
                                if pollChoice == option { Text("Selected").font(.caption).foregroundStyle(.secondary) }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    Text("Poll selection is local and is not submitted.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Section("Comments") {
                    ForEach(comments, id: \.self) { comment in
                        Text(comment).textSelection(.enabled)
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                HStack {
                    TextField("Write a comment", text: $draftComment, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                    Button("Post", systemImage: "paperplane.fill") {
                        let value = draftComment.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !value.isEmpty else { return }
                        comments.append("Alex Morgan: \(value)")
                        draftComment = ""
                    }
                    .disabled(draftComment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding()
                .background(.bar)
            }
            .navigationTitle("Post")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
