import SwiftUI

// MARK: - Scanline Shape / Texture

public struct ScanlinesOverlay: View {
    let opacity: Double
    let spacing: CGFloat

    public init(opacity: Double = 0.12, spacing: CGFloat = 3.0) {
        self.opacity = opacity
        self.spacing = spacing
    }

    public var body: some View {
        Canvas { context, size in
            var y: CGFloat = 0
            while y < size.height {
                let path = Path { p in
                    p.move(to: CGPoint(x: 0, y: y))
                    p.addLine(to: CGPoint(x: size.width, y: y))
                }
                context.stroke(path, with: .color(.black.opacity(opacity)), lineWidth: 1.0)
                y += spacing
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Noise Overlay

public struct NoiseOverlay: View {
    let opacity: Double

    public init(opacity: Double = 0.05) {
        self.opacity = opacity
    }

    public var body: some View {
        Canvas { context, size in
            // Generate subtle monochromatic point noise
            let step: CGFloat = 4.0
            var x: CGFloat = 0
            while x < size.width {
                var y: CGFloat = 0
                while y < size.height {
                    let rand = Double((Int(x * 37 + y * 17) & 0xFF)) / 255.0
                    if rand > 0.5 {
                        let rect = CGRect(x: x, y: y, width: step, height: step)
                        let alpha = (rand - 0.5) * 2.0 * opacity
                        context.fill(Path(rect), with: .color(.white.opacity(alpha)))
                    }
                    y += step
                }
                x += step
            }
        }
        .allowsHitTesting(false)
    }
}

