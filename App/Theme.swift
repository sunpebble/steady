import SwiftUI

enum Theme {
    static let cream = Color(red: 1.0, green: 0.965, blue: 0.91)      // #FFF6E8
    static let ink = Color(red: 0.137, green: 0.153, blue: 0.20)      // #232733
    static let sun = Color(red: 0.969, green: 0.718, blue: 0.20)      // #F7B733
    static let pebble = Color(red: 0.431, green: 0.431, blue: 0.451)  // #6E6E73
    static let night = Color(red: 0.086, green: 0.098, blue: 0.157)   // #161928

    static let bg = dynamic(light: cream, dark: night)
    static let card = dynamic(light: .white.opacity(0.6), dark: ink)
    static let text = dynamic(light: ink, dark: cream)
    static let secondaryText = dynamic(light: pebble, dark: cream.opacity(0.55))

    static func font(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    private static func dynamic(light: Color, dark: Color) -> Color {
        Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light) })
    }
}
