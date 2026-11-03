import SwiftUI
struct SchoologyNotificationArgumentRow: View {
    let notification: SchoologyNotification
    let argument: SchoologyNotificationArgument
    var body: some View {
        Group {
            if argument.type == "more" {
                DisclosureGroup(argument.title) {
                    ForEach(argument.children) { child in
                        SchoologyNotificationArgumentRow(notification: notification, argument: child)
                    }
                }
            } else if argument.canOpen {
                NavigationLink {
                    SchoologyNotificationTargetView(notification: notification, argument: argument)
                } label: {
                    Label(argument.title, systemImage: argument.symbol)
                        .frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
                }
            } else {
                Label(argument.title, systemImage: argument.symbol).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
