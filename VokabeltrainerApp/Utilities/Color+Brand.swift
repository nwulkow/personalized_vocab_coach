import SwiftUI

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }

    static let brandIndigo = Color(hex: 0x667EEA)
    static let brandPurple = Color(hex: 0x764BA2)
    static let brandGreen = Color(hex: 0x20C997)
    static let brandGreenDark = Color(hex: 0x28A745)
    static let brandRed = Color(hex: 0xDC3545)
    static let brandAmber = Color(hex: 0xFFC107)
}

extension LinearGradient {
    static let brand = LinearGradient(
        colors: [.brandIndigo, .brandPurple],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let brandSuccess = LinearGradient(
        colors: [.brandGreenDark, .brandGreen],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}
