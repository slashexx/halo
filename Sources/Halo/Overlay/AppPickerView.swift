import AppKit
import SwiftUI

/// What the user chose in the picker.
enum PickResult {
    case app(InstalledApp)
    case newWorkflow
}

/// A searchable list of installed apps with "New Workflow" pinned at the top.
/// Shown when the user clicks an empty slot (or Replace… on a filled one).
struct AppPickerView: View {
    let apps: [InstalledApp]
    var onPick: (PickResult) -> Void
    var onCancel: () -> Void

    @State private var query = ""

    private var filtered: [InstalledApp] {
        guard !query.isEmpty else { return apps }
        return apps.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search apps…", text: $query)
                    .textFieldStyle(.plain)
            }
            .padding(10)
            .background(.quaternary, in: .rect(cornerRadius: 8))
            .padding(12)

            List {
                Button {
                    onPick(.newWorkflow)
                } label: {
                    Label {
                        VStack(alignment: .leading, spacing: 1) {
                            Text("New Workflow").fontWeight(.semibold)
                            Text("Chain multiple actions — coming soon")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "square.stack.3d.up.fill")
                            .foregroundStyle(.tint)
                    }
                }
                .buttonStyle(.plain)

                Section("Applications") {
                    ForEach(filtered) { app in
                        Button {
                            onPick(.app(app))
                        } label: {
                            HStack(spacing: 10) {
                                Image(nsImage: NSWorkspace.shared.icon(forFile: app.path))
                                    .resizable().frame(width: 22, height: 22)
                                Text(app.name)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .listStyle(.inset)
        }
        .frame(width: 340, height: 460)
        .onExitCommand(perform: onCancel)
    }
}
