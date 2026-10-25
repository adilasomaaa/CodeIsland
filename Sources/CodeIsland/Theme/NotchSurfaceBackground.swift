import SwiftUI

public struct NotchSurfaceContext {
    public let isExpanded: Bool
    public let isFloating: Bool
    public let usesPhysicalNotch: Bool
    public let notchHeight: CGFloat

    public init(
        isExpanded: Bool,
        isFloating: Bool,
        usesPhysicalNotch: Bool,
        notchHeight: CGFloat
    ) {
        self.isExpanded = isExpanded
        self.isFloating = isFloating
        self.usesPhysicalNotch = usesPhysicalNotch
        self.notchHeight = notchHeight
    }
}

public struct NotchSurfaceBackground<S: Shape>: View {
    public let shape: S
    public let theme: NotchTheme
    public let context: NotchSurfaceContext

    public init(
        shape: S,
        theme: NotchTheme,
        context: NotchSurfaceContext
    ) {
        self.shape = shape
        self.theme = theme
        self.context = context
    }

    public var body: some View {
        ZStack {
            // Layer 1: Base Fill / Blur Material
            surfaceBase

            // Layer 2: Texture / Overlay (Noise / Scanlines)
            switch theme.overlay {
            case .none:
                EmptyView()
            case .noise(let opacity):
                NoiseOverlay(opacity: opacity)
            case .scanlines(let opacity):
                ScanlinesOverlay(opacity: opacity)
            }

            // Layer 3: Notch-Safe Band
            // Blends top notch area with pure black on physical notch attached mode
            if context.usesPhysicalNotch && !context.isFloating && theme.notchSafeBand {
                notchSafeBandView
            }

            // Layer 4: Border / Outline / Glow
            if let border = theme.border {
                borderView(border)
            }
        }
        .clipShape(shape)
        // Layer 5: Shadows
        .background {
            shadowsView
        }
    }

    @ViewBuilder
    private var surfaceBase: some View {
        switch theme.surface {
        case .solid(let color):
            shape.fill(color)

        case .gradient(let descriptor):
            shape.fill(descriptor.linearGradient)

        case .material(let fallback):
            ZStack {
                VisualEffectBlur(material: fallback.materialStyle, blendingMode: .behindWindow, state: .active)
                shape.fill(fallback.tint.opacity(fallback.opacity))
            }

        case .liquidGlass(let tint):
            ZStack {
                VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow, state: .active)
                shape.fill(tint)
            }

        case .neumorphic(let base):
            shape.fill(base)
        }
    }

    @ViewBuilder
    private var notchSafeBandView: some View {
        VStack(spacing: 0) {
            Color.black
                .frame(height: max(0, context.notchHeight - 4))
            LinearGradient(
                colors: [Color.black, Color.black.opacity(0.0)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 8)
            Spacer(minLength: 0)
        }
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private func borderView(_ border: NotchBorderStyle) -> some View {
        ZStack {
            if let glowColor = border.glowColor, border.glowRadius > 0 {
                shape.stroke(glowColor, lineWidth: border.width)
                    .blur(radius: border.glowRadius)
            }
            if let gradient = border.gradient {
                shape.stroke(gradient.linearGradient, lineWidth: border.width)
            } else if let color = border.color {
                shape.stroke(color, lineWidth: border.width)
            }
        }
    }

    @ViewBuilder
    private var shadowsView: some View {
        let shadow = theme.shadow
        let shouldShadow = context.isFloating || context.isExpanded

        if shouldShadow {
            ZStack {
                // Primary shadow
                shape
                    .fill(Color.clear)
                    .shadow(
                        color: shadow.color,
                        radius: shadow.radius,
                        x: shadow.x,
                        y: shadow.y
                    )

                // Secondary Neumorphic Highlight shadow if present
                if let highlightColor = shadow.highlightColor, shadow.highlightRadius > 0 {
                    shape
                        .fill(Color.clear)
                        .shadow(
                            color: highlightColor,
                            radius: shadow.highlightRadius,
                            x: shadow.highlightX,
                            y: shadow.highlightY
                        )
                }
            }
        }
    }
}

