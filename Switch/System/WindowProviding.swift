import Foundation

protocol WindowProviding {
    func snapshot(mode: SwitcherMode) -> [WindowEntry]
}
