import SwiftUI
struct SchoologyNotificationRow: View {
    let notification: SchoologyNotification
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: notification.symbol)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(SchoologyStyle.blue)
                .frame(width: 42, height: 42)
                .background(SchoologyStyle.blue.opacity(0.11), in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(notification.title).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                    Spacer(minLength: 4)
                    if let date = notification.createdAt {
                        Text(date, style: .relative).font(.caption).foregroundStyle(.tertiary).lineLimit(1)
                    }
                }
                Text(notification.formattedBody.isEmpty ? notification.title : notification.formattedBody)
                    .font(.body).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                if !notification.isViewed {
                    Label("New", systemImage: "circle.fill").font(.caption2.weight(.semibold)).foregroundStyle(SchoologyStyle.blue)
                }
            }
        }
        .padding(.vertical, 7).contentShape(Rectangle()).accessibilityElement(children: .combine)
    }
}
