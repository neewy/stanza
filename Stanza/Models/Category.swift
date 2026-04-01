import Foundation
import SwiftData
import SwiftUI

@Model
final class Category {
    @Attribute(.unique) var id: UUID
    var name: String
    var hexColor: String
    
    // Relationship to time entries
    @Relationship(deleteRule: .nullify, inverse: \TimeEntry.category)
    var timeEntries: [TimeEntry]
    
    init(id: UUID = UUID(), name: String, hexColor: String = "#0000FF") {
        self.id = id
        self.name = name
        self.hexColor = hexColor
        self.timeEntries = []
    }
    
    var color: Color {
        Color(hex: hexColor) ?? .blue
    }
}

// Extension to load hex color
extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0

        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }

        let r = Double((rgb & 0xFF0000) >> 16) / 255.0
        let g = Double((rgb & 0x00FF00) >> 8) / 255.0
        let b = Double(rgb & 0x0000FF) / 255.0

        self.init(red: r, green: g, blue: b)
    }
    
    func toHex() -> String {
        guard let nsColor = NSColor(self).usingColorSpace(.sRGB) else { return "#808080" }
        let r = Int(round(nsColor.redComponent * 255))
        let g = Int(round(nsColor.greenComponent * 255))
        let b = Int(round(nsColor.blueComponent * 255))
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
