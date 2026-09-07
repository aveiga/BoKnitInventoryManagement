import SwiftUI

/// Type scale for the hardware-panel look. There's no bundled display face,
/// so headlines lean on heavy system weights with tight tracking, and every
/// small label uses the system monospaced face wide-tracked and uppercased —
/// standing in for Archivo / Space Mono without adding font assets.
extension View {
    func bkScreenTitle() -> some View {
        font(.system(size: 29, weight: .heavy, design: .default))
            .tracking(-0.6)
            .textCase(.uppercase)
    }

    func bkRowTitle(size: CGFloat = 15) -> some View {
        font(.system(size: size, weight: .semibold, design: .default))
            .tracking(-0.1)
    }

    func bkMonoLabel(size: CGFloat = 10, weight: Font.Weight = .regular) -> some View {
        font(.system(size: size, weight: weight, design: .monospaced))
            .tracking(1.2)
            .textCase(.uppercase)
    }

    func bkStatNumber(size: CGFloat = 28) -> some View {
        font(.system(size: size, weight: .bold, design: .default))
            .monospacedDigit()
            .tracking(-0.5)
    }
}

/// A number rendered with its leading zero-padding dimmed, matching the
/// inset "LCD" displays (e.g. quantity `004`, stock `012`).
struct BKDimmedNumber: View {
    let value: Int
    let minDigits: Int
    var size: CGFloat = 34
    var brightColor: Color = BKColor.insetInk
    /// Colour for the dimmed leading-zero digits. Defaults to a faded version
    /// of `brightColor` (for panels); pass a fixed colour like
    /// `BKColor.insetInkDim` when rendering on a dark inset display.
    var dimColor: Color?

    private var digits: String { String(format: "%0\(minDigits)d", max(0, value)) }

    var body: some View {
        let text = digits
        let firstNonZero = text.firstIndex(where: { $0 != "0" }) ?? text.index(before: text.endIndex)
        HStack(spacing: 0) {
            ForEach(Array(text.enumerated()), id: \.offset) { index, char in
                Text(String(char))
                    .font(.system(size: size, weight: .bold, design: .default))
                    .monospacedDigit()
                    .tracking(-0.5)
                    .foregroundStyle(text.distance(from: text.startIndex, to: firstNonZero) > index
                        ? (dimColor ?? brightColor.opacity(0.22))
                        : brightColor)
            }
        }
    }
}
