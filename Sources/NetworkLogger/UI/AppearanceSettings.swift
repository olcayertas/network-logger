#if canImport(SwiftUI)
import Foundation
import Perception
import SwiftUI

/// User-tunable appearance for `NetworkLoggerView`.
///
/// Persisted to `UserDefaults.standard` under the `NetworkLogger.appearance.*`
/// namespace so settings survive across launches. Backed by `Perception` so the
/// UI re-renders when any field changes. All writes happen from SwiftUI views
/// (main actor); reads from the environment key may come from any actor.
@Perceptible
public final class AppearanceSettings: @unchecked Sendable {
    public static let shared = AppearanceSettings()

    public enum ColorSchemeOverride: String, CaseIterable, Sendable {
        case system, light, dark

        var swiftUI: ColorScheme? {
            switch self {
            case .system: nil
            case .light:  .light
            case .dark:   .dark
            }
        }
    }

    public enum AccentTint: String, CaseIterable, Sendable {
        case blue, indigo, purple, teal, green, orange, pink

        var color: Color {
            switch self {
            case .blue:   .blue
            case .indigo: .indigo
            case .purple: .purple
            case .teal:   .teal
            case .green:  .green
            case .orange: .orange
            case .pink:   .pink
            }
        }
    }

    public var bodyFontSize: Double {
        didSet { defaults.set(bodyFontSize, forKey: Self.fontKey) }
    }

    public var colorScheme: ColorSchemeOverride {
        didSet { defaults.set(colorScheme.rawValue, forKey: Self.schemeKey) }
    }

    public var accent: AccentTint {
        didSet { defaults.set(accent.rawValue, forKey: Self.accentKey) }
    }

    @PerceptionIgnored
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.bodyFontSize = (defaults.object(forKey: Self.fontKey) as? Double) ?? Self.defaultFontSize
        self.colorScheme = (defaults.string(forKey: Self.schemeKey).flatMap(ColorSchemeOverride.init(rawValue:))) ?? .system
        self.accent = (defaults.string(forKey: Self.accentKey).flatMap(AccentTint.init(rawValue:))) ?? .blue
    }

    public func resetToDefaults() {
        bodyFontSize = Self.defaultFontSize
        colorScheme = .system
        accent = .blue
    }

    public static let defaultFontSize: Double = 12
    public static let minFontSize: Double = 9
    public static let maxFontSize: Double = 22

    /// Returns the active syntax-highlighting palette for the given color scheme.
    public func syntaxTheme(for scheme: ColorScheme) -> SyntaxTheme {
        scheme == .dark ? .darkDefault : .lightDefault
    }

    private static let fontKey   = "NetworkLogger.appearance.bodyFontSize"
    private static let schemeKey = "NetworkLogger.appearance.colorScheme"
    private static let accentKey = "NetworkLogger.appearance.accent"
}

/// Token-level palette for JSON syntax highlighting in body views.
///
/// Two presets ship out of the box (`.lightDefault`, `.darkDefault`); custom
/// palettes can be constructed directly.
public struct SyntaxTheme: Sendable, Equatable {
    public var key: Color
    public var string: Color
    public var number: Color
    public var boolean: Color
    public var null: Color
    public var punctuation: Color

    public init(key: Color, string: Color, number: Color, boolean: Color, null: Color, punctuation: Color) {
        self.key = key
        self.string = string
        self.number = number
        self.boolean = boolean
        self.null = null
        self.punctuation = punctuation
    }

    /// Xcode-ish light palette. Tuned for paper-white surfaces.
    public static let lightDefault = SyntaxTheme(
        key:         Color(red: 0.55, green: 0.10, blue: 0.55),
        string:      Color(red: 0.78, green: 0.21, blue: 0.13),
        number:      Color(red: 0.10, green: 0.36, blue: 0.78),
        boolean:     Color(red: 0.66, green: 0.30, blue: 0.04),
        null:        Color(red: 0.50, green: 0.50, blue: 0.50),
        punctuation: Color(red: 0.30, green: 0.30, blue: 0.30)
    )

    /// Higher-saturation palette for dark surfaces.
    public static let darkDefault = SyntaxTheme(
        key:         Color(red: 0.78, green: 0.51, blue: 0.90),
        string:      Color(red: 0.96, green: 0.55, blue: 0.45),
        number:      Color(red: 0.45, green: 0.78, blue: 0.97),
        boolean:     Color(red: 0.98, green: 0.74, blue: 0.36),
        null:        Color(red: 0.60, green: 0.60, blue: 0.65),
        punctuation: Color(red: 0.80, green: 0.80, blue: 0.85)
    )
}

private struct AppearanceSettingsKey: EnvironmentKey {
    static let defaultValue: AppearanceSettings = .shared
}

extension EnvironmentValues {
    var networkLoggerAppearance: AppearanceSettings {
        get { self[AppearanceSettingsKey.self] }
        set { self[AppearanceSettingsKey.self] = newValue }
    }
}
#endif
