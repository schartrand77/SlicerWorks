import SwiftUI

struct SlicerDashboardView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        ViewThatFits(in: .horizontal) {
            editorLayout
            compactLayout
        }
        .navigationTitle("Slicer")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(red: 0.95, green: 0.95, blue: 0.93))
    }

    private var editorLayout: some View {
        HStack(spacing: 16) {
            workspaceSidebar
                .frame(width: 260)

            centerWorkspace

            inspectorSidebar
                .frame(width: 320)
        }
        .padding(16)
    }

    private var compactLayout: some View {
        ScrollView {
            VStack(spacing: 16) {
                centerWorkspace
                    .frame(height: 440)
                workspaceSidebar
                inspectorSidebar
            }
            .padding(16)
        }
    }

    private var workspaceSidebar: some View {
        VStack(alignment: .leading, spacing: 16) {
            panelHeader(title: "Workspace", subtitle: store.selectedPrinter.displayName)

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Build Plates")
                        .font(.headline)
                    Spacer()
                    Button {
                        store.addPlate()
                    } label: {
                        Label("Add plate", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }

                ForEach(store.activeProject.plates) { plate in
                    Button {
                        store.selectedPlateID = plate.id
                        store.selectedModelID = plate.models.first?.id
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(plate.name)
                                    .font(.headline)
                                Text("\(plate.models.count) model\(plate.models.count == 1 ? "" : "s")")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if store.selectedPlateID == plate.id {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.orange)
                            }
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(store.selectedPlateID == plate.id ? Color.orange.opacity(0.15) : Color.white.opacity(0.9), in: RoundedRectangle(cornerRadius: 16))
                    }
                    .buttonStyle(.plain)
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Models")
                        .font(.headline)
                    Spacer()
                    Button {
                        store.addSampleModel()
                    } label: {
                        Label("Add model", systemImage: "square.stack.badge.plus")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                if let selectedPlate = store.selectedPlate, selectedPlate.models.isEmpty == false {
                    ForEach(selectedPlate.models) { model in
                        Button {
                            store.selectModel(model.id)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(model.name)
                                    .font(.headline)
                                Text(model.sourceURL.lastPathComponent)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text("Scale \(model.scalePercent)% • Rot \(Int(model.rotationDegrees)) deg")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text("Surface marks \(store.paintingStrokeCount(for: model.id))")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(store.selectedModelID == model.id ? Color.orange.opacity(0.18) : Color.white.opacity(0.9), in: RoundedRectangle(cornerRadius: 16))
                        }
                        .buttonStyle(.plain)
                    }
                } else {
                    Text("No models on this plate yet.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.white.opacity(0.9), in: RoundedRectangle(cornerRadius: 16))
                }
            }

            if let selectedModel = store.selectedModel {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Selection")
                        .font(.headline)
                    Text(selectedModel.name)
                        .font(.subheadline.weight(.semibold))
                    Text("X \(Int(selectedModel.position.x)) • Y \(Int(selectedModel.position.y))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("Paint and model edits require Apple Pencil in the Paint workspace.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white.opacity(0.9), in: RoundedRectangle(cornerRadius: 16))
            }

            Spacer()
        }
        .padding(16)
        .background(Color(red: 0.90, green: 0.91, blue: 0.88), in: RoundedRectangle(cornerRadius: 24))
    }

    private var centerWorkspace: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(store.activeProject.name)
                        .font(.title2.weight(.semibold))
                    Text("Touch selects and inspects. Apple Pencil handles model edits.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Label("\(store.activeProject.allModels.count) total model\(store.activeProject.allModels.count == 1 ? "" : "s")", systemImage: "cube.transparent")
                    .font(.subheadline.weight(.medium))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.9), in: Capsule())
            }

            plateWorkspace
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var plateWorkspace: some View {
        GeometryReader { geometry in
            ZStack {
                RoundedRectangle(cornerRadius: 28)
                    .fill(Color(red: 0.84, green: 0.85, blue: 0.80))

                WorkspaceGrid()
                    .clipShape(RoundedRectangle(cornerRadius: 28))

                RoundedRectangle(cornerRadius: 24)
                    .stroke(Color.black.opacity(0.12), lineWidth: 1)
                    .padding(24)

                if let plate = store.selectedPlate {
                    workspaceOverlay(for: plate)

                    ForEach(Array(plate.models.enumerated()), id: \.element.id) { index, model in
                        plateModelCard(model: model, index: index, size: geometry.size)
                    }
                } else {
                    VStack(spacing: 10) {
                        Image(systemName: "square.grid.3x3.middle.filled")
                            .font(.system(size: 38))
                        Text("Add a build plate to begin arranging parts.")
                            .font(.headline)
                        Text("Plates stay outside the canvas. The workspace stays clear.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                store.selectModel(nil)
            }
        }
        .frame(minHeight: 560)
        .shadow(color: .black.opacity(0.08), radius: 20, y: 10)
    }

    private var inspectorSidebar: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                panelHeader(title: "Slice Setup", subtitle: "Outside menus only")

                VStack(alignment: .leading, spacing: 10) {
                    TextField("Project name", text: $store.activeProject.name)
                        .textFieldStyle(.roundedBorder)

                    Text("Quality")
                        .font(.headline)
                    Picker("Quality", selection: $store.activeProject.sliceSettings.qualityPreset) {
                        ForEach(SliceQualityPreset.allCases) { preset in
                            Text(preset.displayName).tag(preset)
                        }
                    }
                    .pickerStyle(.segmented)

                    Picker("Material", selection: $store.activeProject.sliceSettings.filamentMaterial) {
                        ForEach(FilamentMaterial.allCases) { material in
                            Text(material.displayName).tag(material)
                        }
                    }

                    Button("Apply recommended printer preset") {
                        store.applyRecommendedSettings()
                    }
                    .buttonStyle(.borderedProminent)
                }

                if let selectedModel = store.selectedModel {
                    inspectorGroup(title: "Selected Model") {
                        Text(selectedModel.name)
                            .font(.headline)
                        Text(selectedModel.sourceURL.lastPathComponent)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("Position \(Int(selectedModel.position.x)), \(Int(selectedModel.position.y))")
                        Text("Rotation \(Int(selectedModel.rotationDegrees)) deg")
                        Text("Scale \(selectedModel.scalePercent)%")
                        Text("Surface paint regions \(store.paintingStrokeCount(for: selectedModel.id))")
                        Text("Editing is Pencil-only in Paint to keep touch gestures separate from model changes.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                inspectorGroup(title: "Color Plan") {
                    colorPlanRow(title: "Surface", color: store.activeProject.sliceSettings.surfaceColor)
                    colorPlanRow(title: "Infill", color: store.activeProject.sliceSettings.infillColor)
                    Text("Surface color can be painted with Apple Pencil. Infill color is explicit and never painted by touch or hover interactions.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                inspectorGroup(title: "Shell and Infill") {
                    Stepper("Layer \(store.activeProject.sliceSettings.layerHeightMM.formatted(.number.precision(.fractionLength(2)))) mm", value: $store.activeProject.sliceSettings.layerHeightMM, in: store.selectedPrinter.minimumLayerHeightMM...store.selectedPrinter.maximumLayerHeightMM, step: 0.04)
                    Stepper("Walls \(store.activeProject.sliceSettings.wallLoopCount)", value: $store.activeProject.sliceSettings.wallLoopCount, in: 1...8)
                    Stepper("Infill \(store.activeProject.sliceSettings.infillPercent)%", value: $store.activeProject.sliceSettings.infillPercent, in: 0...100, step: 5)

                    Picker("Pattern", selection: $store.activeProject.sliceSettings.infillPattern) {
                        ForEach(InfillPattern.allCases) { pattern in
                            Text(pattern.displayName).tag(pattern)
                        }
                    }
                }

                inspectorGroup(title: "Thermals and Support") {
                    Stepper("Speed \(store.activeProject.sliceSettings.printSpeedMMPerSecond) mm/s", value: $store.activeProject.sliceSettings.printSpeedMMPerSecond, in: 30...store.selectedPrinter.maximumPrintSpeedMMPerSecond, step: 10)
                    Stepper("Nozzle \(store.activeProject.sliceSettings.nozzleTemperatureC) C", value: $store.activeProject.sliceSettings.nozzleTemperatureC, in: 180...300, step: 5)
                    Stepper("Bed \(store.activeProject.sliceSettings.bedTemperatureC) C", value: $store.activeProject.sliceSettings.bedTemperatureC, in: 0...110, step: 5)

                    Picker("Supports", selection: $store.activeProject.sliceSettings.supportStyle) {
                        ForEach(SupportStyle.allCases) { style in
                            Text(style.displayName).tag(style)
                        }
                    }

                    Picker("Adhesion", selection: $store.activeProject.sliceSettings.adhesionType) {
                        ForEach(AdhesionType.allCases) { adhesion in
                            Text(adhesion.displayName).tag(adhesion)
                        }
                    }
                }

                inspectorGroup(title: "Actions") {
                    Button("Save project") {
                        store.saveActiveProject()
                    }
                    .buttonStyle(.bordered)
                    .disabled(store.sliceStatus.isWorking || store.uploadStatus.isWorking)

                    Button("Slice current project") {
                        Task { await store.prepareSlice() }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(store.sliceStatus.isWorking || store.uploadStatus.isWorking)

                    Button("Upload to printer") {
                        Task { await store.pushLatestSliceToPrinter() }
                    }
                    .buttonStyle(.bordered)
                    .disabled(store.latestSliceResult == nil || store.sliceStatus.isWorking || store.uploadStatus.isWorking)
                }

                inspectorGroup(title: "Slice Output") {
                    Text(store.sliceStatus.message)
                        .font(.subheadline)

                    if let latestSliceResult = store.latestSliceResult {
                        Text("Preset \(latestSliceResult.selectedQualityPreset.displayName)")
                        Text("Material \(latestSliceResult.selectedMaterial.displayName)")
                        Text("Time \(latestSliceResult.estimatedPrintTimeMinutes) min")
                        Text("Filament \(latestSliceResult.estimatedFilamentGrams.formatted(.number.precision(.fractionLength(1)))) g")
                        Text("Length \(latestSliceResult.estimatedFilamentMeters.formatted(.number.precision(.fractionLength(2)))) m")
                    }
                }

                inspectorGroup(title: "Validation") {
                    if store.projectValidationIssues.isEmpty {
                        Text("No validation issues")
                    } else {
                        ForEach(store.projectValidationIssues) { issue in
                            Label(issue.message, systemImage: "exclamationmark.triangle")
                                .font(.subheadline)
                        }
                    }
                }
            }
            .padding(16)
        }
        .background(Color(red: 0.90, green: 0.91, blue: 0.88), in: RoundedRectangle(cornerRadius: 24))
    }

    private func panelHeader(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.title3.weight(.semibold))
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private func inspectorGroup<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.9), in: RoundedRectangle(cornerRadius: 18))
    }

    private func workspaceOverlay(for plate: BuildPlate) -> some View {
        VStack {
            HStack {
                Text(plate.name)
                    .font(.headline)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.75), in: Capsule())
                    .foregroundStyle(.white)
                Spacer()
                if let selectedModel = store.selectedModel {
                    Text("Selected: \(selectedModel.name)")
                        .font(.subheadline.weight(.medium))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.9), in: Capsule())
                }
            }
            .padding(24)

            Spacer()
        }
    }

    private func plateModelCard(model: PlacedModel, index: Int, size: CGSize) -> some View {
        let xOffset = CGFloat(model.position.x) + CGFloat(index * 28) - 48
        let yOffset = CGFloat(model.position.y) + CGFloat(index * 18) - 16
        let isSelected = store.selectedModelID == model.id
        let strokeCount = store.paintingStrokeCount(for: model.id)

        return VStack(alignment: .leading, spacing: 6) {
            Text(model.name)
                .font(.headline)
            Text(model.sourceURL.lastPathComponent)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("\(model.scalePercent)% • \(Int(model.rotationDegrees)) deg")
                .font(.caption2)
                .foregroundStyle(.secondary)
            if strokeCount > 0 {
                Text("\(strokeCount) painted surface region\(strokeCount == 1 ? "" : "s")")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .frame(width: 160, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(isSelected ? Color.orange.opacity(0.22) : Color.white.opacity(0.92))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(isSelected ? Color.orange : Color.orange.opacity(0.35), lineWidth: isSelected ? 2 : 1)
        )
        .rotationEffect(.degrees(model.rotationDegrees))
        .scaleEffect(CGFloat(model.scalePercent) / 100)
        .position(
            x: min(max(size.width * 0.5 + xOffset, 120), size.width - 120),
            y: min(max(size.height * 0.5 + yOffset, 120), size.height - 120)
        )
        .onTapGesture {
            store.selectModel(model.id)
        }
    }

    private func colorPlanRow(title: String, color: PrintColorOption) -> some View {
        HStack {
            Circle()
                .fill(color.swatch)
                .frame(width: 14, height: 14)
            Text(title)
            Spacer()
            Text(color.displayName)
                .foregroundStyle(.secondary)
        }
    }
}

private struct WorkspaceGrid: View {
    var body: some View {
        GeometryReader { _ in
            Canvas { context, size in
                let major = Color.black.opacity(0.12)
                let minor = Color.black.opacity(0.05)
                let majorSpacing: CGFloat = 80
                let minorSpacing: CGFloat = 20

                for x in stride(from: 0, through: size.width, by: minorSpacing) {
                    var path = Path()
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: size.height))
                    context.stroke(path, with: .color(minor), lineWidth: 1)
                }

                for y in stride(from: 0, through: size.height, by: minorSpacing) {
                    var path = Path()
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: size.width, y: y))
                    context.stroke(path, with: .color(minor), lineWidth: 1)
                }

                for x in stride(from: 0, through: size.width, by: majorSpacing) {
                    var path = Path()
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: size.height))
                    context.stroke(path, with: .color(major), lineWidth: 1.25)
                }

                for y in stride(from: 0, through: size.height, by: majorSpacing) {
                    var path = Path()
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: size.width, y: y))
                    context.stroke(path, with: .color(major), lineWidth: 1.25)
                }

                var centerX = Path()
                centerX.move(to: CGPoint(x: size.width / 2, y: 0))
                centerX.addLine(to: CGPoint(x: size.width / 2, y: size.height))
                context.stroke(centerX, with: .color(.orange.opacity(0.35)), lineWidth: 2)

                var centerY = Path()
                centerY.move(to: CGPoint(x: 0, y: size.height / 2))
                centerY.addLine(to: CGPoint(x: size.width, y: size.height / 2))
                context.stroke(centerY, with: .color(.orange.opacity(0.35)), lineWidth: 2)
            }
        }
    }
}
