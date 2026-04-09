import SwiftUI

struct RootTabView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        TabView {
            NavigationStack {
                SlicerDashboardView()
            }
            .tabItem {
                Label("Slice", systemImage: "cube")
            }

            NavigationStack {
                ModelPaintingView()
            }
            .tabItem {
                Label("Paint", systemImage: "paintbrush")
            }

            NavigationStack {
                PrinterControlView()
            }
            .tabItem {
                Label("Devices", systemImage: "wifi")
            }
        }
    }
}
