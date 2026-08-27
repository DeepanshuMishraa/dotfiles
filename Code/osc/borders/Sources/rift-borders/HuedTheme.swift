import Foundation
import RiftBordersCore

struct HuedState: Decodable {
    let theme: String
}

struct HuedTheme: Decodable {
    let palette: [String: String]
}

final class HuedThemeProvider {
    private let stateURL: URL
    private let themeDirectories: [URL]
    private(set) var palette: [String: ColorValue] = [:]

    init(home: URL = FileManager.default.homeDirectoryForCurrentUser) {
        let configRoot = home.appendingPathComponent(".config/hued")
        let stateRoot = home.appendingPathComponent(".local/state/hued")
        stateURL = stateRoot.appendingPathComponent("state.json")
        themeDirectories = [
            configRoot.appendingPathComponent("themes/custom"),
            configRoot.appendingPathComponent("themes/bundled")
        ]
    }

    var watchedURL: URL { stateURL }

    @discardableResult
    func reload() -> Bool {
        do {
            let stateData = try Data(contentsOf: stateURL)
            let state = try JSONDecoder().decode(HuedState.self, from: stateData)
            guard let themeURL = themeDirectories
                .map({ $0.appendingPathComponent("\(state.theme).json") })
                .first(where: { FileManager.default.fileExists(atPath: $0.path) }) else { return false }
            let theme = try JSONDecoder().decode(HuedTheme.self, from: Data(contentsOf: themeURL))
            var next: [String: ColorValue] = [:]
            for (field, value) in theme.palette {
                if let color = try? ColorValue(value) { next[field] = color }
            }
            guard !next.isEmpty else { return false }
            palette = next
            return true
        } catch {
            return false
        }
    }

    func color(for field: String) -> ColorValue? { palette[field] }
}
