import AppKit

enum AppColors {
    static let accentGreen = NSColor(calibratedRed: 0.45, green: 0.82, blue: 0.68, alpha: 0.95)

    // Text
    static let titleText = NSColor(calibratedWhite: 0.96, alpha: 0.98)
    static let subtitleText = NSColor(calibratedWhite: 0.80, alpha: 0.84)
    static let cardTitleText = NSColor(calibratedWhite: 0.82, alpha: 0.74)
    static let secondaryLabel = NSColor(calibratedWhite: 0.82, alpha: 0.78)
    static let chipLabel = NSColor(calibratedWhite: 0.95, alpha: 0.92)
    static let inputText = NSColor(calibratedWhite: 0.92, alpha: 0.96)
    static let outputText = NSColor(calibratedWhite: 0.90, alpha: 0.95)
    static let errorText = NSColor(calibratedRed: 1.0, green: 0.56, blue: 0.56, alpha: 0.97)
    static let placeholderText = NSColor(calibratedWhite: 0.70, alpha: 0.55)
    static let outputPlaceholder = NSColor(calibratedWhite: 0.72, alpha: 0.58)
    static let iconDefault = NSColor(calibratedWhite: 1.0, alpha: 0.45)
    static let closeIcon = NSColor(calibratedWhite: 1.0, alpha: 0.70)
    static let clearAllText = NSColor(calibratedWhite: 0.82, alpha: 0.65)

    // Borders & Backgrounds
    static let chipBorder = NSColor(calibratedWhite: 1, alpha: 0.35)
    static let chipBorderDefault = NSColor(calibratedWhite: 1, alpha: 0.28)
    static let chipBorderHover = NSColor(calibratedWhite: 1, alpha: 0.40)
    static let chipBackground = NSColor(calibratedWhite: 1.0, alpha: 0.22)
    static let cardBorder = NSColor(calibratedWhite: 1, alpha: 0.08)
    static let panelBorder = NSColor(calibratedWhite: 1.0, alpha: 0.07)
    static let containerBackground = NSColor(calibratedRed: 0.06, green: 0.07, blue: 0.09, alpha: 0.48)
    static let panelBackground = NSColor(calibratedRed: 0.06, green: 0.07, blue: 0.09, alpha: 0.55)
    static let cardBackground = NSColor(calibratedRed: 0.08, green: 0.09, blue: 0.12, alpha: 0.42)
}

enum Layout {
    static let outerPadding: CGFloat = 20
    static let splitSpacing: CGFloat = 14
    static let cardCornerRadius: CGFloat = 16
    static let panelCornerRadius: CGFloat = 22
    static let minimumPanelWidth: CGFloat = 600
    static let minimumPanelHeight: CGFloat = 420
    static let cardInnerPadding: CGFloat = 14
    static let cardTitleTopPadding: CGFloat = 12
}
