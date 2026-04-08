import SwiftUI

struct GeneralSettingsView: View {
    @Environment(AppCoordinator.self) private var coordinator

    var body: some View {
        Form {
            Section("Startup") {
                @Bindable var loginManager = coordinator.loginItemManager
                Toggle("Launch at Login", isOn: $loginManager.isEnabled)
            }

            Section("About") {
                LabeledContent("Version") {
                    Text(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0")
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}
