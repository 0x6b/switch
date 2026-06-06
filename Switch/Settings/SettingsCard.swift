import AppKit
import SwiftUI

/// Card fill mimicking System Settings sections: subtle gray over the
/// control background, no border.
struct SettingsCardBackground: View {
    var body: some View {
        ZStack {
            Color(nsColor: .controlBackgroundColor)
            Color.primary.opacity(0.05)
        }
    }
}

/// Rounded card mimicking System Settings sections; shared by the settings views.
struct SettingsCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) { content }
            .background(SettingsCardBackground())
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
