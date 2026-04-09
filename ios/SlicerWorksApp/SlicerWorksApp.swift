import SwiftUI

@main
struct SlicerWorksApp: App {
    @StateObject private var appStore = AppStore(environment: .live)

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(appStore)
                .task {
                    appStore.loadLastProject()
                }
        }
    }
}
