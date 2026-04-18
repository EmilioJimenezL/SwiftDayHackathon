import SwiftUI

// MARK: - Color Tokens
extension Color {
    static let cfPrimary    = Color(hex: "#4A7FA5")  // Blue — CTAs, headers
    static let cfAccent     = Color(hex: "#1A2B4A")  // Navy — links, highlights
    static let cfBackground = Color(hex: "#EBEBEB")  // Warm white — page bg
    static let cfSurface    = Color.white             // Cards & modals
    static let cfBorder     = Color(hex: "#D0CFC9")  // Subtle borders
    static let cfText1      = Color(hex: "#1A1A1A")  // Titles
    static let cfText2      = Color(hex: "#555555")  // Body
    static let cfText3      = Color(hex: "#888888")  // Captions / timestamps
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB,
                  red:   Double(r) / 255,
                  green: Double(g) / 255,
                  blue:  Double(b) / 255,
                  opacity: Double(a) / 255)
    }
}

// MARK: - Typography
struct CFFont {
    static func display(_ size: CGFloat = 30, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .default)
    }
    static func heading1(_ size: CGFloat = 22, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight)
    }
    static func heading2(_ size: CGFloat = 17, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight)
    }
    static func body(_ size: CGFloat = 16, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight)
    }
    static func caption(_ size: CGFloat = 13, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight)
    }
}

// MARK: - Spacing
struct CFSpacing {
    static let xs:   CGFloat = 4
    static let sm:   CGFloat = 8
    static let base: CGFloat = 16
    static let md:   CGFloat = 20
    static let lg:   CGFloat = 24
    static let xl:   CGFloat = 32
    static let cardGap: CGFloat = 12
    static let cardRadius: CGFloat = 14
    static let pillRadius: CGFloat = 100
    static let buttonHeight: CGFloat = 50
}

// MARK: - Animation
struct CFAnimation {
    static let spring = Animation.spring(response: 0.4, dampingFraction: 0.8)
    static let stagger: Double = 0.05
}
