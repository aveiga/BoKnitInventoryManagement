import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Colour tokens for the hardware-panel look (grey chassis, hairline borders,
/// dark inset displays, single orange accent). Light/dark pairs are lifted
/// from the Teenage Engineering-style design pass.
enum BKColor {
    static let chassis = adaptive(light: 0xD9D8D3, dark: 0x1A1A1C)
    static let panel = adaptive(light: 0xF3F2EF, dark: 0x262628)
    static let panel2 = adaptive(light: 0xE7E6E1, dark: 0x313134)
    static let ink = adaptive(light: 0x16161A, dark: 0xF0EFEA)
    static let ink2 = adaptive(light: 0x5A5A57, dark: 0x96958F)
    static let line = adaptive(light: 0xC6C5C0, dark: 0x3A3A3D)

    /// Always dark — the "LCD" display used for stats and the quantity stepper.
    static let inset = Color(hex: 0x1A1A1C)
    static let insetInk = Color(hex: 0xE8E7E2)
    static let insetInkDim = Color(hex: 0x55555A)
    static let insetLabel = Color(hex: 0x7C7C80)
    static let insetLine = Color(hex: 0x3A3A3E)

    static let orange = Color(hex: 0xFF4A00)
    static let orangeShadow = Color(hex: 0xB83600)
    static let red = Color(hex: 0xD8321F)
    static let redText = adaptive(light: 0xA3200F, dark: 0xFF8A75)

    private static func adaptive(light: UInt32, dark: UInt32) -> Color {
        #if canImport(UIKit)
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light)
        })
        #else
        Color(hex: light)
        #endif
    }
}

extension Color {
    init(hex: UInt32) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8) & 0xFF) / 255
        let b = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: 1)
    }
}

#if canImport(UIKit)
extension UIColor {
    convenience init(hex: UInt32) {
        let r = CGFloat((hex >> 16) & 0xFF) / 255
        let g = CGFloat((hex >> 8) & 0xFF) / 255
        let b = CGFloat(hex & 0xFF) / 255
        self.init(red: r, green: g, blue: b, alpha: 1)
    }
}
#endif
