import SwiftUI

// MARK: - Environment Key & Values

private struct NotchThemeEnvironmentKey: EnvironmentKey {
    static let defaultValue: NotchTheme = .classic
}

extension EnvironmentValues {
    public var notchTheme: NotchTheme {
        get { self[NotchThemeEnvironmentKey.self] }
        set { self[NotchThemeEnvironmentKey.self] = newValue }
    }
}

// MARK: - Accessibility Adjustments

extension NotchTheme {
    /// Adjusts theme tokens dynamically based on macOS accessibility settings
    public func adjusted(
        reduceTransparency: Bool,
        increaseContrast: Bool,
        reduceMotion: Bool
    ) -> NotchTheme {
        var copy = self

        // Reduce transparency: Fall back materials/blur to solid opaque colors
        if reduceTransparency {
            switch copy.surface {
            case .material, .liquidGlass:
                copy.surface = .solid(Color(red: 0.10, green: 0.11, blue: 0.12))
            default:
                break
            }
        }

        // Increase contrast: Enhance borders and cards
        if increaseContrast {
            if let border = copy.border {
                copy.border = NotchBorderStyle(
                    width: max(border.width, 1.5),
                    color: .white.opacity(0.4),
                    glowColor: nil,
                    glowRadius: 0
                )
            } else {
                copy.border = NotchBorderStyle(
                    width: 1.5,
                    color: .white.opacity(0.3)
                )
            }

            copy.card = NotchCardStyle(
                fill: copy.card.fill,
                hoverFill: copy.card.hoverFill,
                borderColor: .white.opacity(0.4),
                borderWidth: 1.5
            )
        }

        return copy
    }
}

