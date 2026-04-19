import AppKit
import SwiftUI

struct PermissionGuideView: View {
    @Environment(AppCoordinator.self) private var coordinator
    var onGetStarted: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Text("How to Use QuickOpen")
                .font(.title2)
                .fontWeight(.semibold)

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

            OnboardingProgressView(
                accessibilityGranted: coordinator.permissionManager.accessibilityGranted,
                automationGranted: coordinator.permissionManager.automationGranted
            )
            .padding(.horizontal, 12)

            VStack(spacing: 10) {
                PermissionCardView(
                    icon: "accessibility",
                    title: "Accessibility",
                    description: "Required to detect global shortcuts and mouse/trackpad events",
                    granted: coordinator.permissionManager.accessibilityGranted,
                    primaryAction: { coordinator.permissionManager.requestAccessibilityPermission() },
                    fallbackAction: { coordinator.permissionManager.openAccessibilitySettings() }
                )
                PermissionCardView(
                    icon: "gearshape.2.fill",
                    title: "Automation (Finder)",
                    description: "Required to communicate with Finder to get selected files",
                    granted: coordinator.permissionManager.automationGranted,
                    primaryAction: { coordinator.permissionManager.requestAutomationPermission() },
                    fallbackAction: { coordinator.permissionManager.openAutomationSettings() }
                )
            }

            if coordinator.state.setupCompleted {
                Button("Close") { onGetStarted() }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .keyboardShortcut(.defaultAction)
            } else {
                Button("Get Started") { onGetStarted() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(!coordinator.permissionManager.allPermissionsGranted)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 440)
        .onAppear {
            coordinator.permissionManager.checkPermissions()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            coordinator.permissionManager.checkPermissions()
        }
    }
}

// MARK: - Subviews (public)

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

// MARK: - Onboarding progress

fileprivate struct OnboardingProgressView: View {
    let accessibilityGranted: Bool
    let automationGranted: Bool

    private var currentStep: Int {
        if !accessibilityGranted { return 0 }
        if !automationGranted { return 1 }
        return 2 // all done
    }

    var body: some View {
        HStack(spacing: 0) {
            StepDot(
                number: 1,
                title: "Accessibility",
                completed: accessibilityGranted,
                isCurrent: currentStep == 0
            )
            connector(active: accessibilityGranted)
            StepDot(
                number: 2,
                title: "Automation",
                completed: automationGranted,
                isCurrent: currentStep == 1
            )
        }
    }

    private func connector(active: Bool) -> some View {
        Rectangle()
            .fill(active ? Color.green : Color.secondary.opacity(0.3))
            .frame(height: 2)
            .frame(maxWidth: .infinity)
            .padding(.bottom, 22) // vertical-center against the dot (not the label)
            .animation(.easeInOut(duration: 0.3), value: active)
    }
}

fileprivate struct StepDot: View {
    let number: Int
    let title: String
    let completed: Bool
    let isCurrent: Bool

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(backgroundColor)
                if completed {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                } else {
                    Text("\(number)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(isCurrent ? .white : .secondary)
                }
            }
            .frame(width: 24, height: 24)
            .overlay(
                Circle()
                    .stroke(Color.accentColor.opacity(isCurrent ? 0.35 : 0), lineWidth: 4)
            )
            .animation(.easeInOut(duration: 0.25), value: completed)

            Text(title)
                .font(.caption)
                .foregroundStyle(isCurrent ? .primary : .secondary)
        }
    }

    private var backgroundColor: Color {
        if completed { return .green }
        if isCurrent { return .accentColor }
        return Color.secondary.opacity(0.3)
    }
}

// MARK: - Permission card

fileprivate struct PermissionCardView: View {
    let icon: String
    let title: String
    let description: String
    let granted: Bool
    let primaryAction: () -> Void
    let fallbackAction: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            iconBadge
                .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(title)
                        .font(.headline)
                    Spacer()
                    StatusBadge(granted: granted)
                }
                Text(granted ? "Permission granted" : description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if !granted {
                    HStack(spacing: 10) {
                        // Custom style keeps the accent fill + white text
                        // regardless of window focus. .borderedProminent
                        // fades so aggressively when the window deactivates
                        // that the button effectively disappears.
                        Button(action: primaryAction) {
                            Label("Grant Access", systemImage: "arrow.up.forward.square")
                        }
                        .buttonStyle(AccentFillButtonStyle())

                        Button("Open Settings", action: fallbackAction)
                            .buttonStyle(.link)
                            .controlSize(.small)
                    }
                    .padding(.top, 4)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.secondary.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(borderColor, lineWidth: 1)
        )
        .animation(.easeInOut(duration: 0.25), value: granted)
    }

    private var iconBadge: some View {
        ZStack {
            Circle().fill(iconBackgroundColor)
            Image(systemName: granted ? "checkmark.circle.fill" : icon)
                .font(.system(size: 22, weight: .regular))
                .foregroundStyle(iconForegroundColor)
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.6), value: granted)
    }

    private var iconBackgroundColor: Color {
        (granted ? Color.green : Color.orange).opacity(0.15)
    }

    private var iconForegroundColor: Color {
        granted ? .green : .orange
    }

    private var borderColor: Color {
        (granted ? Color.green : Color.orange).opacity(0.3)
    }
}

fileprivate struct StatusBadge: View {
    let granted: Bool

    var body: some View {
        Text(granted ? "Granted" : "Required")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(granted ? .green : .orange)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(
                Capsule().fill((granted ? Color.green : Color.orange).opacity(0.15))
            )
    }
}

/// Solid-accent button style that does not dim when the window loses focus,
/// unlike `.borderedProminent` which fades aggressively. Matches the visual
/// weight of the default-action Close/Get Started button.
fileprivate struct AccentFillButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(Color.accentColor)
                    .opacity(configuration.isPressed ? 0.7 : 1.0)
            )
    }
}
