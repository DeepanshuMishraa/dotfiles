import Foundation

public enum BorderShape: String, Equatable, Sendable {
    case round
    case square
    case uniform
}

public enum BorderPaint: String, Equatable, Sendable {
    case solid
    case gradient
    case glow
}

public enum BorderOrder: String, Equatable, Sendable {
    case above
    case below
}

public enum ThemeSource: String, Equatable, Sendable {
    case manual
    case hued
}

public struct ColorValue: Equatable, Sendable {
    public var red: UInt8
    public var green: UInt8
    public var blue: UInt8
    public var alpha: UInt8

    public init(red: UInt8, green: UInt8, blue: UInt8, alpha: UInt8 = 255) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    public init(_ string: String) throws {
        var value = string.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("#") { value.removeFirst() }
        if value.hasPrefix("0x") || value.hasPrefix("0X") { value.removeFirst(2) }
        guard value.count == 6 || value.count == 8,
              let number = UInt32(value, radix: 16) else {
            throw ConfigError.invalidValue("invalid color: \(string)")
        }
        if value.count == 6 {
            self.init(
                red: UInt8((number >> 16) & 0xff),
                green: UInt8((number >> 8) & 0xff),
                blue: UInt8(number & 0xff)
            )
        } else {
            self.init(
                red: UInt8((number >> 16) & 0xff),
                green: UInt8((number >> 8) & 0xff),
                blue: UInt8(number & 0xff),
                alpha: UInt8((number >> 24) & 0xff)
            )
        }
    }
}

public struct Appearance: Equatable, Sendable {
    public var paint: BorderPaint = .solid
    public var color = ColorValue(red: 225, green: 227, blue: 228)
    public var endColor: ColorValue?
    public var opacity: Double = 1
    public var width: Double?

    public init() {}
}

public struct AppearanceOverride: Equatable, Sendable {
    public var paint: BorderPaint?
    public var color: ColorValue?
    public var endColor: ColorValue?
    public var opacity: Double?
    public var width: Double?

    public init() {}
}

public struct AppRule: Equatable, Sendable {
    public var name: String
    public var bundleIdentifier: String?
    public var excluded = false
    public var radius: Double?
    public var active: AppearanceOverride?
    public var inactive: AppearanceOverride?

    public init(name: String) { self.name = name }
}

public struct BorderConfiguration: Equatable, Sendable {
    public var enabled = true
    public var shape: BorderShape = .round
    public var width = 3.0
    public var gap = -1.0
    public var radius: Double? = nil
    public var hidpi = true
    public var order: BorderOrder = .above
    public var active = Appearance()
    public var inactive = Appearance()
    public var fadeEnabled = true
    public var fadeDurationMilliseconds = 120.0
    public var disableAnimationDuringDrag = true
    public var hideInFullscreen = true
    public var coverNotch = false
    public var themeSource: ThemeSource = .manual
    public var themeActiveField = "accent"
    public var themeInactiveField = "surface1"
    public var themeActiveEndField: String?
    public var themeInactiveEndField: String?
    public var excludedBundleIdentifiers: Set<String> = []
    public var excludedWindowRoles: Set<String> = ["dialog", "popover"]
    public var apps: [String: AppRule] = [:]

    public init() {
        active.paint = .solid
        active.color = ColorValue(red: 225, green: 227, blue: 228)
        inactive.paint = .solid
        inactive.color = ColorValue(red: 73, green: 77, blue: 100)
        inactive.opacity = 0.35
    }

    public func rule(for appName: String, bundleIdentifier: String?) -> AppRule? {
        if let bundleIdentifier, let rule = apps[bundleIdentifier] { return rule }
        if let bundleIdentifier,
           let rule = apps.values.first(where: { $0.bundleIdentifier == bundleIdentifier }) { return rule }
        return apps.first { $0.key.caseInsensitiveCompare(appName) == .orderedSame }?.value
    }

    public func appearance(focused: Bool, appName: String, bundleIdentifier: String?) -> Appearance {
        let base = focused ? active : inactive
        guard let rule = rule(for: appName, bundleIdentifier: bundleIdentifier),
              !(rule.excluded) else { return base }
        var result = base
        if let override = focused ? rule.active : rule.inactive {
            if let paint = override.paint { result.paint = paint }
            if let color = override.color { result.color = color }
            result.endColor = override.endColor ?? result.endColor
            if let opacity = override.opacity { result.opacity = opacity }
            if let width = override.width { result.width = width }
        }
        return result
    }

