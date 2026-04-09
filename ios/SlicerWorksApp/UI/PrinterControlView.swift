import SwiftUI

struct PrinterControlView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        List {
            Section("Bambu Lab") {
                Label("LAN discovery", systemImage: "dot.radiowaves.left.and.right")
                Label("Cloud queue (future)", systemImage: "icloud")
                Label("AMS filament sync", systemImage: "square.stack.3d.up")
            }

            Section("Selected") {
                Text(store.selectedPrinter.displayName)
            }
        }
        .navigationTitle("Printers")
    }
}
