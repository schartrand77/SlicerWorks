import SwiftUI

@main
struct SlicerWorksApp: App {
    @StateObject private var appStore = AppStore()

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(appStore)
        }
    }
}
