import AppKit
import Carbon.HIToolbox
import SwiftUI

/// Button that records a single key press. Click to arm, press a key to store
/// its keyCode. Escape cancels without changing the binding.
struct KeyRecorderField: View {
    @Binding var keyCode: UInt16?
    @State private var recording = false
    @State private var monitor: Any?

    var body: some View {
        Button(label) {
            recording ? stopRecording() : startRecording()
        }
        .onDisappear { stopRecording() }
    }

    private var label: String {
        if recording { return "Press a key…" }
        return keyCode.map(KeyName.string(for:)) ?? "Record Key"
    }

    private func startRecording() {
        recording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if Int(event.keyCode) != kVK_Escape {
                keyCode = event.keyCode
            }
            stopRecording()
            return nil // swallow the recorded keystroke
        }
    }

    private func stopRecording() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        recording = false
    }
}
