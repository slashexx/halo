import SwiftUI

/// The Settings window: trigger gesture and where the menu appears. More
/// sections (clipboard size, launch at login, permissions) land here as those
/// features arrive.
struct SettingsView: View {
    @State private var gesture = AppSettings.gestureMode
    @State private var placement = AppSettings.placement

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
        }
        .formStyle(.grouped)
        .frame(width: 440, height: 260)
    }
}
