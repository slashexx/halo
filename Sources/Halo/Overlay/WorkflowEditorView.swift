import AppKit
import SwiftUI

/// Builds/edits a workflow: a name plus an ordered list of steps that run in
/// sequence. Saves as a `.chain` action on a slot.
struct WorkflowEditorView: View {
    @State private var name: String
    @State private var steps: [WorkflowStep]
    var onSave: (String, [WorkflowStep]) -> Void
    var onCancel: () -> Void

    init(
        name: String,
        steps: [WorkflowStep],
        onSave: @escaping (String, [WorkflowStep]) -> Void,
        onCancel: @escaping () -> Void
    ) {
        _name = State(initialValue: name)
        _steps = State(initialValue: steps.isEmpty ? [WorkflowStep()] : steps)
        self.onSave = onSave
        self.onCancel = onCancel
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            stepList
            Divider()
            footer
        }
        .frame(width: 540, height: 580)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "square.stack.3d.up.fill")
                .font(.title2).foregroundStyle(.tint)
            TextField("Workflow name", text: $name)
                .textFieldStyle(.plain)
                .font(.title3.weight(.semibold))
        }
        .padding(16)
    }

    private var stepList: some View {
        List {
            ForEach($steps) { $step in
                StepRowView(step: $step)
                    .padding(.vertical, 4)
            }
            .onMove { steps.move(fromOffsets: $0, toOffset: $1) }
            .onDelete { steps.remove(atOffsets: $0) }
        }
        .listStyle(.inset)
    }

    private var footer: some View {
        HStack {
            Button {
                steps.append(WorkflowStep())
            } label: {
                Label("Add step", systemImage: "plus")
            }

            Spacer()

            Button("Cancel", action: onCancel)
                .keyboardShortcut(.cancelAction)
            Button("Save") { onSave(name, steps) }
                .keyboardShortcut(.defaultAction)
                .disabled(!canSave)
        }
        .padding(16)
    }
}

/// One editable step: type picker + the field(s) that type needs.
private struct StepRowView: View {
    @Binding var step: WorkflowStep

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("\u{2630}").foregroundStyle(.tertiary) // drag affordance
                Picker("", selection: $step.kind) {
                    ForEach(StepKind.allCases) { Text($0.title).tag($0) }
                }
                .labelsHidden()
                .frame(width: 190)
                Spacer()
            }

            field
        }
    }

    @ViewBuilder
    private var field: some View {
        switch step.kind {
        case .launchApp:
            AppChooserField(appName: $step.text)
        case .keyboardShortcut:
            ShortcutRecorder(combo: $step.combo, display: $step.shortcutDisplay)
        case .runAppleScript, .runShell:
            TextEditor(text: $step.text)
                .font(.system(.callout, design: .monospaced))
                .frame(height: 64)
                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(.quaternary))
        default:
            TextField(step.kind.placeholder, text: $step.text)
                .textFieldStyle(.roundedBorder)
        }
    }
}

/// Picks an installed app from a searchable popover list; stores the app name.
private struct AppChooserField: View {
    @Binding var appName: String

    @State private var apps: [InstalledApp] = []
    @State private var showing = false
    @State private var query = ""

    private var filtered: [InstalledApp] {
        guard !query.isEmpty else { return apps }
        return apps.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    private var selectedPath: String? {
        apps.first { $0.name == appName }?.path
    }

    var body: some View {
        Button {
            showing.toggle()
        } label: {
            HStack(spacing: 8) {
                if let path = selectedPath {
                    Image(nsImage: NSWorkspace.shared.icon(forFile: path))
                        .resizable().frame(width: 18, height: 18)
                }
                Text(appName.isEmpty ? "Choose app…" : appName)
                    .foregroundStyle(appName.isEmpty ? .secondary : .primary)
                Spacer()
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 8).padding(.vertical, 6)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .task { if apps.isEmpty { apps = InstalledApps.all() } }
        .popover(isPresented: $showing, arrowEdge: .bottom) {
            VStack(spacing: 0) {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("Search apps…", text: $query).textFieldStyle(.plain)
                }
                .padding(8)
                Divider()
                List(filtered) { app in
                    Button {
                        appName = app.name
                        showing = false
                    } label: {
                        HStack(spacing: 8) {
                            Image(nsImage: NSWorkspace.shared.icon(forFile: app.path))
                                .resizable().frame(width: 20, height: 20)
                            Text(app.name)
                            Spacer()
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .listStyle(.plain)
            }
            .frame(width: 260, height: 320)
        }
    }
}

/// Records a single key combo by capturing the next key-down while active.
private struct ShortcutRecorder: View {
    @Binding var combo: KeyCombo?
    @Binding var display: String

    @State private var recording = false
    @State private var monitor: Any?

    var body: some View {
        Button {
            recording ? stop() : start()
        } label: {
            HStack {
                Image(systemName: "keyboard")
                Text(recording ? "Press keys…" : (display.isEmpty ? "Record shortcut" : display))
                    .monospaced()
            }
        }
        .onDisappear(perform: stop)
    }

    private func start() {
        recording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            capture(event)
            return nil
        }
    }

    private func stop() {
        recording = false
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }

    private func capture(_ event: NSEvent) {
        var flags: CGEventFlags = []
        if event.modifierFlags.contains(.command) { flags.insert(.maskCommand) }
        if event.modifierFlags.contains(.shift) { flags.insert(.maskShift) }
        if event.modifierFlags.contains(.option) { flags.insert(.maskAlternate) }
        if event.modifierFlags.contains(.control) { flags.insert(.maskControl) }

        combo = KeyCombo(keyCode: CGKeyCode(event.keyCode), modifiers: flags)

        var label = ""
        if flags.contains(.maskControl) { label += "⌃" }
        if flags.contains(.maskAlternate) { label += "⌥" }
        if flags.contains(.maskShift) { label += "⇧" }
        if flags.contains(.maskCommand) { label += "⌘" }
        label += (event.charactersIgnoringModifiers ?? "").uppercased()
        display = label

        stop()
    }
}
