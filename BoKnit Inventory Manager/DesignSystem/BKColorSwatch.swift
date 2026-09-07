import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Maps an inventory colour name (Portuguese, free text from the imported
/// spreadsheet) to a swatch colour for the colour-key tiles and row accents.
/// Known names get a curated colour; anything else gets a stable pastel
/// derived from the name so the same colour always renders the same swatch.
enum BKColorSwatch {
    private static let known: [String: UInt32] = [
        "verde": 0x1E5C46,
        "azul": 0x3B6FD4,
        "vermelho": 0xC4342B,
        "roxo": 0x6B4E9B,
        "violeta": 0xA9A2F2,
        "rosa": 0xE06482,
        "dourado": 0xC8A24A,
        "prateado": 0xBFC0C2,
        "cinzento": 0x8A8A86,
        "cinza": 0x8A8A86,
        "preto": 0x2A2A2C,
        "branco": 0xF2F1ED,
        "amarelo": 0xE8C547,
        "laranja": 0xE0742E,
        "menta": 0x7FC9A8,
        "marrom": 0x6B4A34,
        "castanho": 0x6B4A34,
        "bege": 0xD9C7A8,
        "turquesa": 0x3FB7B0,
        "coral": 0xE0745E,
        "lima": 0xA8C24A,
        "alfazema": 0xB9A8E0,
    ]

    static func hex(for colorName: String) -> UInt32 {
        let key = colorName
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: .diacriticInsensitive, locale: .current)

        if let exact = known[key] { return exact }
        for (name, hex) in known where key.contains(name) { return hex }

        // Stable pastel fallback for anything not in the curated list.
        var hasher = Hasher()
        hasher.combine(key)
        let hash = UInt32(bitPattern: Int32(truncatingIfNeeded: hasher.finalize()))
        let hue = Double(hash % 360) / 360
        let color = Color(hue: hue, saturation: 0.42, brightness: 0.62)
        #if canImport(UIKit)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a)
        return (UInt32(r * 255) << 16) | (UInt32(g * 255) << 8) | UInt32(b * 255)
        #else
        return 0x8A8A86
        #endif
    }

    static func color(for colorName: String) -> Color {
        Color(hex: hex(for: colorName))
    }
}
