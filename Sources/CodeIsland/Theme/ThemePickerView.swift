import SwiftUI

public struct ThemePickerView: View {
    @Binding var selectedThemeRaw: String
    @Environment(\.notchTheme) private var currentTheme

    private let columns = [
        GridItem(.adaptive(minimum: 120, maximum: 160), spacing: 12)
    ]

    public init(selectedThemeRaw: Binding<String>) {
        self._selectedThemeRaw = selectedThemeRaw
    }

    public var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(NotchThemeID.allCases) { themeID in
                let theme = NotchTheme.preset(for: themeID)
                let isSelected = selectedThemeRaw == themeID.rawValue

                Button {
                    withAnimation(NotchAnimation.micro) {
                        selectedThemeRaw = themeID.rawValue
                    }
                } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        // Mini preview of the theme
                        ZStack {
                            // Mini notch surface preview
                            NotchSurfaceBackground(
                                shape: RoundedRectangle(cornerRadius: 10 * theme.cornerScale, style: .continuous),
                                theme: theme,
                                context: NotchSurfaceContext(
                                    isExpanded: false,
                                    isFloating: true,
                                    usesPhysicalNotch: false,
                                    notchHeight: 28
                                )
                            )

                            // Mock inner content
                            HStack(spacing: 5) {
                                Circle()
                                    .fill(theme.accent)
                                    .frame(width: 8, height: 8)
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color.white.opacity(0.7))
                                    .frame(width: 28, height: 4)
                                Spacer()
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(theme.palette.allowFill)
                                    .frame(width: 14, height: 6)
                            }
                            .padding(.horizontal, 8)
                        }
                        .frame(height: 38)
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                        // Theme Name
                        HStack(spacing: 4) {
                            Text(themeTitle(for: themeID))
                                .font(.system(size: 11, weight: isSelected ? .bold : .medium))
                                .foregroundStyle(isSelected ? .primary : .secondary)

                            Spacer()

                            if isSelected {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 11))
                                    .foregroundStyle(Color.accentColor)
                            }
                        }

                        Text(themeDescription(for: themeID))
                            .font(.system(size: 9.5))
                            .foregroundStyle(.tertiary)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(isSelected ? Color.accentColor.opacity(0.12) : Color.white.opacity(0.04))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(isSelected ? Color.accentColor : Color.white.opacity(0.08), lineWidth: isSelected ? 1.5 : 1.0)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(themeTitle(for: themeID))
                .accessibilityValue(isSelected ? "Selected" : "Not selected")
            }
        }
        .padding(.vertical, 4)
    }

    private func themeTitle(for id: NotchThemeID) -> String {
        L10n.shared["theme_\(id.rawValue)"]
    }

    private func themeDescription(for id: NotchThemeID) -> String {
        L10n.shared["theme_\(id.rawValue)_desc"]
    }
}

