import AppKit
import SwiftUI

/// First-run welcome + permissions. Requests Accessibility up front (the
/// umbrella grant for keystroke/text/media-key actions) and explains that
/// Automation is asked per-app on first use. Everything is skippable.
struct OnboardingView: View {
    var onDone: () -> Void

    @State private var hasAccessibility = Permissions.hasAccessibility
    @State private var launchAtLogin = LoginItem.isEnabled

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    trigger
                    accessibilityRow
                    automationRow
                    Toggle("Launch Halo at login", isOn: $launchAtLogin)
                        .onChange(of: launchAtLogin) { _, on in LoginItem.setEnabled(on) }
                }
                .padding(20)
            }
            Divider()
            HStack {
                Spacer()
                Button("Get Started", action: onDone)
                    .keyboardShortcut(.defaultAction)
                    .controlSize(.large)
            }
            .padding(16)
        }
        .frame(width: 500, height: 560)
        // Poll so the Accessibility row updates the moment the user grants it.
        .task {
            while !Task.isCancelled {
                hasAccessibility = Permissions.hasAccessibility
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable().frame(width: 76, height: 76)
            Text("Welcome to Halo").font(.title.bold())
            Text("Everything at your cursor. Press ⌥Tab anywhere to open the wheel.")
                .font(.callout).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 24).padding(.bottom, 18).padding(.horizontal, 20)
    }

    private var trigger: some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text("Open the wheel").fontWeight(.semibold)
                Text("Press ⌥Tab. Hover an item; the center flips to your now-playing media.")
                    .font(.callout).foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: "circle.hexagongrid.fill").foregroundStyle(.tint).font(.title2)
        }
    }

    private var accessibilityRow: some View {
        permissionRow(
            icon: "accessibility",
            title: "Accessibility",
            detail: "Lets Halo trigger keyboard shortcuts, insert text, and use media keys.",
            granted: hasAccessibility
        ) {
            if !hasAccessibility {
                Permissions.ensureAccessibility()
                Permissions.openAccessibilitySettings()
            }
        }
    }

    private var automationRow: some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text("Automation").fontWeight(.semibold)
                Text("Halo asks permission the first time it controls another app "
                    + "(Spotify, Music, your browser). Nothing to do now.")
                    .font(.callout).foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: "gearshape.2.fill").foregroundStyle(.tint).font(.title2)
        }
    }

    private func permissionRow(
        icon: String, title: String, detail: String,
        granted: Bool, action: @escaping () -> Void
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon).foregroundStyle(.tint).font(.title2).frame(width: 26)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).fontWeight(.semibold)
                Text(detail).font(.callout).foregroundStyle(.secondary)
            }
            Spacer()
            if granted {
                Label("Granted", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green).labelStyle(.iconOnly).font(.title2)
            } else {
                Button("Enable", action: action)
            }
        }
    }
}
