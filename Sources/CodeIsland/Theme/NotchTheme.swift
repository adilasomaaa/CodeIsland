import SwiftUI

// MARK: - Theme Identifiers

public enum NotchThemeID: String, CaseIterable, Identifiable, Sendable {
    case classic = "classic"
    case glass = "glass"
    case liquidGlass = "liquidGlass"
    case skeuo = "skeuo"
    case modern = "modern"
    case neumorph = "neumorph"
    case terminal = "terminal"
    case neon = "neon"

    public var id: String { rawValue }

    public static func resolve(_ raw: String) -> NotchThemeID {
        NotchThemeID(rawValue: raw) ?? .classic
    }
}

// MARK: - Gradient Descriptor

public struct NotchGradientDescriptor: Equatable, Sendable {
    public let colors: [Color]
    public let startPoint: UnitPoint
    public let endPoint: UnitPoint

    public init(colors: [Color], startPoint: UnitPoint = .topLeading, endPoint: UnitPoint = .bottomTrailing) {
        self.colors = colors
        self.startPoint = startPoint
        self.endPoint = endPoint
    }

    public var linearGradient: LinearGradient {
        LinearGradient(colors: colors, startPoint: startPoint, endPoint: endPoint)
    }
}

// MARK: - Surface Styles

public enum NotchSurfaceStyle: Equatable, Sendable {
    case solid(Color)
    case gradient(NotchGradientDescriptor)
    case material(MaterialFallback)
    case liquidGlass(tint: Color)
    case neumorphic(base: Color)

    public struct MaterialFallback: Equatable, Sendable {
        public let materialStyle: NSVisualEffectView.Material
        public let tint: Color
        public let opacity: Double

        public init(materialStyle: NSVisualEffectView.Material = .hudWindow, tint: Color = .black, opacity: Double = 0.5) {
            self.materialStyle = materialStyle
            self.tint = tint
            self.opacity = opacity
        }
    }
}

// MARK: - Border & Accent

public struct NotchBorderStyle: Equatable, Sendable {
    public let width: CGFloat
    public let gradient: NotchGradientDescriptor?
    public let color: Color?
    public let glowColor: Color?
    public let glowRadius: CGFloat

    public init(width: CGFloat = 1.0, gradient: NotchGradientDescriptor? = nil, color: Color? = nil, glowColor: Color? = nil, glowRadius: CGFloat = 0) {
        self.width = width
        self.gradient = gradient
        self.color = color
        self.glowColor = glowColor
        self.glowRadius = glowRadius
    }
}

// MARK: - Shadow

public struct NotchShadow: Equatable, Sendable {
    public let color: Color
    public let radius: CGFloat
    public let x: CGFloat
    public let y: CGFloat

    // Secondary shadow for Neumorphism (light highlight on opposite side)
    public let highlightColor: Color?
    public let highlightRadius: CGFloat
    public let highlightX: CGFloat
    public let highlightY: CGFloat

    public init(
        color: Color = .black.opacity(0.28),
        radius: CGFloat = 16,
        x: CGFloat = 0,
        y: CGFloat = 6,
        highlightColor: Color? = nil,
        highlightRadius: CGFloat = 0,
        highlightX: CGFloat = 0,
        highlightY: CGFloat = 0
    ) {
        self.color = color
        self.radius = radius
        self.x = x
        self.y = y
        self.highlightColor = highlightColor
        self.highlightRadius = highlightRadius
        self.highlightX = highlightX
        self.highlightY = highlightY
    }
}

// MARK: - Overlays (Noise, Scanline, etc.)

public enum NotchOverlay: Equatable, Sendable {
    case none
    case noise(opacity: Double)
    case scanlines(opacity: Double)
}

// MARK: - Dividers

public enum NotchDividerStyle: Equatable, Sendable {
    case dashed(opacity: Double)
    case solid(color: Color, width: CGFloat)
    case none
}

// MARK: - Card Styling

