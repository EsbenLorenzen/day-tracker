import Foundation
import SwiftUI
import DayTrackerCore

enum AppConfig {
    /// Days start at 04:00 (D14).
    static let dayBoundary = DayBoundary(startHour: 4)

    static var version: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(version) (build \(build))"
    }
}

extension Tracker {
    var color: Color {
        switch colorName {
        case "blue": .blue
        case "brown": .brown
        case "red": .red
        case "yellow": .yellow
        case "orange": .orange
        case "purple": .purple
        case "green": .green
        case "teal": .teal
        case "pink": .pink
        case "indigo": .indigo
        case "mint": .mint
        case "gray": .gray
        default: .accentColor
        }
    }
}

extension Date {
    var shortTime: String {
        formatted(date: .omitted, time: .shortened)
    }
}