    public func isExcluded(appName: String, bundleIdentifier: String?) -> Bool {
        if let bundleIdentifier, excludedBundleIdentifiers.contains(bundleIdentifier) { return true }
        return rule(for: appName, bundleIdentifier: bundleIdentifier)?.excluded ?? false
    }
}

public enum ConfigError: Error, CustomStringConvertible, Equatable {
    case invalidValue(String)
    case invalidSection(String)

    public var description: String {
        switch self {
        case .invalidValue(let value), .invalidSection(let value): return value
        }
    }
}

public enum ConfigurationLoader {
    public static func load(from url: URL) throws -> BorderConfiguration {
        guard FileManager.default.fileExists(atPath: url.path) else { return BorderConfiguration() }
        let text = try String(contentsOf: url, encoding: .utf8)
        return try parse(text)
    }

    public static func parse(_ text: String) throws -> BorderConfiguration {
        var config = BorderConfiguration()
        var section = ""
        for (index, rawLine) in text.components(separatedBy: .newlines).enumerated() {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix("#") { continue }
            if line.hasPrefix("[") && line.hasSuffix("]") {
                section = String(line.dropFirst().dropLast())
                continue
            }
            guard let equal = line.firstIndex(of: "=") else {
                throw ConfigError.invalidValue("line \(index + 1): expected key = value")
            }
            let key = String(line[..<equal]).trimmingCharacters(in: .whitespaces)
            let value = String(line[line.index(after: equal)...]).trimmingCharacters(in: .whitespaces)
            try apply(key: key, value: value, section: section, to: &config, line: index + 1)
        }
        try validate(config)
        return config
    }

