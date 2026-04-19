import SwiftUI

struct SettingsView: View {
    @Environment(AppCoordinator.self) private var coordinator

    var body: some View {
        VStack(spacing: 0) {
            MappingListView()
            Divider()
            GeneralSettingsView()
        }
        .frame(
            minWidth: 280, idealWidth: 435, maxWidth: .infinity,
            minHeight: 300, idealHeight: 332, maxHeight: .infinity
        )
        .environment(coordinator)
    }
}
