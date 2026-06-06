import Foundation

/// Leader-key launcher state machine, ported from app-activate. Press the
/// leader key, then a mapped key within the timeout, to launch that app.
/// Double-tap the leader to toggle to the secondary mapping set.
///
/// The deadline is checked lazily when the next key arrives — a stale awaiting
/// state has no observable effect until then, so no timer is needed.
final class LauncherDecoder {
    enum Action: Equatable {
        case passthrough
        case consume
        case launch(String)
    }

    private enum State {
        case waiting
        case awaiting(deadline: Date, secondary: Bool)
    }

    private var state: State = .waiting
    private let configProvider: () -> LauncherConfig

    init(configProvider: @escaping () -> LauncherConfig) {
        self.configProvider = configProvider
    }

    func handleKeyDown(keyCode: UInt16, hasModifiers: Bool, now: Date) -> Action {
        let config = configProvider()
        guard let leader = config.leaderKeyCode else {
            state = .waiting
            return .passthrough
        }
        if hasModifiers {
            state = .waiting
            return .passthrough
        }

        // Expired sequence behaves exactly like the waiting state.
        if case .awaiting(let deadline, _) = state, now > deadline {
            state = .waiting
        }

        switch state {
        case .waiting:
            guard keyCode == leader else { return .passthrough }
            state = .awaiting(deadline: now + timeout(config), secondary: false)
            return .consume

        case .awaiting(_, let secondary):
            if keyCode == leader {
                state = .awaiting(deadline: now + timeout(config), secondary: !secondary)
                return .consume
            }
            state = .waiting
            guard let target = config.target(for: keyCode, secondary: secondary) else {
                return .passthrough
            }
            return .launch(target)
        }
    }

    private func timeout(_ config: LauncherConfig) -> TimeInterval {
        TimeInterval(config.timeoutMs) / 1000
    }
}
