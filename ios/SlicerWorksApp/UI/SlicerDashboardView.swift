import SwiftUI

struct SlicerDashboardView: View {
    @EnvironmentObject private var store: AppStore
    @State private var isLeftRailCollapsed = false
    @State private var isRightInspectorCollapsed = false
    @State private var isBottomStatusCollapsed = false

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                workspaceBackground

                plateWorkspace
                    .padding(.horizontal, horizontalWorkspaceInset(for: geometry.size))
                    .padding(.top, 88)
                    .padding(.bottom, 74)

                topToolbar
                    .padding(.horizontal, 18)
                    .padding(.top, 12)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                edgeWidgets(for: geometry.size)
            }
        }
        .navigationBarHidden(true)
        .background(Color(red: 0.33, green: 0.34, blue: 0.38))
    }

    private var workspaceBackground: some View {
        LinearGradient(
            colors: [
                Color(red: 0.37, green: 0.38, blue: 0.42),
                Color(red: 0.31, green: 0.32, blue: 0.36)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    private var topToolbar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 10) {
                workspaceModeChip(title: "Prepare", icon: "cube.transparent.fill", isActive: true)
                workspaceModeChip(title: "Preview", icon: "square.stack.3d.up")
                workspaceModeChip(title: "Devices", icon: "printer")
            }

            Spacer()

            Text(store.activeProject.name)
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.96))

            Spacer()

            HStack(spacing: 10) {
                toolbarGlyph(systemName: "square.grid.2x2")
                toolbarGlyph(systemName: "slider.horizontal.3")

                Button("Slice plate") {
                    Task { await store.prepareSlice() }
                }
                .buttonStyle(WorkspaceCapsuleButtonStyle(fill: Color.white.opacity(0.14), foreground: .white))

                Button("Print plate") {
                    Task { await store.pushLatestSliceToPrinter() }
                }
                .buttonStyle(WorkspaceCapsuleButtonStyle(fill: Color.green.opacity(0.9), foreground: .white))
                .disabled(store.latestSliceResult == nil || store.sliceStatus.isWorking || store.uploadStatus.isWorking)
            }
        }
    }

    private func edgeWidgets(for size: CGSize) -> some View {
        ZStack {
            VStack {
                Spacer(minLength: 84)

                HStack(alignment: .top, spacing: 14) {
                    leftRail
                    Spacer()
                    rightInspector
                }

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 18)

            bottomStatus
                .padding(.horizontal, 16)
                .padding(.bottom, 18)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
    }

    private var leftRail: some View {
        workspaceWidget(alignment: .leading, width: isLeftRailCollapsed ? 62 : 308) {
            VStack(alignment: .leading, spacing: 14) {
                railHeader(
                    title: "Workspace",
                    subtitle: store.selectedPrinter.displayName,
                    isCollapsed: $isLeftRailCollapsed,
                    collapseSystemImage: "sidebar.left"
                )

                if isLeftRailCollapsed == false {
                    VStack(alignment: .leading, spacing: 14) {
                        sectionCard(title: "Build Plates", trailing: {
                            Button {
                                store.addPlate()
                            } label: {
                                Image(systemName: "plus")
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.white)
                        }) {
                            ForEach(store.activeProject.plates) { plate in
                                Button {
                                    store.selectedPlateID = plate.id
                                    store.selectedModelID = plate.models.first?.id
                                } label: {
                                    HStack(spacing: 10) {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(plateBadgeFill(isSelected: store.selectedPlateID == plate.id))
                                            Text(plate.name.replacingOccurrences(of: "Plate ", with: ""))
                                                .font(.caption.weight(.bold))
                                                .foregroundStyle(.white)
                                        }
                                        .frame(width: 34, height: 42)

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(plate.name)
                                                .font(.subheadline.weight(.semibold))
                                                .foregroundStyle(.white)
                                            Text("\(plate.models.count) model\(plate.models.count == 1 ? "" : "s")")
                                                .font(.caption)
                                                .foregroundStyle(.white.opacity(0.65))
                                        }

                                        Spacer()

                                        if store.selectedPlateID == plate.id {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundStyle(.green)
                                        }
                                    }
                                    .padding(10)
                                    .background(widgetRowFill(isSelected: store.selectedPlateID == plate.id), in: RoundedRectangle(cornerRadius: 14))
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        sectionCard(title: "Models", trailing: {
                            Button {
                                store.addSampleModel()
                            } label: {
                                Image(systemName: "square.stack.badge.plus")
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.white)
                        }) {
                            if let selectedPlate = store.selectedPlate, selectedPlate.models.isEmpty == false {
                                ForEach(selectedPlate.models) { model in
                                    Button {
                                        store.selectModel(model.id)
                                    } label: {
                                        VStack(alignment: .leading, spacing: 5) {
                                            HStack {
                                                Text(model.name)
                                                    .font(.subheadline.weight(.semibold))
                                                    .foregroundStyle(.white)
                                                Spacer()
                                                Text("\(store.paintingStrokeCount(for: model.id)) marks")
                                                    .font(.caption2.weight(.medium))
                                                    .foregroundStyle(.green)
                                            }

                                            Text(model.sourceURL.lastPathComponent)
                                                .font(.caption)
                                                .foregroundStyle(.white.opacity(0.62))

                                            Text("Scale \(model.scalePercent)%  Rot \(Int(model.rotationDegrees)) deg")
                                                .font(.caption2)
                                                .foregroundStyle(.white.opacity(0.62))
                                        }
                                        .padding(10)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(widgetRowFill(isSelected: store.selectedModelID == model.id), in: RoundedRectangle(cornerRadius: 14))
                                    }
                                    .buttonStyle(.plain)
                                }
                            } else {
                                Text("No models on this plate yet.")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.65))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }

                        if let selectedModel = store.selectedModel {
                            sectionCard(title: "Selection") {
                                Text(selectedModel.name)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.white)
                                Text("X \(Int(selectedModel.position.x))  Y \(Int(selectedModel.position.y))")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.62))
                                Text("Touch selects. Apple Pencil edits surfaces in Paint.")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.62))
                            }
                        }
                    }
                } else {
                    collapsedRailGlyphs(systemNames: ["square.grid.2x2", "square.stack.3d.up", "paintbrush"])
                }
            }
        }
    }

    private var rightInspector: some View {
        workspaceWidget(alignment: .trailing, width: isRightInspectorCollapsed ? 62 : 332) {
            VStack(alignment: .leading, spacing: 14) {
                railHeader(
                    title: "Inspector",
                    subtitle: "Transparent edge widget",
                    isCollapsed: $isRightInspectorCollapsed,
                    collapseSystemImage: "sidebar.right"
                )

                if isRightInspectorCollapsed == false {
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 14) {
                            sectionCard(title: "Project") {
                                TextField("Project name", text: $store.activeProject.name)
                                    .textFieldStyle(.plain)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                                    .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                                    .foregroundStyle(.white)

                                labeledPicker("Quality", selection: $store.activeProject.sliceSettings.qualityPreset, options: SliceQualityPreset.allCases) { $0.displayName }
                                labeledPicker("Material", selection: $store.activeProject.sliceSettings.filamentMaterial, options: FilamentMaterial.allCases) { $0.displayName }

                                Button("Apply recommended preset") {
                                    store.applyRecommendedSettings()
                                }
                                .buttonStyle(WorkspaceCapsuleButtonStyle(fill: Color.green.opacity(0.8), foreground: .white))
                            }

                            if let selectedModel = store.selectedModel {
                                sectionCard(title: "Selected Model") {
                                    Text(selectedModel.name)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.white)
                                    Text(selectedModel.sourceURL.lastPathComponent)
                                        .font(.caption)
                                        .foregroundStyle(.white.opacity(0.65))
                                    Text("Position \(Int(selectedModel.position.x)), \(Int(selectedModel.position.y))")
                                        .font(.caption)
                                        .foregroundStyle(.white.opacity(0.65))
                                    Text("Rotation \(Int(selectedModel.rotationDegrees)) deg")
                                        .font(.caption)
                                        .foregroundStyle(.white.opacity(0.65))
                                    Text("Scale \(selectedModel.scalePercent)%")
                                        .font(.caption)
                                        .foregroundStyle(.white.opacity(0.65))
                                    Text("Surface paint regions \(store.paintingStrokeCount(for: selectedModel.id))")
                                        .font(.caption)
                                        .foregroundStyle(.green)
                                }
                            }

                            sectionCard(title: "Color Plan") {
                                colorPlanRow(title: "Surface", color: store.activeProject.sliceSettings.surfaceColor)
                                colorPlanRow(title: "Infill", color: store.activeProject.sliceSettings.infillColor)
                                Text("Surface color comes from Apple Pencil painting. Infill color is chosen explicitly so the inside never gets painted by mistake.")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.65))
                            }

                            sectionCard(title: "Shell and Infill") {
                                metricStepper("Layer \(store.activeProject.sliceSettings.layerHeightMM.formatted(.number.precision(.fractionLength(2)))) mm", value: $store.activeProject.sliceSettings.layerHeightMM, range: store.selectedPrinter.minimumLayerHeightMM...store.selectedPrinter.maximumLayerHeightMM, step: 0.04)
                                metricStepper("Walls \(store.activeProject.sliceSettings.wallLoopCount)", value: $store.activeProject.sliceSettings.wallLoopCount, range: 1...8, step: 1)
                                metricStepper("Infill \(store.activeProject.sliceSettings.infillPercent)%", value: $store.activeProject.sliceSettings.infillPercent, range: 0...100, step: 5)

                                labeledPicker("Pattern", selection: $store.activeProject.sliceSettings.infillPattern, options: InfillPattern.allCases) { $0.displayName }
                            }

                            sectionCard(title: "Thermals and Support") {
                                metricStepper("Speed \(store.activeProject.sliceSettings.printSpeedMMPerSecond) mm/s", value: $store.activeProject.sliceSettings.printSpeedMMPerSecond, range: 30...store.selectedPrinter.maximumPrintSpeedMMPerSecond, step: 10)
                                metricStepper("Nozzle \(store.activeProject.sliceSettings.nozzleTemperatureC) C", value: $store.activeProject.sliceSettings.nozzleTemperatureC, range: 180...300, step: 5)
                                metricStepper("Bed \(store.activeProject.sliceSettings.bedTemperatureC) C", value: $store.activeProject.sliceSettings.bedTemperatureC, range: 0...110, step: 5)

                                labeledPicker("Supports", selection: $store.activeProject.sliceSettings.supportStyle, options: SupportStyle.allCases) { $0.displayName }
                                labeledPicker("Adhesion", selection: $store.activeProject.sliceSettings.adhesionType, options: AdhesionType.allCases) { $0.displayName }
                            }
                        }
                    }
                } else {
                    collapsedRailGlyphs(systemNames: ["slider.horizontal.3", "paintpalette", "gearshape.2"])
                }
            }
        }
    }

    private var bottomStatus: some View {
        workspaceWidget(alignment: .bottom, width: isBottomStatusCollapsed ? 220 : 360) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label(store.sliceStatus.isWorking ? "Working" : "Slice status", systemImage: store.sliceStatus.isWorking ? "gearshape.2.fill" : "checkmark.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)

                    Spacer()

                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isBottomStatusCollapsed.toggle()
                        }
                    } label: {
                        Image(systemName: isBottomStatusCollapsed ? "chevron.up" : "chevron.down")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white.opacity(0.82))
                    }
                    .buttonStyle(.plain)
                }

                if isBottomStatusCollapsed == false {
                    Text(store.sliceStatus.message)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))

                    if let latestSliceResult = store.latestSliceResult {
                        HStack(spacing: 16) {
                            workspaceMetric(title: "Preset", value: latestSliceResult.selectedQualityPreset.displayName)
                            workspaceMetric(title: "Time", value: "\(latestSliceResult.estimatedPrintTimeMinutes) min")
                            workspaceMetric(title: "Filament", value: "\(latestSliceResult.estimatedFilamentGrams.formatted(.number.precision(.fractionLength(1)))) g")
                        }
                    }

                    if store.projectValidationIssues.isEmpty == false {
                        Text(store.projectValidationIssues.first?.message ?? "")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
            }
        }
    }

    private var plateWorkspace: some View {
        GeometryReader { geometry in
            ZStack {
                RoundedRectangle(cornerRadius: 32)
                    .fill(Color.clear)

                WorkspaceGrid()
                    .clipShape(RoundedRectangle(cornerRadius: 32))

                RoundedRectangle(cornerRadius: 28)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    .padding(24)

                if let plate = store.selectedPlate {
                    workspaceOverlay(for: plate)

                    topToolStrip
                        .padding(.top, 16)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                    ForEach(Array(plate.models.enumerated()), id: \.element.id) { index, model in
                        plateModelCard(model: model, index: index, size: geometry.size)
                    }

                    bottomWorkspaceReadout
                        .padding(.leading, 22)
                        .padding(.bottom, 18)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                } else {
                    VStack(spacing: 10) {
                        Image(systemName: "square.grid.3x3.middle.filled")
                            .font(.system(size: 38))
                            .foregroundStyle(.white.opacity(0.9))
                        Text("Add a build plate to begin arranging parts.")
                            .font(.headline)
                            .foregroundStyle(.white)
                        Text("The workspace stays full-screen while tools remain off to the edges.")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.65))
                    }
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                store.selectModel(nil)
            }
        }
        .shadow(color: .black.opacity(0.22), radius: 22, y: 10)
    }

    private var topToolStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                workspaceToolGlyph("plus.viewfinder")
                workspaceToolGlyph("move.3d")
                workspaceToolGlyph("rotate.3d")
                workspaceToolGlyph("scale.3d")
                workspaceToolGlyph("scissors")
                workspaceToolGlyph("paintbrush.pointed")
                workspaceToolGlyph("eye")
                workspaceToolGlyph("slider.horizontal.3")
            }
            .padding(.horizontal, 12)
        }
        .frame(height: 52)
    }

    private var bottomWorkspaceReadout: some View {
        HStack(spacing: 12) {
            axisTile
            Label("Touch selects and orbits. Apple Pencil edits models and paints surfaces.", systemImage: "applepencil")
                .font(.caption.weight(.medium))
                .foregroundStyle(.white.opacity(0.74))
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.black.opacity(0.22), in: Capsule())
        }
    }

    private var axisTile: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Top")
                .font(.caption2.weight(.bold))
            Text("Front")
                .font(.caption2)
        }
        .foregroundStyle(.white.opacity(0.82))
        .padding(12)
        .background(Color.black.opacity(0.22), in: RoundedRectangle(cornerRadius: 12))
    }

    private func workspaceOverlay(for plate: BuildPlate) -> some View {
        VStack {
            HStack {
                HStack(spacing: 10) {
                    Text(plate.name)
                        .font(.headline)
                        .foregroundStyle(.white)

                    Text("\(plate.models.count) model\(plate.models.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.65))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.black.opacity(0.22), in: Capsule())

                Spacer()

                if let selectedModel = store.selectedModel {
                    Text("Selected: \(selectedModel.name)")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Color.black.opacity(0.22), in: Capsule())
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 20)

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
                .foregroundStyle(.white)
            Text(model.sourceURL.lastPathComponent)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.7))
            Text("\(model.scalePercent)%  \(Int(model.rotationDegrees)) deg")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.64))
            if strokeCount > 0 {
                Text("\(strokeCount) painted surface region\(strokeCount == 1 ? "" : "s")")
                    .font(.caption2)
                    .foregroundStyle(.green.opacity(0.92))
            }
        }
        .padding(14)
        .frame(width: 176, alignment: .leading)
        .background(widgetRowFill(isSelected: isSelected), in: RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(isSelected ? Color.green.opacity(0.88) : Color.white.opacity(0.08), lineWidth: isSelected ? 2 : 1)
        )
        .rotationEffect(.degrees(model.rotationDegrees))
        .scaleEffect(CGFloat(model.scalePercent) / 100)
        .position(
            x: min(max(size.width * 0.5 + xOffset, 132), size.width - 132),
            y: min(max(size.height * 0.5 + yOffset, 132), size.height - 132)
        )
        .onTapGesture {
            store.selectModel(model.id)
        }
    }

    private func workspaceWidget<Content: View>(alignment: Alignment, width: CGFloat, @ViewBuilder content: () -> Content) -> some View {
        content()
            .frame(width: width, alignment: .topLeading)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color.black.opacity(0.22))
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.18), radius: 16, y: 8)
    }

    private func railHeader(title: String, subtitle: String, isCollapsed: Binding<Bool>, collapseSystemImage: String) -> some View {
        HStack {
            if isCollapsed.wrappedValue == false {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.64))
                }
            } else {
                Image(systemName: collapseSystemImage)
                    .foregroundStyle(.white.opacity(0.88))
                    .frame(maxWidth: .infinity, alignment: .center)
            }

            Spacer(minLength: isCollapsed.wrappedValue ? 0 : 8)

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isCollapsed.wrappedValue.toggle()
                }
            } label: {
                Image(systemName: isCollapsed.wrappedValue ? "chevron.right" : "chevron.left")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.82))
                    .frame(width: 28, height: 28)
                    .background(Color.white.opacity(0.08), in: Circle())
            }
            .buttonStyle(.plain)
        }
    }

    private func sectionCard<Content: View, Trailing: View>(title: String, @ViewBuilder trailing: () -> Trailing, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.7))
                Spacer()
                trailing()
            }

            content()
        }
        .padding(12)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 18))
    }

    private func sectionCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        sectionCard(title: title, trailing: { EmptyView() }, content: content)
    }

    private func colorPlanRow(title: String, color: PrintColorOption) -> some View {
        HStack {
            Circle()
                .fill(color.swatch)
                .frame(width: 14, height: 14)
            Text(title)
                .foregroundStyle(.white)
            Spacer()
            Text(color.displayName)
                .foregroundStyle(.white.opacity(0.68))
        }
        .font(.caption)
    }

    private func workspaceModeChip(title: String, icon: String, isActive: Bool = false) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption.weight(.semibold))
            Text(title)
                .font(.subheadline.weight(.semibold))
        }
        .foregroundStyle(.white.opacity(isActive ? 1 : 0.82))
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(isActive ? Color.green.opacity(0.8) : Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
    }

    private func toolbarGlyph(systemName: String) -> some View {
        Image(systemName: systemName)
            .foregroundStyle(.white.opacity(0.85))
            .frame(width: 34, height: 34)
            .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
    }

    private func workspaceToolGlyph(_ systemName: String) -> some View {
        Image(systemName: systemName)
            .foregroundStyle(.white.opacity(0.88))
            .frame(width: 38, height: 38)
            .background(Color.black.opacity(0.18), in: RoundedRectangle(cornerRadius: 10))
    }

    private func workspaceMetric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white.opacity(0.54))
            Text(value)
                .font(.caption.weight(.medium))
                .foregroundStyle(.white)
        }
    }

    private func collapsedRailGlyphs(systemNames: [String]) -> some View {
        VStack(spacing: 10) {
            ForEach(systemNames, id: \.self) { systemName in
                Image(systemName: systemName)
                    .foregroundStyle(.white.opacity(0.84))
                    .frame(width: 38, height: 38)
                    .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func plateBadgeFill(isSelected: Bool) -> Color {
        isSelected ? Color.green.opacity(0.9) : Color.white.opacity(0.14)
    }

    private func widgetRowFill(isSelected: Bool) -> Color {
        isSelected ? Color.green.opacity(0.18) : Color.white.opacity(0.04)
    }

    private func horizontalWorkspaceInset(for size: CGSize) -> CGFloat {
        size.width > 900 ? 52 : 16
    }

    private func labeledPicker<Option: Hashable>(_ title: String, selection: Binding<Option>, options: [Option], titleForOption: @escaping (Option) -> String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(.white.opacity(0.7))

            Picker(title, selection: selection) {
                ForEach(Array(options.enumerated()), id: \.offset) { _, option in
                    Text(titleForOption(option)).tag(option)
                }
            }
            .pickerStyle(.menu)
            .tint(.white)
        }
    }

    private func metricStepper<Value: Strideable>(_ title: String, value: Binding<Value>, range: ClosedRange<Value>, step: Value.Stride) -> some View where Value.Stride: SignedNumeric {
        Stepper(title, value: value, in: range, step: step)
            .font(.caption)
            .foregroundStyle(.white)
    }
}

private struct WorkspaceGrid: View {
    var body: some View {
        GeometryReader { _ in
            Canvas { context, size in
                let major = Color.white.opacity(0.11)
                let minor = Color.white.opacity(0.045)
                let majorSpacing: CGFloat = 84
                let minorSpacing: CGFloat = 21

                let backgroundRect = Path(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 32)
                context.fill(backgroundRect, with: .color(Color.black.opacity(0.1)))

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
                    context.stroke(path, with: .color(major), lineWidth: 1.15)
                }

                for y in stride(from: 0, through: size.height, by: majorSpacing) {
                    var path = Path()
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: size.width, y: y))
                    context.stroke(path, with: .color(major), lineWidth: 1.15)
                }

                var centerX = Path()
                centerX.move(to: CGPoint(x: size.width / 2, y: 0))
                centerX.addLine(to: CGPoint(x: size.width / 2, y: size.height))
                context.stroke(centerX, with: .color(.green.opacity(0.26)), lineWidth: 1.5)

                var centerY = Path()
                centerY.move(to: CGPoint(x: 0, y: size.height / 2))
                centerY.addLine(to: CGPoint(x: size.width, y: size.height / 2))
                context.stroke(centerY, with: .color(.green.opacity(0.26)), lineWidth: 1.5)
            }
        }
    }
}

private struct WorkspaceCapsuleButtonStyle: ButtonStyle {
    let fill: Color
    let foreground: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(foreground.opacity(configuration.isPressed ? 0.82 : 1))
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(fill.opacity(configuration.isPressed ? 0.8 : 1), in: Capsule())
    }
}