    private static func apply(key: String, value: String, section: String,
                              to config: inout BorderConfiguration, line: Int) throws {
        func string() throws -> String {
            let trimmed = value.trimmingCharacters(in: .whitespaces)
            guard trimmed.count >= 2, trimmed.first == "\"", trimmed.last == "\"" else {
                throw ConfigError.invalidValue("line \(line): expected quoted string for \(key)")
            }
            return String(trimmed.dropFirst().dropLast())
        }
        func bool() throws -> Bool {
            guard value == "true" || value == "false" else { throw ConfigError.invalidValue("line \(line): invalid boolean") }
            return value == "true"
        }
        func number() throws -> Double {
            guard let result = Double(value) else { throw ConfigError.invalidValue("line \(line): invalid number") }
            return result
        }
        func color() throws -> ColorValue { try ColorValue(string()) }
        func list() throws -> [String] {
            let trimmed = value.trimmingCharacters(in: .whitespaces)
            guard trimmed.first == "[", trimmed.last == "]" else { throw ConfigError.invalidValue("line \(line): expected array") }
            return try trimmed.dropFirst().dropLast().split(separator: ",", omittingEmptySubsequences: true).map {
                let item = String($0).trimmingCharacters(in: .whitespaces)
                guard item.count >= 2, item.first == "\"", item.last == "\"" else { throw ConfigError.invalidValue("line \(line): arrays contain quoted strings") }
                return String(item.dropFirst().dropLast())
            }
        }

        switch section {
        case "":
            switch key {
            case "enabled": config.enabled = try bool()
            case "shape": config.shape = try BorderShape(rawValue: string()) ?? { throw ConfigError.invalidValue("line \(line): invalid shape") }()
            case "width": config.width = try number()
            case "gap": config.gap = try number()
            case "radius":
                if value == "\"native\"" { config.radius = nil } else { config.radius = try number() }
            case "hidpi": config.hidpi = try bool()
            case "border_order": config.order = try BorderOrder(rawValue: string()) ?? { throw ConfigError.invalidValue("line \(line): invalid border_order") }()
            case "excluded_bundle_identifiers": config.excludedBundleIdentifiers = Set(try list())
            case "excluded_window_roles": config.excludedWindowRoles = Set(try list())
            case "hide_in_fullscreen": config.hideInFullscreen = try bool()
            case "cover_notch": config.coverNotch = try bool()
            default: throw ConfigError.invalidValue("line \(line): unknown key \(key)")
            }
        case "active", "inactive":
            var appearance = section == "active" ? config.active : config.inactive
            switch key {
            case "paint": appearance.paint = try BorderPaint(rawValue: string()) ?? { throw ConfigError.invalidValue("line \(line): invalid paint") }()
            case "color": appearance.color = try color()
            case "end_color": appearance.endColor = try color()
            case "opacity": appearance.opacity = try number()
            case "width": appearance.width = try number()
            default: throw ConfigError.invalidValue("line \(line): unknown appearance key \(key)")
            }
            if section == "active" { config.active = appearance } else { config.inactive = appearance }
        case "animation":
            switch key {
            case "enabled": config.fadeEnabled = try bool()
            case "fade_duration_ms": config.fadeDurationMilliseconds = try number()
            case "disable_during_drag": config.disableAnimationDuringDrag = try bool()
            default: throw ConfigError.invalidValue("line \(line): unknown animation key \(key)")
            }
        case "theme":
            switch key {
            case "source": config.themeSource = try ThemeSource(rawValue: string()) ?? { throw ConfigError.invalidValue("line \(line): invalid theme source") }()
            case "active_field": config.themeActiveField = try string()
            case "inactive_field": config.themeInactiveField = try string()
            case "active_end_field": config.themeActiveEndField = try string()
            case "inactive_end_field": config.themeInactiveEndField = try string()
            default: throw ConfigError.invalidValue("line \(line): unknown theme key \(key)")
            }
        case let appSection where appSection.hasPrefix("apps."):
            let rawName = String(appSection.dropFirst(5)).trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            var rule = config.apps[rawName] ?? AppRule(name: rawName)
            switch key {
            case "bundle_identifier": rule.bundleIdentifier = try string()
            case "excluded": rule.excluded = try bool()
            case "radius": rule.radius = try number()
            case "active_paint": rule.active = (rule.active ?? AppearanceOverride()); rule.active?.paint = try BorderPaint(rawValue: string()) ?? { throw ConfigError.invalidValue("line \(line): invalid active_paint") }()
            case "active_color": rule.active = (rule.active ?? AppearanceOverride()); rule.active?.color = try color()
            case "active_end_color": rule.active = (rule.active ?? AppearanceOverride()); rule.active?.endColor = try color()
            case "active_opacity": rule.active = (rule.active ?? AppearanceOverride()); rule.active?.opacity = try number()
            case "inactive_paint": rule.inactive = (rule.inactive ?? AppearanceOverride()); rule.inactive?.paint = try BorderPaint(rawValue: string()) ?? { throw ConfigError.invalidValue("line \(line): invalid inactive_paint") }()
            case "inactive_color": rule.inactive = (rule.inactive ?? AppearanceOverride()); rule.inactive?.color = try color()
            case "inactive_end_color": rule.inactive = (rule.inactive ?? AppearanceOverride()); rule.inactive?.endColor = try color()
            case "inactive_opacity": rule.inactive = (rule.inactive ?? AppearanceOverride()); rule.inactive?.opacity = try number()
            default: throw ConfigError.invalidValue("line \(line): unknown app key \(key)")
            }
            config.apps[rawName] = rule
        default: throw ConfigError.invalidSection(section)
        }
    }

    public static func validate(_ config: BorderConfiguration) throws {
        guard config.width > 0, config.width <= 32 else { throw ConfigError.invalidValue("width must be > 0 and <= 32") }
        for appearance in [config.active, config.inactive] {
            guard appearance.opacity >= 0, appearance.opacity <= 1 else { throw ConfigError.invalidValue("opacity must be between 0 and 1") }
            if let width = appearance.width, !(width > 0 && width <= 32) { throw ConfigError.invalidValue("appearance width must be > 0 and <= 32") }
        }
        for rule in config.apps.values {
            if let radius = rule.radius, radius < 0 { throw ConfigError.invalidValue("app radius cannot be negative") }
            for override in [rule.active, rule.inactive].compactMap({ $0 }) {
                if let opacity = override.opacity, !(opacity >= 0 && opacity <= 1) { throw ConfigError.invalidValue("app opacity must be between 0 and 1") }
                if let width = override.width, !(width > 0 && width <= 32) { throw ConfigError.invalidValue("app width must be > 0 and <= 32") }
            }
        }
        guard config.fadeDurationMilliseconds >= 0 else { throw ConfigError.invalidValue("animation duration cannot be negative") }
    }
}
