import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        TabView {
            MappingListView()
                .tabItem {
                    Label("Triggers", systemImage: "bolt.fill")
                }

            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gear")
                }
        }
        .frame(minWidth: 400, minHeight: 400)
        .environment(appState)
    }
}
