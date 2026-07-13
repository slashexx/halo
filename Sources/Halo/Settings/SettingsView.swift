import SwiftUI

/// The Settings window: trigger gesture and where the menu appears. More
/// sections (clipboard size, launch at login, permissions) land here as those
/// features arrive.
struct SettingsView: View {
    @State private var gesture = AppSettings.gestureMode
    @State private var placement = AppSettings.placement
    @State private var clipboardDelay = AppSettings.clipboardHoverDelay

    var body: some View {
        Form {
            Section("Trigger") {
                Picker("Selection", selection: $gesture) {
                    ForEach(GestureMode.allCases) { Text($0.title).tag($0) }
                }
                .onChange(of: gesture) { _, newValue in AppSettings.gestureMode = newValue }

                LabeledContent("Shortcut", value: "⌥ Tab")
            }

            Section("Menu") {
                Picker("Open menu", selection: $placement) {
                    ForEach(OverlayPlacement.allCases) { Text($0.title).tag($0) }
                }
                .onChange(of: placement) { _, newValue in AppSettings.placement = newValue }
            }

            Section("Clipboard") {
                VStack(alignment: .leading) {
                    LabeledContent("Open after hover",
                                   value: String(format: "%.1f s", clipboardDelay))
                    Slider(value: $clipboardDelay, in: 0.2...1.5, step: 0.1)
                        .onChange(of: clipboardDelay) { _, newValue in
                            AppSettings.clipboardHoverDelay = newValue
                        }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 440, height: 260)
    }
}
