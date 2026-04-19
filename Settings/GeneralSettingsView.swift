import SwiftUI

/// Compact footer for the Settings window — holds app-level preferences
/// that don't belong inside the trigger list. Version / author info
/// lives in the About window and is intentionally not duplicated here.
struct GeneralSettingsView: View {
    @Environment(AppCoordinator.self) private var coordinator

    var body: some View {
        HStack {
            @Bindable var loginManager = coordinator.loginItemManager
            Toggle("Launch at Login", isOn: $loginManager.isEnabled)
                .toggleStyle(.switch)

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.bar)
    }
}
