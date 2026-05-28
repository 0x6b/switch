import AppKit
import SwiftUI

struct SettingsView: View {
    @StateObject private var loginItem = LoginItem()

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Toggle("Launch at login", isOn: Binding(
                    get: { loginItem.enabled },
                    set: { loginItem.set($0) }
                ))
                if loginItem.requiresApproval {
                    Text("Open System Settings → General → Login Items to approve Switch.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)

            Divider()

            HStack {
                Spacer()
                Button("Quit Switch") {
                    NSApp.terminate(nil)
                }
                .keyboardShortcut("q", modifiers: [.command])
            }
            .padding(12)
        }
        .frame(width: 360)
        .background {
            // Accessory apps have no menu bar, so Cmd+W isn't wired by default.
            Button("Close") { NSApp.keyWindow?.performClose(nil) }
                .keyboardShortcut("w", modifiers: [.command])
                .hidden()
        }
        .onAppear { loginItem.refresh() }
    }
}
