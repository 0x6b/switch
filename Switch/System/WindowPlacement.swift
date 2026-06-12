import AppKit
import ApplicationServices

/// Window placement actions, ported from Rectangle's execute-action set.
enum PlacementAction: Equatable {
    case leftHalf
    case rightHalf
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight
    case center
    case nextDisplay
}

/// Tracks repeated invocations so the size can cycle. A repeat means: same
/// window, same action, and the window frame is still exactly what the last
/// placement produced (so moving the window by hand restarts the cycle).
struct PlacementCycle {
    private struct Last: Equatable {
        let windowID: CGWindowID
        let action: PlacementAction
        let step: Int
        let frame: CGRect
    }
    private var last: Last?

    /// The cycle step for this invocation: one past the previous step on a
    /// repeat, otherwise 0.
    func step(windowID: CGWindowID?, action: PlacementAction, currentFrame: CGRect) -> Int {
        guard let windowID, let last,
              last.windowID == windowID, last.action == action, last.frame == currentFrame
        else { return 0 }
        return (last.step + 1) % WindowPlacement.cycleFractions.count
    }

    /// Records the frame the window actually ended up with, which can differ
    /// from the requested one (e.g. terminals snap to their character grid).
    mutating func record(windowID: CGWindowID?, action: PlacementAction, step: Int, frame: CGRect) {
        last = windowID.map { Last(windowID: $0, action: action, step: step, frame: frame) }
    }
}

enum WindowPlacement {
    /// Width fractions a repeated half/corner command cycles through.
    static let cycleFractions: [CGFloat] = [1.0 / 2, 2.0 / 3, 1.0 / 4, 1.0 / 3]

    /// Computes the new window frame for an action. All rects share one
    /// coordinate space with a top-left origin (the AX convention: y grows
    /// downward, so the top edge of a screen is its minY).
    /// `step` indexes `cycleFractions` for the width of halves and corners;
    /// center and nextDisplay ignore it.
    /// Returns nil when there is nothing to do (nextDisplay on a single display).
    static func targetFrame(
        for action: PlacementAction,
        window: CGRect,
        visibleFrame vf: CGRect,
        nextVisibleFrame: CGRect?,
        step: Int = 0
    ) -> CGRect? {
        let width = floor(vf.width * cycleFractions[step % cycleFractions.count])
        let halfH = floor(vf.height / 2)
        return switch action {
        case .leftHalf:    CGRect(x: vf.minX, y: vf.minY, width: width, height: vf.height)
        case .rightHalf:   CGRect(x: vf.maxX - width, y: vf.minY, width: width, height: vf.height)
        case .topLeft:     CGRect(x: vf.minX, y: vf.minY, width: width, height: halfH)
        case .topRight:    CGRect(x: vf.maxX - width, y: vf.minY, width: width, height: halfH)
        case .bottomLeft:  CGRect(x: vf.minX, y: vf.maxY - halfH, width: width, height: halfH)
        case .bottomRight: CGRect(x: vf.maxX - width, y: vf.maxY - halfH, width: width, height: halfH)
        case .center:      centered(size: window.size, in: vf)
        case .nextDisplay: nextVisibleFrame.map { centered(size: window.size, in: $0) }
        }
    }

    /// Moves/resizes the window for the given action, relative to the screen
    /// the window currently occupies. Repeating the same action on the same
    /// window advances `cycle` through `cycleFractions`.
    static func apply(_ action: PlacementAction, to window: AXUIElement, cycle: inout PlacementCycle) {
        guard let frame = window.frame() else { return }
        let screens = NSScreen.screens
        guard let primary = screens.first else { return }
        // AppKit frames have a bottom-left origin; flip to AX coordinates
        // (top-left origin) around the primary screen's top edge.
        let visibleFrames = screens.map { screen in
            let vf = screen.visibleFrame
            return CGRect(x: vf.minX, y: primary.frame.maxY - vf.maxY, width: vf.width, height: vf.height)
        }

        // The window's screen is the one it overlaps most; default to the first.
        let index = visibleFrames.indices.max(by: {
            overlapArea(visibleFrames[$0], frame) < overlapArea(visibleFrames[$1], frame)
        }) ?? 0
        let next = visibleFrames.count > 1 ? visibleFrames[(index + 1) % visibleFrames.count] : nil

        let windowID = window.windowID()
        let step = cycle.step(windowID: windowID, action: action, currentFrame: frame)
        guard let target = targetFrame(
            for: action, window: frame, visibleFrame: visibleFrames[index],
            nextVisibleFrame: next, step: step
        ) else { return }
        window.setFrame(target)
        if let result = window.frame() {
            cycle.record(windowID: windowID, action: action, step: step, frame: result)
        }
    }

    // MARK: - Private

    /// Centers a window of the given size, clamping to the visible frame when
    /// it doesn't fit.
    private static func centered(size: CGSize, in vf: CGRect) -> CGRect {
        let width = min(size.width, vf.width)
        let height = min(size.height, vf.height)
        return CGRect(
            x: vf.minX + ((vf.width - width) / 2).rounded(),
            y: vf.minY + ((vf.height - height) / 2).rounded(),
            width: width,
            height: height
        )
    }

    private static func overlapArea(_ a: CGRect, _ b: CGRect) -> CGFloat {
        let i = a.intersection(b)
        return i.isNull ? 0 : i.width * i.height
    }
}
