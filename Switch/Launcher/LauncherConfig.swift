import Combine
import Foundation

/// One row of the launcher mapping table. keyCode/target are optional so the
/// settings UI can hold half-filled rows; lookup ignores incomplete rows.
/// `target` is an app bundle path ("/Applications/Safari.app") or a URL
/// string ("cleanshot://capture-window") — see LauncherTarget.
struct LauncherMapping: Equatable, Identifiable {
    var id = UUID()
    var keyCode: UInt16?
    var target: String?
    var isSecondary: Bool = false
}

extension LauncherMapping: Codable {
    private enum CodingKeys: String, CodingKey {
        case id, keyCode, target, isSecondary
        case appURL // legacy: targets were originally persisted as URLs
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        keyCode = try container.decodeIfPresent(UInt16.self, forKey: .keyCode)
        isSecondary = try container.decode(Bool.self, forKey: .isSecondary)
        if let target = try container.decodeIfPresent(String.self, forKey: .target) {
            self.target = target
        } else if let url = try container.decodeIfPresent(URL.self, forKey: .appURL) {
            target = url.isFileURL ? url.path : url.absoluteString
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(keyCode, forKey: .keyCode)
        try container.encodeIfPresent(target, forKey: .target)
        try container.encode(isSecondary, forKey: .isSecondary)
    }
}

struct LauncherConfig: Codable, Equatable {
    /// No leader key means the launcher is disabled.
    var leaderKeyCode: UInt16?
    var timeoutMs: Int = 600
    var mappings: [LauncherMapping] = []

    func target(for keyCode: UInt16, secondary: Bool) -> String? {
        mappings.first { $0.keyCode == keyCode && $0.isSecondary == secondary }?.target
    }

    /// Orders the mapping table for display: primary set first, then by key
    /// display name, rows without a key last within their set.
    mutating func sortMappings() {
        mappings.sort { a, b in
            if a.isSecondary != b.isSecondary { return !a.isSecondary }
            switch (a.keyCode, b.keyCode) {
            case let (ka?, kb?): return KeyName.string(for: ka) < KeyName.string(for: kb)
            case (_?, nil):      return true
            default:             return false
            }
        }
    }
}

/// Persists LauncherConfig as JSON in UserDefaults and publishes changes so the
/// settings UI and the decoder both see edits immediately.
final class LauncherConfigStore: ObservableObject {
    private static let key = "launcherConfig"
    private let defaults: UserDefaults

    @Published var config: LauncherConfig {
        didSet { save() }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.key),
           let decoded = try? JSONDecoder().decode(LauncherConfig.self, from: data) {
            config = decoded
        } else {
            config = LauncherConfig()
        }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(config) else { return }
        defaults.set(data, forKey: Self.key)
    }
}
