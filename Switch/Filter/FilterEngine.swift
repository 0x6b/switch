import Foundation

enum FilterEngine {
    static func matches(haystack: String, filter: String) -> Bool {
        let tokens = filter.split(whereSeparator: \.isWhitespace).map { $0.fold() }
        guard !tokens.isEmpty else { return true }
        let folded = haystack.fold()
        return tokens.allSatisfy(folded.contains)
    }
}

private extension StringProtocol {
    func fold() -> String {
        String(self).folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
    }
}