public struct NotchCardStyle: Equatable, Sendable {
    public let fill: Color
    public let hoverFill: Color
    public let borderColor: Color?
    public let borderWidth: CGFloat
    public let shadowColor: Color?
    public let shadowRadius: CGFloat
    public let shadowY: CGFloat

    public init(
        fill: Color = Color.white.opacity(0.05),
        hoverFill: Color = Color.white.opacity(0.10),
        borderColor: Color? = nil,
        borderWidth: CGFloat = 0,
        shadowColor: Color? = nil,
        shadowRadius: CGFloat = 0,
        shadowY: CGFloat = 0
    ) {
        self.fill = fill
        self.hoverFill = hoverFill
        self.borderColor = borderColor
        self.borderWidth = borderWidth
        self.shadowColor = shadowColor
        self.shadowRadius = shadowRadius
        self.shadowY = shadowY
    }
}

// MARK: - Button Kinds

public enum NotchButtonStyleKind: Equatable, Sendable {
    case classic
    case bevel
    case extruded
    case neonOutline
    case bracket
}

// MARK: - Card Palette (WCAG-Checked)

public struct NotchCardPaletteValues: Equatable, Sendable {
    public let allowFill: Color
    public let allowFillHover: Color
    public let deny: Color
    public let link: Color
    public let permission: Color

    public init(
        allowFill: Color = Color(red: 0.16, green: 0.50, blue: 0.24),
        allowFillHover: Color = Color(red: 0.17, green: 0.53, blue: 0.26),
        deny: Color = Color(red: 0.92, green: 0.38, blue: 0.38),
        link: Color = Color(red: 0.45, green: 0.72, blue: 1.0),
        permission: Color = Color(red: 1.0, green: 0.6, blue: 0.2)
    ) {
        self.allowFill = allowFill
        self.allowFillHover = allowFillHover
        self.deny = deny
        self.link = link
        self.permission = permission
    }
}

// MARK: - NotchTheme Definition

public struct NotchTheme: Equatable, Identifiable, Sendable {
    public let id: NotchThemeID

    // Surface & Shell
    public var surface: NotchSurfaceStyle
    public var border: NotchBorderStyle?
    public var shadow: NotchShadow
    public var overlay: NotchOverlay
    public var notchSafeBand: Bool

    // Structural
    public var divider: NotchDividerStyle
    public var cornerScale: CGFloat
    public var fontDesign: Font.Design

    // Elements
    public var card: NotchCardStyle
    public var buttonKind: NotchButtonStyleKind
    public var palette: NotchCardPaletteValues
    public var accent: Color
    public var elevatedFill: Color

    public init(
        id: NotchThemeID,
        surface: NotchSurfaceStyle,
        border: NotchBorderStyle? = nil,
        shadow: NotchShadow = NotchShadow(),
        overlay: NotchOverlay = .none,
        notchSafeBand: Bool = true,
        divider: NotchDividerStyle = .dashed(opacity: 0.15),
        cornerScale: CGFloat = 1.0,
        fontDesign: Font.Design = .default,
        card: NotchCardStyle = NotchCardStyle(),
        buttonKind: NotchButtonStyleKind = .classic,
        palette: NotchCardPaletteValues = NotchCardPaletteValues(),
        accent: Color = .blue,
        elevatedFill: Color = Color.black.opacity(0.85)
    ) {
        self.id = id
        self.surface = surface
        self.border = border
        self.shadow = shadow
        self.overlay = overlay
        self.notchSafeBand = notchSafeBand
        self.divider = divider
        self.cornerScale = cornerScale
        self.fontDesign = fontDesign
        self.card = card
        self.buttonKind = buttonKind
        self.palette = palette
        self.accent = accent
        self.elevatedFill = elevatedFill
    }
}

// MARK: - Built-in Theme Presets

