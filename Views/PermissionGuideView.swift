import SwiftUI

struct PermissionGuideView: View {
    @Environment(AppState.self) private var appState
    var onGetStarted: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 12) {
                Image(systemName: "folder.badge.gearshape")
                    .font(.system(size: 56))
                    .foregroundStyle(.blue)

                Text("QuickOpen")
                    .font(.title)
                    .fontWeight(.bold)

                Text("Version \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0")")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                Text("Developed by oh-research")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                Link("github.com/oh-research/QuickOpen",
                     destination: URL(string: "https://github.com/oh-research/QuickOpen")!)
                    .font(.caption)
            }

            Divider()

            // How to use
            GroupBox("How to use") {
                VStack(alignment: .leading, spacing: 10) {
                    HowToRow(
                        icon: "keyboard",
                        text: "Set a keyboard shortcut to open files with your favorite app"
                    )
                    HowToRow(
                        icon: "computermouse",
                        text: "Use modifier + click to open files in a different app"
                    )
                    HowToRow(
                        icon: "hand.point.up",
                        text: "Use modifier + Force Click for trackpad gestures"
                    )
                    HowToRow(
                        icon: "gearshape",
                        text: "Configure triggers from the menu bar icon"
                    )
                }
                .padding(.vertical, 4)
            }

            // Permissions
            GroupBox("Permissions") {
                VStack(spacing: 12) {
                    PermissionRow(
                        granted: appState.permissionManager.accessibilityGranted,
                        title: "Accessibility",
                        description: "Required to detect global shortcuts and mouse/trackpad events",
                        action: { appState.permissionManager.requestAccessibility() }
                    )

                    Divider()

                    PermissionRow(
                        granted: appState.permissionManager.automationGranted,
                        title: "Automation (Finder)",
                        description: "Required to communicate with Finder to get selected files",
                        action: { appState.permissionManager.openAutomationSettings() }
                    )
                }
                .padding(.vertical, 4)
            }

            // Get Started
            Button(appState.setupCompleted ? "Close" : "Get Started") {
                onGetStarted()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!appState.permissionManager.allPermissionsGranted)
        }
        .padding(24)
        .frame(width: 420)
        .onAppear {
            appState.permissionManager.checkPermissions()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            appState.permissionManager.checkPermissions()
        }
    }
}

// MARK: - Subviews

struct PermissionRow: View {
    let granted: Bool
    let title: String
    let description: String
    let action: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: granted ? "checkmark.shield.fill" : "shield.lefthalf.filled")
                .font(.title2)
                .foregroundStyle(granted ? .green : .orange)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.bold())
                Text(granted ? "Permission granted" : description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if !granted {
                Button("Grant Access") { action() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            }
        }
    }
}

struct HowToRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .frame(width: 24)
                .foregroundStyle(.blue)
            Text(text)
                .font(.subheadline)
        }
    }
}
