import AppKit
import SwiftUI

struct SettingsView: View {
    @StateObject private var loginItem = LoginItem()
    @ObservedObject var launcherStore: LauncherConfigStore

    private static let versionString: String = {
        let short = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        return "Version \(short)"
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(spacing: 6) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 96, height: 96)
                Link("github.com/0x6b/switch", destination: URL(string: "https://github.com/0x6b/switch")!)
                    .font(.footnote)
                Text(Self.versionString)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 16)
            .padding(.bottom, 12)

            SettingsCard {
                HStack {
                    Text("Launch at login")
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { loginItem.enabled },
                        set: { loginItem.set($0) }
                    ))
                    .labelsHidden()
                    .toggleStyle(.switch)
                    // System Settings switches are the small control size.
                    .controlSize(.small)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

                Divider().padding(.leading, 12).opacity(0.5)

                HStack {
                    Text("Quit Switch")
                    Spacer()
                    Button("Quit") {
                        NSApp.terminate(nil)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            if loginItem.requiresApproval {
                Text("Open System Settings → General → Login Items to approve Switch.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
            }

            LauncherSettingsView(store: launcherStore)
                .padding(.top, 12)
        }
        .padding(16)
        // Width only: the height follows the content, so the window shrinks
        // while the launcher is disabled and grows when the table appears.
        .frame(width: 480)
        .background(Color(nsColor: .controlBackgroundColor))
        .background {
            // Accessory apps have no menu bar, so Cmd+W/Cmd+Q aren't wired by
            // default. Hidden buttons supply the shortcuts.
            Button("Close") { NSApp.keyWindow?.performClose(nil) }
                .keyboardShortcut("w", modifiers: [.command])
                .hidden()
            Button("Quit") { NSApp.terminate(nil) }
                .keyboardShortcut("q", modifiers: [.command])
                .hidden()
        }
        .onAppear { loginItem.refresh() }
    }
}
