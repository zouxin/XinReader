import Foundation
import SwiftUI

/// Reader appearance settings. Stored globally (not per-book).
struct ReaderSettings: Codable, Equatable {
    var fontFamily: String       // e.g. "Georgia", "System", "Menlo"
    var fontSize: CGFloat        // 14–32 pt
    var lineSpacing: CGFloat     // 1.0–2.5 multiplier
    var theme: ReaderTheme

    enum ReaderTheme: String, Codable, CaseIterable, Identifiable {
        case light
        case sepia
        case dark
        case eyeProtection

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .light: return "浅色"
            case .sepia: return "暖纸"
            case .dark: return "深色"
            case .eyeProtection: return "护眼"
            }
        }

        var backgroundColor: String {
            switch self {
            case .light: return "#FFFFFF"
            case .sepia: return "#F5E6C8"
            case .dark: return "#1E1E1E"
            case .eyeProtection: return "#C7EDCC"
            }
        }

        var textColor: String {
            switch self {
            case .light: return "#1A1A1A"
            case .sepia: return "#5B4636"
            case .dark: return "#D4D4D4"
            case .eyeProtection: return "#2D4A2D"
            }
        }

        var linkColor: String {
            switch self {
            case .light: return "#0066CC"
            case .sepia: return "#8B6914"
            case .dark: return "#6CB4EE"
            case .eyeProtection: return "#3D7A3D"
            }
        }

        var nsBackgroundColor: NSColor {
            NSColor(hex: backgroundColor) ?? .white
        }

        var nsTextColor: NSColor {
            NSColor(hex: textColor) ?? .black
        }
    }

    static let `default` = ReaderSettings(
        fontFamily: "Georgia",
        fontSize: 18,
        lineSpacing: 1.6,
        theme: .light
    )

    // Available font families for the picker
    static let availableFonts: [String] = [
        "Georgia",
        "Times New Roman",
        "Palatino",
        "Helvetica Neue",
        "San Francisco",
        "Menlo",
        "Songti SC",       // 宋体
        "STKaiti",         // 楷体
        "PingFang SC",     // 苹方
    ]
}

// MARK: - NSColor hex extension

extension NSColor {
    convenience init?(hex: String) {
        var hexString = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if hexString.hasPrefix("#") {
            hexString.removeFirst()
        }

        guard hexString.count == 6,
              let rgb = UInt64(hexString, radix: 16) else {
            return nil
        }

        let r = CGFloat((rgb >> 16) & 0xFF) / 255.0
        let g = CGFloat((rgb >> 8) & 0xFF) / 255.0
        let b = CGFloat(rgb & 0xFF) / 255.0

        self.init(red: r, green: g, blue: b, alpha: 1.0)
    }
}
