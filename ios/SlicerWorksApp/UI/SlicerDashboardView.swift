import SwiftUI

struct SlicerDashboardView: View {
    @EnvironmentObject private var store: AppStore

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
                Button("Save project") {
                    store.saveActiveProject()
                }
                .disabled(store.sliceStatus.isWorking || store.uploadStatus.isWorking)

                Button("Slice now") {
                    Task { await store.prepareSlice() }
                }
                .disabled(store.sliceStatus.isWorking || store.uploadStatus.isWorking)

                Button("Upload to printer") {
                    Task { await store.pushLatestSliceToPrinter() }
                }
                .disabled(store.latestSliceResult == nil || store.sliceStatus.isWorking || store.uploadStatus.isWorking)
            }

            Section("Slice Status") {
                Text(store.sliceStatus.message)
                if let latestSliceResult = store.latestSliceResult {
                    Text("Time: \(latestSliceResult.estimatedPrintTimeMinutes) min")
                    Text("Material: \(latestSliceResult.estimatedFilamentGrams.formatted()) g")
                }
            }

            Section("Upload Status") {
                Text(store.uploadStatus.message)
            }

            Section("Project Status") {
                Text(store.projectStatus.message)
            }

            Section("Validation") {
                if store.projectValidationIssues.isEmpty {
                    Text("No validation issues")
                } else {
                    ForEach(store.projectValidationIssues) { issue in
                        Text(issue.message)
                    }
                }
            }
        }
        .navigationTitle("SlicerWorks")
    }
}
