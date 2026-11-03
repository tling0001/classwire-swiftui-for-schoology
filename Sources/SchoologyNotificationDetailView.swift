import SwiftUI
struct SchoologyNotificationDetailView: View {
    let notification: SchoologyNotification
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 10) {
                    Label(notification.title, systemImage: notification.symbol).font(.headline).foregroundStyle(SchoologyStyle.blue)
                    Text(notification.formattedBody.isEmpty ? notification.title : notification.formattedBody).font(.body).textSelection(.enabled)
                    if let date = notification.createdAt {
                        Label(date.formatted(date: .complete, time: .shortened), systemImage: "clock").font(.caption).foregroundStyle(.secondary)
                    }
                }
                .padding(18).frame(maxWidth: .infinity, alignment: .leading)
                .background(.background, in: RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(.quaternary))
                if !notification.arguments.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Related items").font(.headline)
                        ForEach(notification.arguments) { argument in
                            SchoologyNotificationArgumentRow(notification: notification, argument: argument)
                        }
                    }
                }
            }
            .padding().frame(maxWidth: 760).frame(maxWidth: .infinity)
        }
        .navigationTitle(notification.title)
    }
}