extension NotchTheme {
    /// Classic CodeIsland theme: Pitch black surface, white 0.15 dashed divider, subtle white opacity cards
    public static let classic = NotchTheme(
        id: .classic,
        surface: .solid(.black),
        border: nil,
        shadow: NotchShadow(color: .black.opacity(0.28), radius: 16, x: 0, y: 6),
        overlay: .none,
        notchSafeBand: false,
        divider: .dashed(opacity: 0.15),
        cornerScale: 1.0,
        fontDesign: .default,
        card: NotchCardStyle(
            fill: Color.white.opacity(0.05),
            hoverFill: Color.white.opacity(0.10)
        ),
        buttonKind: .classic,
        palette: NotchCardPaletteValues(),
        accent: .blue,
        elevatedFill: Color.black.opacity(0.85)
    )

    /// Glassmorphism: Translucent frosted blur, luminous gradient stroke, soft shadow
    public static let glass = NotchTheme(
        id: .glass,
        surface: .material(NotchSurfaceStyle.MaterialFallback(
            materialStyle: .hudWindow,
            tint: Color.black,
            opacity: 0.45
        )),
        border: NotchBorderStyle(
            width: 1.0,
            gradient: NotchGradientDescriptor(
                colors: [Color.white.opacity(0.35), Color.white.opacity(0.08), Color.white.opacity(0.02)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        ),
        shadow: NotchShadow(color: .black.opacity(0.4), radius: 20, x: 0, y: 8),
        overlay: .none,
        notchSafeBand: true,
        divider: .solid(color: Color.white.opacity(0.12), width: 0.5),
        cornerScale: 1.0,
        fontDesign: .default,
        card: NotchCardStyle(
            fill: Color.white.opacity(0.08),
            hoverFill: Color.white.opacity(0.15),
            borderColor: Color.white.opacity(0.15),
            borderWidth: 0.5
        ),
        buttonKind: .classic,
        palette: NotchCardPaletteValues(),
        accent: Color(red: 0.35, green: 0.65, blue: 1.0),
        elevatedFill: Color.black.opacity(0.65)
    )

    /// Liquid Glass: macOS 26 native refraction & specular highlights (with glass fallback)
    public static let liquidGlass = NotchTheme(
        id: .liquidGlass,
        surface: .liquidGlass(tint: Color.black.opacity(0.35)),
        border: NotchBorderStyle(
            width: 1.0,
            gradient: NotchGradientDescriptor(
                colors: [Color.white.opacity(0.45), Color.white.opacity(0.15), Color.white.opacity(0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        ),
        shadow: NotchShadow(color: .black.opacity(0.35), radius: 24, x: 0, y: 10),
        overlay: .none,
        notchSafeBand: true,
        divider: .solid(color: Color.white.opacity(0.15), width: 0.5),
        cornerScale: 1.0,
        fontDesign: .default,
        card: NotchCardStyle(
            fill: Color.white.opacity(0.09),
            hoverFill: Color.white.opacity(0.18),
            borderColor: Color.white.opacity(0.20),
            borderWidth: 0.5
        ),
        buttonKind: .classic,
        palette: NotchCardPaletteValues(),
        accent: Color(red: 0.4, green: 0.75, blue: 1.0),
        elevatedFill: Color.black.opacity(0.6)
    )

    /// Skeuomorphic: Obsidian / dark brushed metal finish with vertical gradient, top bevel highlight, fine tactile depth
    public static let skeuo = NotchTheme(
        id: .skeuo,
        surface: .gradient(NotchGradientDescriptor(
            colors: [Color(red: 0.18, green: 0.19, blue: 0.22), Color(red: 0.10, green: 0.11, blue: 0.13)],
            startPoint: .top,
            endPoint: .bottom
        )),
        border: NotchBorderStyle(
            width: 1.0,
            gradient: NotchGradientDescriptor(
                colors: [Color.white.opacity(0.30), Color.white.opacity(0.06), Color.black.opacity(0.8)],
                startPoint: .top,
                endPoint: .bottom
            )
        ),
        shadow: NotchShadow(color: .black.opacity(0.6), radius: 18, x: 0, y: 8),
        overlay: .noise(opacity: 0.04),
        notchSafeBand: true,
        divider: .solid(color: Color.black.opacity(0.6), width: 1.0),
        cornerScale: 0.95,
        fontDesign: .default,
        card: NotchCardStyle(
            fill: Color(red: 0.08, green: 0.08, blue: 0.10),
            hoverFill: Color(red: 0.12, green: 0.12, blue: 0.15),
            borderColor: Color.black.opacity(0.8),
            borderWidth: 1.0,
            shadowColor: Color.white.opacity(0.06),
            shadowRadius: 1,
            shadowY: 1
        ),
        buttonKind: .bevel,
        palette: NotchCardPaletteValues(),
        accent: Color(red: 0.95, green: 0.65, blue: 0.25),
        elevatedFill: Color(red: 0.09, green: 0.09, blue: 0.11)
    )

    /// Modern: Minimalist crisp charcoal slate, hairline border, clean geometry
    public static let modern = NotchTheme(
        id: .modern,
        surface: .solid(Color(red: 0.09, green: 0.10, blue: 0.11)),
        border: NotchBorderStyle(
            width: 1.0,
            color: Color.white.opacity(0.10)
        ),
        shadow: NotchShadow(color: .black.opacity(0.35), radius: 16, x: 0, y: 6),
        overlay: .none,
        notchSafeBand: true,
        divider: .solid(color: Color.white.opacity(0.08), width: 1.0),
        cornerScale: 1.1,
        fontDesign: .default,
        card: NotchCardStyle(
            fill: Color.white.opacity(0.04),
            hoverFill: Color.white.opacity(0.08),
            borderColor: Color.white.opacity(0.06),
            borderWidth: 1.0
        ),
        buttonKind: .classic,
        palette: NotchCardPaletteValues(),
        accent: Color.accentColor,
        elevatedFill: Color(red: 0.12, green: 0.13, blue: 0.15)
    )

    /// Neumorphism: Soft dark-mode UI with dual highlights and debossed card wells
    public static let neumorph = NotchTheme(
        id: .neumorph,
        surface: .neumorphic(base: Color(red: 0.12, green: 0.13, blue: 0.15)),
        border: NotchBorderStyle(width: 0.5, color: Color.white.opacity(0.06)),
        shadow: NotchShadow(
            color: .black.opacity(0.6),
            radius: 12,
            x: 6,
            y: 8,
            highlightColor: Color.white.opacity(0.07),
            highlightRadius: 8,
            highlightX: -3,
            highlightY: -3
        ),
        overlay: .none,
        notchSafeBand: true,
        divider: .solid(color: Color.black.opacity(0.4), width: 1.5),
        cornerScale: 1.2,
        fontDesign: .rounded,
        card: NotchCardStyle(
            fill: Color(red: 0.10, green: 0.11, blue: 0.13),
            hoverFill: Color(red: 0.14, green: 0.15, blue: 0.17),
            borderColor: Color.black.opacity(0.5),
            borderWidth: 1.0,
            shadowColor: Color.white.opacity(0.05),
            shadowRadius: 2,
            shadowY: -1
        ),
        buttonKind: .extruded,
        palette: NotchCardPaletteValues(),
        accent: Color(red: 0.45, green: 0.65, blue: 1.0),
        elevatedFill: Color(red: 0.11, green: 0.12, blue: 0.14)
    )

    /// Retro Terminal: Vintage CRT phosphorescent phosphor glow, scanlines & monospace design
    public static let terminal = NotchTheme(
        id: .terminal,
        surface: .solid(Color(red: 0.02, green: 0.06, blue: 0.03)),
        border: NotchBorderStyle(
            width: 1.5,
            color: Color(red: 0.15, green: 0.85, blue: 0.35),
            glowColor: Color(red: 0.15, green: 0.85, blue: 0.35).opacity(0.45),
            glowRadius: 6
        ),
        shadow: NotchShadow(color: Color(red: 0.05, green: 0.4, blue: 0.15).opacity(0.35), radius: 14, x: 0, y: 4),
        overlay: .scanlines(opacity: 0.12),
        notchSafeBand: true,
        divider: .solid(color: Color(red: 0.15, green: 0.85, blue: 0.35).opacity(0.3), width: 1.0),
        cornerScale: 0.6,
        fontDesign: .monospaced,
        card: NotchCardStyle(
            fill: Color(red: 0.04, green: 0.10, blue: 0.05),
            hoverFill: Color(red: 0.06, green: 0.16, blue: 0.08),
            borderColor: Color(red: 0.15, green: 0.85, blue: 0.35).opacity(0.35),
            borderWidth: 1.0
        ),
        buttonKind: .bracket,
        palette: NotchCardPaletteValues(
            allowFill: Color(red: 0.10, green: 0.55, blue: 0.22),
            allowFillHover: Color(red: 0.14, green: 0.70, blue: 0.28),
            deny: Color(red: 0.85, green: 0.25, blue: 0.25),
            link: Color(red: 0.30, green: 0.90, blue: 0.50),
            permission: Color(red: 0.95, green: 0.75, blue: 0.15)
        ),
        accent: Color(red: 0.2, green: 0.95, blue: 0.4),
        elevatedFill: Color(red: 0.03, green: 0.08, blue: 0.04)
    )

    /// Neon: Cyberpunk vibrant synthwave border with vivid glowing aura
    public static let neon = NotchTheme(
        id: .neon,
        surface: .solid(Color(red: 0.05, green: 0.05, blue: 0.09)),
        border: NotchBorderStyle(
            width: 1.5,
            gradient: NotchGradientDescriptor(
                colors: [Color(red: 1.0, green: 0.1, blue: 0.6), Color(red: 0.0, green: 0.85, blue: 1.0)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            glowColor: Color(red: 0.9, green: 0.1, blue: 0.7).opacity(0.4),
            glowRadius: 8
        ),
        shadow: NotchShadow(color: Color(red: 0.5, green: 0.05, blue: 0.8).opacity(0.3), radius: 20, x: 0, y: 6),
        overlay: .none,
        notchSafeBand: true,
        divider: .solid(color: Color(red: 0.0, green: 0.85, blue: 1.0).opacity(0.35), width: 1.0),
        cornerScale: 1.0,
        fontDesign: .default,
        card: NotchCardStyle(
            fill: Color(red: 0.08, green: 0.07, blue: 0.14),
            hoverFill: Color(red: 0.13, green: 0.11, blue: 0.22),
            borderColor: Color(red: 1.0, green: 0.2, blue: 0.7).opacity(0.35),
            borderWidth: 1.0
        ),
        buttonKind: .neonOutline,
        palette: NotchCardPaletteValues(
            allowFill: Color(red: 0.0, green: 0.6, blue: 0.7),
            allowFillHover: Color(red: 0.0, green: 0.75, blue: 0.85),
            deny: Color(red: 0.95, green: 0.15, blue: 0.45),
            link: Color(red: 0.2, green: 0.85, blue: 1.0),
            permission: Color(red: 1.0, green: 0.5, blue: 0.1)
        ),
        accent: Color(red: 0.0, green: 0.85, blue: 1.0),
        elevatedFill: Color(red: 0.07, green: 0.06, blue: 0.12)
    )

    public static func preset(for id: NotchThemeID) -> NotchTheme {
        switch id {
        case .classic: return .classic
        case .glass: return .glass
        case .liquidGlass: return .liquidGlass
        case .skeuo: return .skeuo
        case .modern: return .modern
        case .neumorph: return .neumorph
        case .terminal: return .terminal
        case .neon: return .neon
        }
    }
}

