import SwiftUI

struct PermissionGuideView: View {
    @Environment(AppCoordinator.self) private var coordinator
    var onGetStarted: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Text("How to Use QuickOpen")
                .font(.title2)
                .fontWeight(.semibold)

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
                        granted: coordinator.permissionManager.accessibilityGranted,
                        title: "Accessibility",
                        description: "Required to detect global shortcuts and mouse/trackpad events",
                        action: { coordinator.permissionManager.requestAccessibility() }
                    )

                    Divider()

                    PermissionRow(
                        granted: coordinator.permissionManager.automationGranted,
                        title: "Automation (Finder)",
                        description: "Required to communicate with Finder to get selected files",
                        action: { coordinator.permissionManager.openAutomationSettings() }
                    )
                }
                .padding(.vertical, 4)
            }

            // Get Started
            Button(coordinator.state.setupCompleted ? "Close" : "Get Started") {
                onGetStarted()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!coordinator.permissionManager.allPermissionsGranted)
        }
        .padding(24)
        .frame(width: 420)
        .onAppear {
            coordinator.permissionManager.checkPermissions()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            coordinator.permissionManager.checkPermissions()
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
