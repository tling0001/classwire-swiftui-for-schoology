import SwiftUI

struct SchoologyProfileInfobox: View {
    let title: String
    var subtitle: String? = nil
    let imageURL: URL?
    let fallbackSymbol: String
    var details: [String] = []

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            Group {
                if let imageURL {
                    AuthenticatedSchoologyImage(url: imageURL)
                        .frame(width: 76, height: 76)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                } else {
                    Image(systemName: fallbackSymbol)
                        .font(.system(size: 34))
                        .foregroundStyle(SchoologyStyle.blue)
                        .frame(width: 76, height: 76)
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 14))
                }
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.title3.bold()).fixedSize(horizontal: false, vertical: true)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                ForEach(details.filter { !$0.isEmpty }, id: \.self) { detail in
                    Text(detail).font(.callout).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(.quaternary))
        .accessibilityElement(children: .combine)
    }
}
