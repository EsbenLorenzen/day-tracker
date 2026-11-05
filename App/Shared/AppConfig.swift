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

/// Color tokens stored on trackers, and the choices offered in pickers.
enum TrackerPalette {
    static let colorNames = ["red", "orange", "yellow", "green", "mint", "teal",
                             "blue", "indigo", "purple", "pink", "brown", "gray"]

    static let medicineIcons = ["pills.fill", "pill.fill", "cross.case.fill", "syringe.fill",
                                "bandage.fill", "drop.fill", "heart.fill", "leaf.fill",
                                "sun.max.fill", "moon.fill", "bolt.fill", "staroflife.fill"]

    static let generalIcons = ["drop.fill", "cup.and.saucer.fill", "wineglass.fill", "mug.fill",
                               "fork.knife", "carrot.fill", "figure.walk", "dumbbell.fill",
                               "bed.double.fill", "brain.head.profile", "face.smiling", "bolt.fill",
                               "scope", "heart.fill", "waveform.path.ecg", "lungs.fill",
                               "sun.max.fill", "moon.fill", "cloud.rain.fill", "flame.fill",
                               "book.fill", "pencil", "star.fill", "scalemass.fill"]

    static func color(named name: String) -> Color {
        switch name {
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

extension Tracker {
    var color: Color { TrackerPalette.color(named: colorName) }
}

extension Date {
    var shortTime: String {
        formatted(date: .omitted, time: .shortened)
    }
}
