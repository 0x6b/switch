import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Settings tab for the leader-key launcher: leader key, timeout, and the
/// key → target mapping table. Targets are app bundle paths or URL strings
/// (e.g. "cleanshot://capture-window").
///
/// Built from custom cards instead of a grouped Form: the System Settings
/// table look (edge-to-edge row selection, +/- bar attached to the table)
/// is not achievable through Form/List row styling on macOS.
struct LauncherSettingsView: View {
    @ObservedObject var store: LauncherConfigStore
    @State private var selection: UUID?
    @State private var urlPromptShown = false
    @State private var scrollTarget: UUID?

    private var launcherEnabled: Bool {
        store.config.leaderKeyCode != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Launcher")
                .font(.headline)
            Text("Press the leader key, then a mapped key, to open that target. Press the leader twice to use the secondary set.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            SettingsCard {
                cardRow("Leader key") {
                    KeyRecorderField(keyCode: $store.config.leaderKeyCode)
                    if store.config.leaderKeyCode != nil {
                        Button("Clear") { store.config.leaderKeyCode = nil }
                    }
                }
                HStack {
                    Text(launcherEnabled
                        ? "Clearing the leader key disables the launcher."
                        : "Record a leader key to enable the launcher.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
                if launcherEnabled {
                    Divider().padding(.leading, 12).opacity(0.5)
                    cardRow("Timeout (ms)") {
                        TextField("", value: Binding(
                            get: { store.config.timeoutMs },
                            set: { store.config.timeoutMs = max(0, $0) }
                        ), format: .number)
                        .frame(width: 80)
                        .multilineTextAlignment(.trailing)
                    }
                }
            }

            if launcherEnabled {
                Text("Mappings")
                    .font(.headline)
                    .padding(.top, 8)

                mappingsTable
                    // Explicit height: the scroll view has no intrinsic size,
                    // and the window now sizes to fit the content.
                    .frame(height: 360)
            }
        }
        .sheet(isPresented: $urlPromptShown) {
            AddURLSheet { append(target: $0) }
        }
    }

    // MARK: - Mappings table

    /// Scrolling row list with the +/- bar attached to the card bottom,
    /// matching System Settings tables (e.g. Privacy & Security).
    private var mappingsTable: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach($store.config.mappings) { $mapping in
                            MappingRow(mapping: $mapping)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 9)
                                .frame(maxWidth: .infinity)
                                .background(
                                    selection == mapping.id
                                        ? Color(nsColor: .unemphasizedSelectedContentBackgroundColor)
                                        : .clear
                                )
                                .contentShape(Rectangle())
                                // Simultaneous so clicks landing on the key
                                // recorder or picker still select the row.
                                .simultaneousGesture(TapGesture().onEnded {
                                    selection = mapping.id
                                })
                                .id(mapping.id)
                            Divider().padding(.leading, 44).opacity(0.5)
                        }
                    }
                }
                .onChange(of: scrollTarget) { _, target in
                    guard let target else { return }
                    withAnimation { proxy.scrollTo(target) }
                    scrollTarget = nil
                }
            }

            Divider()

            addRemoveBar
        }
        .background(SettingsCardBackground())
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var addRemoveBar: some View {
        HStack(spacing: 0) {
            Menu {
                Button("Add App…") { addApp() }
                Button("Add URL…") { urlPromptShown = true }
            } label: {
                Image(systemName: "plus")
            }
            .menuIndicator(.hidden)
            .menuStyle(.borderlessButton)
            .frame(width: 24, height: 16)
            Divider().frame(height: 14)
            // A tap gesture, not a Button: after clicking a row the list
            // holds first responder, and the first click on a borderless
            // button is consumed shifting focus instead of acting.
            Image(systemName: "minus")
                .foregroundStyle(selection == nil ? .tertiary : .primary)
                .frame(width: 24, height: 16)
                .contentShape(Rectangle())
                .onTapGesture {
                    guard selection != nil else { return }
                    store.config.mappings.removeAll { $0.id == selection }
                    selection = nil
                }
            Spacer()
            if !duplicateKeyNames.isEmpty {
                Text("Duplicate key in the same set: \(duplicateKeyNames.joined(separator: ", ")). Only the first row is used.")
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .padding(.trailing, 8)
            }
        }
        .padding(4)
        // Layered over the card's own gray, so it reads darker than the rows.
        .background(Color.primary.opacity(0.06))
    }

    // MARK: - Top card

    private func cardRow<Content: View>(
        _ label: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack {
            Text(label)
            Spacer()
            content()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Actions

    private func addApp() {
        guard let url = chooseAppPanel(directory: nil) else { return }
        append(target: url.path)
    }

    private func append(target: String) {
        let mapping = LauncherMapping(target: target)
        store.config.mappings.append(mapping)
        selection = mapping.id
        scrollTarget = mapping.id
    }

    /// Key names that appear more than once within the same set.
    private var duplicateKeyNames: [String] {
        struct Slot: Hashable {
            let keyCode: UInt16
            let secondary: Bool
        }
        var seen = Set<Slot>(), duplicates = [UInt16]()
        for m in store.config.mappings {
            guard let key = m.keyCode else { continue }
            if !seen.insert(Slot(keyCode: key, secondary: m.isSecondary)).inserted {
                duplicates.append(key)
            }
        }
        return duplicates.map(KeyName.string(for:))
    }
}

/// Sheet instead of an alert: NSAlert-backed alerts don't honor FocusState,
/// so the text field couldn't receive focus automatically.
private struct AddURLSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @FocusState private var focused: Bool
    let onAdd: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Add URL")
                .font(.headline)
            TextField("cleanshot://capture-window", text: $text)
                .textFieldStyle(.roundedBorder)
                .focused($focused)
                .frame(width: 340)
                .onSubmit(add)
            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Add", action: add)
                    .keyboardShortcut(.defaultAction)
                    .disabled(trimmed.isEmpty)
            }
        }
        .padding(20)
        .onAppear { focused = true }
    }

    private var trimmed: String {
        text.trimmingCharacters(in: .whitespaces)
    }

    private func add() {
        guard !trimmed.isEmpty else { return }
        onAdd(trimmed)
        dismiss()
    }
}

