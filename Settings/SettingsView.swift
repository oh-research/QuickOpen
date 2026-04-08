import SwiftUI

struct SettingsView: View {
    @Environment(AppCoordinator.self) private var coordinator

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
        .environment(coordinator)
    }
}
