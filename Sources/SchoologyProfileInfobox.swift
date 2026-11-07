import SwiftUI

struct SchoologyProfileInfobox: View {
    let title: String
    var subtitle: String? = nil
    var schoolName: String? = nil
    var schoolID: String? = nil
    let imageURL: URL?
    let fallbackSymbol: String
    var details: [String] = []
    var showsImage = true

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            if showsImage {
                Group {
                    if let imageURL {
                        AuthenticatedSchoologyImage(url: imageURL)
                            .frame(width: 48, height: 48)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    } else if fallbackSymbol == "person.crop.circle.fill" || fallbackSymbol == "person.fill" {
                        SchoologyAvatarPlaceholder(size: 48, tint: SchoologyStyle.blue)
                    } else {
                        Image(systemName: fallbackSymbol)
                            .font(.system(size: 23))
                            .foregroundStyle(SchoologyStyle.blue)
                            .frame(width: 48, height: 48)
                            .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
                    }
                }
                .accessibilityHidden(true)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.title2.bold())
                    .fixedSize(horizontal: false, vertical: true)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let schoolName, !schoolName.isEmpty {
                    if let schoolID, !schoolID.isEmpty {
                        NavigationLink {
                            SchoolProfileView(schoolID: schoolID)
                        } label: {
                            Label(schoolName, systemImage: "building.2")
                                .font(.subheadline)
                                .foregroundStyle(SchoologyStyle.blue)
                                .underline()
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Opens the school profile")
                    } else {
                        Text(schoolName)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                ForEach(details.filter { !$0.isEmpty }, id: \.self) { detail in
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 4)
        .accessibilityElement(children: .contain)
    }
}