private struct MappingRow: View {
    @Binding var mapping: LauncherMapping

    /// One classification per render; label and icon both derive from it.
    private enum Target {
        case app(URL, exists: Bool)
        case url(URL)
        case invalid(String)
        case empty

        init(_ target: String?) {
            guard let target else {
                self = .empty
                return
            }
            guard let url = LauncherTarget.url(from: target) else {
                self = .invalid(target)
                return
            }
            self = url.isFileURL
                ? .app(url, exists: FileManager.default.fileExists(atPath: url.path))
                : .url(url)
        }
    }

    var body: some View {
        let target = Target(mapping.target)
        HStack(spacing: 8) {
            ZStack { icon(for: target) }
                .frame(width: 24, height: 24)
            label(for: target)
                .lineLimit(1)
                .truncationMode(.middle)
                .help(mapping.target ?? "")
            Spacer()
            KeyRecorderField(keyCode: $mapping.keyCode)
            Picker("", selection: $mapping.isSecondary) {
                Text("Primary").tag(false)
                Text("Secondary").tag(true)
            }
            .labelsHidden()
            .fixedSize()
        }
    }

    @ViewBuilder
    private func label(for target: Target) -> some View {
        switch target {
        case .app(let url, _):
            Text(url.deletingPathExtension().lastPathComponent)
        case .url(let url):
            Text(url.absoluteString)
        case .invalid(let string):
            Text(string)
                .foregroundStyle(.red)
        case .empty:
            Text("No target")
                .foregroundStyle(.tertiary)
        }
    }

    @ViewBuilder
    private func icon(for target: Target) -> some View {
        switch target {
        case .app(let url, exists: true):
            Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                .resizable()
                .frame(width: 24, height: 24)
        case .app(_, exists: false):
            Image(systemName: "exclamationmark.triangle")
                .foregroundStyle(.red)
                .help("File not found")
        case .url:
            Image(systemName: "link")
                .foregroundStyle(.secondary)
        case .invalid:
            Image(systemName: "exclamationmark.triangle")
                .foregroundStyle(.red)
                .help("Not an app path or URL")
        case .empty:
            Image(systemName: "app.dashed")
                .foregroundStyle(.tertiary)
        }
    }
}

/// Modal .app picker; returns nil when cancelled.
private func chooseAppPanel(directory: URL?) -> URL? {
    let panel = NSOpenPanel()
    panel.allowedContentTypes = [.applicationBundle]
    panel.directoryURL = directory ?? URL(fileURLWithPath: "/Applications")
    panel.allowsMultipleSelection = false
    panel.canChooseDirectories = false
    return panel.runModal() == .OK ? panel.url : nil
}
