import SwiftUI

struct SchoologyProfileHeroImage: View {
    let url: URL?
    let fallbackSymbol: String

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if let url {
                    AuthenticatedSchoologyImage(url: url)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                } else {
                    Image(systemName: fallbackSymbol)
                        .font(.system(size: 40))
                        .foregroundStyle(SchoologyStyle.blue)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(.quaternary)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .aspectRatio(4.0 / 3.0, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .accessibilityHidden(true)
    }
}
