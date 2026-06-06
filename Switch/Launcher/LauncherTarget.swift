import Foundation

/// Resolves a mapping target string to an openable URL.
/// "/path" and "~/path" become file URLs; anything with a scheme
/// ("cleanshot://…") becomes a regular URL; everything else is rejected.
enum LauncherTarget {
    static func url(from target: String) -> URL? {
        let trimmed = target.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        if trimmed.hasPrefix("/") {
            return URL(fileURLWithPath: trimmed)
        }
        if trimmed.hasPrefix("~") {
            return URL(fileURLWithPath: NSString(string: trimmed).expandingTildeInPath)
        }
        guard let url = URL(string: trimmed), url.scheme != nil else { return nil }
        return url
    }
}
