import SwiftUI

/// Displays single-line text that smoothly scrolls horizontally (marquee)
/// when the text width exceeds the available container width.
/// When the text fits, it is displayed static and centered.
struct MarqueeText: View {
    let text: String
    var font: Font = .system(size: 10.5, weight: .medium, design: .monospaced)
    var color: Color = .white.opacity(0.92)
    var speed: Double = 32 // pt per second

    @State private var textWidth: CGFloat = 0
    @State private var offset: CGFloat = 0
    @State private var scrollTask: Task<Void, Never>?

    var body: some View {
        GeometryReader { geo in
            let availableWidth = geo.size.width
            ZStack(alignment: .center) {
                // Invisible measuring view to get unconstrained text width
                Text(text)
                    .font(font)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .background(GeometryReader { textGeo in
                        Color.clear.preference(key: MarqueeTextWidthKey.self, value: textGeo.size.width)
                    })
                    .hidden()

                if textWidth <= availableWidth || textWidth == 0 || availableWidth == 0 {
                    Text(text)
                        .font(font)
                        .foregroundStyle(color)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .center)
                } else {
                    Text(text)
                        .font(font)
                        .foregroundStyle(color)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                        .offset(x: offset)
                        .frame(width: availableWidth, alignment: .leading)
                        .mask(
                            HStack(spacing: 0) {
                                LinearGradient(colors: [.clear, .black], startPoint: .leading, endPoint: .trailing)
                                    .frame(width: min(10, availableWidth * 0.08))
                                Rectangle().fill(.black)
                                LinearGradient(colors: [.black, .clear], startPoint: .leading, endPoint: .trailing)
                                    .frame(width: min(10, availableWidth * 0.08))
                            }
                        )
                }
            }
            .frame(width: availableWidth, height: geo.size.height, alignment: .center)
            .onPreferenceChange(MarqueeTextWidthKey.self) { newWidth in
                textWidth = newWidth
                restartMarquee(availableWidth: availableWidth)
            }
            .onChange(of: text) { _, _ in
                restartMarquee(availableWidth: availableWidth)
            }
            .onAppear {
                restartMarquee(availableWidth: availableWidth)
            }
            .onDisappear {
                scrollTask?.cancel()
                scrollTask = nil
            }
        }
    }

    private func restartMarquee(availableWidth: CGFloat) {
        scrollTask?.cancel()
        offset = 0
        guard textWidth > availableWidth, availableWidth > 0 else { return }

        let overflow = textWidth - availableWidth + 12
        let scrollDuration = Double(overflow) / speed

        scrollTask = Task { @MainActor in
            // Initial pause so the user can read the opening words
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            guard !Task.isCancelled else { return }

            while !Task.isCancelled {
                // Glide left to reveal the rest
                withAnimation(.linear(duration: scrollDuration)) {
                    offset = -overflow
                }
                try? await Task.sleep(nanoseconds: UInt64((scrollDuration + 1.2) * 1_000_000_000))
                guard !Task.isCancelled else { return }

                // Glide back to start
                withAnimation(.easeInOut(duration: 0.8)) {
                    offset = 0
                }
                try? await Task.sleep(nanoseconds: 1_400_000_000)
                guard !Task.isCancelled else { return }
            }
        }
    }
}

private struct MarqueeTextWidthKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

