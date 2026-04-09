import SwiftUI

struct SlicerDashboardView: View {
    @EnvironmentObject private var store: AppStore
    @State private var latestSliceResult: SliceResult?
    @State private var status: String = "Ready"

    var body: some View {
        Form {
            Section("Printer") {
                Picker("Profile", selection: $store.selectedPrinter) {
                    ForEach(BambuPrinterProfile.allCases) { printer in
                        Text(printer.displayName).tag(printer)
                    }
                }
                .pickerStyle(.navigationLink)

                let volume = store.selectedPrinter.buildVolumeMM
                Text("Build volume: \(volume.x) × \(volume.y) × \(volume.z) mm")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Project") {
                TextField("Name", text: $store.activeProject.name)
                Stepper("Layer height: \(store.activeProject.layerHeightMM.formatted()) mm", value: $store.activeProject.layerHeightMM, in: 0.08...0.32, step: 0.04)
                Stepper("Infill: \(store.activeProject.infillPercent)%", value: $store.activeProject.infillPercent, in: 0...100, step: 5)
            }

            Section("Actions") {
                Button("Slice now") {
                    Task {
                        do {
                            latestSliceResult = try await store.prepareSlice()
                            status = "Sliced successfully"
                        } catch {
                            status = "Slice failed: \(error.localizedDescription)"
                        }
                    }
                }

                Button("Upload to printer") {
                    Task {
                        guard let latestSliceResult else {
                            status = "Slice first"
                            return
                        }

                        do {
                            try await store.pushToPrinter(latestSliceResult)
                            status = "Upload queued"
                        } catch {
                            status = "Upload failed: \(error.localizedDescription)"
                        }
                    }
                }
                .disabled(latestSliceResult == nil)
            }

            Section("Status") {
                Text(status)
                if let latestSliceResult {
                    Text("Time: \(latestSliceResult.estimatedPrintTimeMinutes) min")
                    Text("Material: \(latestSliceResult.estimatedFilamentGrams.formatted()) g")
                }
            }
        }
        .navigationTitle("SlicerWorks")
    }
}
