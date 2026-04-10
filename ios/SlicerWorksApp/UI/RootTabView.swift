import SwiftUI

struct RootTabView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        Group {
            if store.knownLANPrinters.isEmpty {
                PrinterSetupLandingView()
            } else {
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
                .tint(.blue)
                .toolbarBackground(Color.black.opacity(0.92), for: .tabBar)
                .toolbarBackground(.visible, for: .tabBar)
            }
        }
    }
}
