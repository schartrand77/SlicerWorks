import SwiftUI
import UniformTypeIdentifiers

struct SlicerDashboardView: View {
    @EnvironmentObject private var store: AppStore
    @State private var showItemsPanel = true
    @State private var showAddPanel = false
    @State private var showInspectorPanel = true
    @State private var showColorPanel = true
    @State private var workspaceCamera = WorkspaceCamera()
    @State private var isPresentingModelImporter = false
    @State private var printerPendingAccessCodeEntry: BambuLANPrinter?
    @State private var printerPendingAccessCodeEdit: BambuLANPrinter?

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                workspaceBackground

                plateWorkspace
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)

                topProjectBar
                    .padding(.top, 18)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                leftSideChrome
                    .padding(.leading, 10)
                    .padding(.top, 20)
                    .padding(.bottom, 18)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)

                rightSideChrome
                    .padding(.trailing, 12)
                    .padding(.top, 20)
                    .padding(.bottom, 18)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)

                bottomChrome
                    .padding(.horizontal, 18)
                    .padding(.bottom, 18)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            }
        }
        .navigationBarHidden(true)
        .background(Color.black)
        .fileImporter(
            isPresented: $isPresentingModelImporter,
            allowedContentTypes: [.slicerWorks3mf, .slicerWorksSTL, .slicerWorksOBJ],
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case let .success(urls):
                store.importModels(from: urls)
            case let .failure(error):
                store.projectImportDidFail(error)
            }
        }
        .sheet(item: $printerPendingAccessCodeEntry) { printer in
            BambuPrinterAccessCodeSheet(printer: printer) { updatedPrinter, accessCode in
                store.addKnownLANPrinter(updatedPrinter, accessCode: accessCode)
            }
        }
        .sheet(item: $printerPendingAccessCodeEdit) { printer in
            BambuPrinterAccessCodeSheet(
                printer: printer,
                initialAccessCode: printer.accessCode ?? ""
            ) { updatedPrinter, accessCode in
                store.addKnownLANPrinter(updatedPrinter, accessCode: accessCode)
            }
        }
    }

    private var workspaceBackground: some View {
        LinearGradient(
            colors: [
                Color(red: 0.10, green: 0.10, blue: 0.11),
                Color(red: 0.07, green: 0.07, blue: 0.08)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    private var topProjectBar: some View {
        HStack(spacing: 12) {
            compactIconButton("house.fill")

            TextField("Project name", text: $store.activeProject.name)
                .textFieldStyle(.plain)
                .foregroundStyle(.white)
                .frame(width: 180)

            Menu {
                Picker("Quality", selection: $store.activeProject.sliceSettings.qualityPreset) {
                    ForEach(SliceQualityPreset.allCases) { preset in
                        Text(preset.displayName).tag(preset)
                    }
                }

                Picker("Material", selection: $store.activeProject.sliceSettings.filamentMaterial) {
                    ForEach(FilamentMaterial.allCases) { material in
                        Text(material.displayName).tag(material)
                    }
                }
            } label: {
                Image(systemName: "chevron.down")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.7))
            }

            Button("Slice") {
                Task { await store.prepareSlice() }
            }
            .buttonStyle(TopBarCapsuleStyle(fill: Color.white.opacity(0.08)))

            Button("Import") {
                isPresentingModelImporter = true
            }
            .buttonStyle(TopBarCapsuleStyle(fill: Color.white.opacity(0.08)))

            Button("Print") {
                Task { await store.pushLatestSliceToPrinter() }
            }
            .buttonStyle(TopBarCapsuleStyle(fill: Color.blue.opacity(0.88)))
            .disabled(store.latestSliceResult == nil || store.sliceStatus.isWorking || store.uploadStatus.isWorking)

            compactIconButton("ellipsis")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().stroke(Color.white.opacity(0.08), lineWidth: 1))
    }

    private var leftSideChrome: some View {
        VStack(alignment: .leading, spacing: 14) {
            toolLabelStack(labels: [
                ("Modeling", "cube"),
                ("Visualization", "sparkles"),
                ("Drawings", "doc.on.doc"),
                ("Items", "square.stack.3d.up")
            ]) {
                if showItemsPanel {
                    miniItemsPanel
                }
            } onTap: { label in
                if label == "Items" {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showItemsPanel.toggle()
                    }
                }
            }

            Spacer()

            toolLabelStack(labels: [
                ("Search", "magnifyingglass"),
                ("Sketch", "scribble.variable"),
                ("Add", "plus"),
                ("Transform", "arrow.up.left.and.arrow.down.right"),
                ("Tools", "wrench.and.screwdriver")
            ]) {
                if showAddPanel {
                    miniAddPanel
                }
            } onTap: { label in
                if label == "Add" {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showAddPanel.toggle()
                    }
                }
            }

            Spacer()

            VStack(alignment: .leading, spacing: 8) {
                sideTagButton(title: "Section View", systemName: "square.split.2x1")
                sideTagButton(title: "Measure", systemName: "ruler")
            }

            HStack(spacing: 8) {
                roundIconBadge("arrow.uturn.backward")
                roundIconBadge("arrow.uturn.forward")
            }
        }
    }

    private var rightSideChrome: some View {
        VStack(alignment: .trailing, spacing: 12) {
            orientationCluster

            VStack(alignment: .trailing, spacing: 8) {
                sideTagButton(title: "Display", systemName: "circle.lefthalf.filled", alignedTrailing: true)
                sideTagButton(title: "History", systemName: "clock.arrow.circlepath", alignedTrailing: true)
                sideTagButton(title: "Colors", systemName: "paintpalette", alignedTrailing: true) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showColorPanel.toggle()
                    }
                }
                sideTagButton(title: "Inspector", systemName: "slider.horizontal.3", alignedTrailing: true) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showInspectorPanel.toggle()
                    }
                }
            }

            if showInspectorPanel, let selectedModel = store.selectedModel {
                floatingInfoCard(title: selectedModel.name) {
                    infoLine("Position", "\(Int(selectedModel.position.x)), \(Int(selectedModel.position.y))")
                    infoLine("Rotation", "\(Int(selectedModel.rotationDegrees)) deg")
                    infoLine("Scale", "\(selectedModel.scalePercent)%")
                    infoLine("Surface regions", "\(store.paintingStrokeCount(for: selectedModel.id))")
                }
            }

            if showColorPanel {
                floatingInfoCard(title: "Color Plan") {
                    colorLine("Surface", store.activeProject.sliceSettings.surfaceColor)
                    colorLine("Infill", store.activeProject.sliceSettings.infillColor)
                    Text("Surface color is Pencil-driven. Infill stays explicit.")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.58))
                }
            }

            Spacer()
        }
    }

    private var bottomChrome: some View {
        HStack {
            if store.selectedLANPrinter == nil || store.knownLANPrinters.isEmpty == false || store.discoveredLANPrinters.isEmpty == false {
                printerStatusCard
            }

            Spacer()
            Spacer()
            floatingStatusCard
        }
    }

    private var printerStatusCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Printer Status", systemImage: "wifi")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.78))
                Spacer()
                if let selectedPrinter = store.selectedLANPrinter {
                    Text(selectedPrinter.name)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.green.opacity(0.95))
                }
            }

            if let selectedPrinter = store.selectedLANPrinter {
                Text("\(selectedPrinter.profile.displayName) on \(selectedPrinter.host)")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.62))
            } else {
                Text("Select a Bambu printer on LAN so sliced jobs can go straight to the device.")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.62))
            }

            HStack(spacing: 8) {
                Button("Discover") {
                    Task { await store.discoverPrintersOnLAN() }
                }
                .buttonStyle(PlainCapsuleActionStyle())

                if let firstDiscoveredPrinter = store.newlyDiscoveredLANPrinters.first ?? store.discoveredLANPrinters.first {
                    Button(store.knownLANPrinters.contains(where: { $0.serialNumber == firstDiscoveredPrinter.serialNumber }) ? "Use First Found" : "Add First Found") {
                        if let knownPrinter = store.knownLANPrinters.first(where: { $0.serialNumber == firstDiscoveredPrinter.serialNumber || $0.host == firstDiscoveredPrinter.host }) {
                            if knownPrinter.hasAccessCode {
                                store.selectLANPrinter(knownPrinter.id)
                            } else {
                                printerPendingAccessCodeEdit = knownPrinter
                            }
                        } else {
                            printerPendingAccessCodeEntry = firstDiscoveredPrinter
                        }
                    }
                    .buttonStyle(PlainCapsuleActionStyle())
                }
            }

            if store.knownLANPrinters.isEmpty == false {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(store.knownLANPrinters.prefix(2)) { printer in
                        Button {
                            store.selectLANPrinter(printer.id)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(printer.name)
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.white)
                                    Text("\(printer.profile.displayName)  \(printer.host)")
                                        .font(.caption2)
                                        .foregroundStyle(.white.opacity(0.55))
                                }
                                Spacer()
                                if store.selectedLANPrinterID == printer.id {
                                    Text("Selected")
                                        .font(.caption2.weight(.bold))
                                        .foregroundStyle(.green.opacity(0.95))
                                } else if printer.hasAccessCode == false {
                                    Text("Needs code")
                                        .font(.caption2.weight(.bold))
                                        .foregroundStyle(.yellow.opacity(0.95))
                                }
                            }
                            .padding(8)
                            .background(Color.white.opacity(store.selectedLANPrinterID == printer.id ? 0.12 : 0.04), in: RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if let selectedPrinter = store.selectedLANPrinter {
                Text(selectedPrinter.hasAccessCode ? "LAN access code saved" : "LAN access code required")
                    .font(.caption2)
                    .foregroundStyle(selectedPrinter.hasAccessCode ? .green.opacity(0.95) : .yellow.opacity(0.95))
            }
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.08), lineWidth: 1))
        .frame(width: 320, alignment: .leading)
    }

    private var miniItemsPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Workspace")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.72))
                Spacer()
                Button {
                    store.addPlate()
                } label: {
                    Image(systemName: "plus")
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
            }

            ForEach(store.activeProject.plates) { plate in
                Button {
                    store.selectedPlateID = plate.id
                    store.selectedModelID = plate.models.first?.id
                } label: {
                    HStack(spacing: 10) {
                        roundedPlateBadge(plate.name.replacingOccurrences(of: "Plate ", with: ""), isSelected: store.selectedPlateID == plate.id)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(plate.name)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white)
                            Text("\(plate.models.count) model\(plate.models.count == 1 ? "" : "s")")
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.55))
                        }
                        Spacer()
                    }
                    .padding(8)
                    .background(Color.white.opacity(store.selectedPlateID == plate.id ? 0.12 : 0.04), in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }

            if let selectedPlate = store.selectedPlate {
                ForEach(selectedPlate.models) { model in
                    Button {
                        store.selectModel(model.id)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(model.name)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.white)
                                Text("\(store.paintingStrokeCount(for: model.id)) marks")
                                    .font(.caption2)
                                    .foregroundStyle(.green)
                            }
                            Spacer()
                        }
                        .padding(8)
                        .background(Color.white.opacity(store.selectedModelID == model.id ? 0.12 : 0.03), in: RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.08), lineWidth: 1))
        .frame(width: 220)
    }

    private var miniAddPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button("Add Plate") {
                store.addPlate()
            }
            .buttonStyle(PlainCapsuleActionStyle())

            Button("Add Model") {
                isPresentingModelImporter = true
            }
            .buttonStyle(PlainCapsuleActionStyle())

            Button("Recommended Preset") {
                store.applyRecommendedSettings()
            }
            .buttonStyle(PlainCapsuleActionStyle())
        }
        .padding(10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.08), lineWidth: 1))
        .frame(width: 180)
    }

    private var plateWorkspace: some View {
        ZStack {
            WorkspaceGrid()
                .clipShape(RoundedRectangle(cornerRadius: 28))

            GeometryReader { geometry in
                ZStack {
                    if let plate = store.selectedPlate {
                        if plate.models.isEmpty {
                            Text("Import a model to begin")
                                .font(.headline)
                                .foregroundStyle(.white.opacity(0.75))
                        } else {
                            ModelWorkspaceSceneView(
                                models: plate.models,
                                selectedModelID: store.selectedModelID,
                                surfaceColor: store.activeProject.sliceSettings.surfaceColor,
                                onSelectModel: { modelID in
                                    store.selectModel(modelID)
                                },
                                onContextAction: handleModelContextAction
                            )
                            .frame(width: geometry.size.width, height: geometry.size.height)

                            if let selectedModel = store.selectedModel {
                                Text(selectedModel.name)
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(.white.opacity(0.8))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Color.black.opacity(0.22), in: Capsule())
                                    .padding(.top, 72)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                            }
                        }
                    } else {
                        Text("Add a build plate to begin")
                            .font(.headline)
                            .foregroundStyle(.white.opacity(0.75))
                    }
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
            }
        }
        .contentShape(Rectangle())
    }

    private func handleModelContextAction(_ action: ModelWorkspaceContextAction) {
        switch action {
        case let .selectModel(modelID):
            store.selectModel(modelID)
        case let .duplicateModel(modelID):
            store.duplicateModel(modelID)
        case let .deleteModel(modelID):
            store.deleteModel(modelID)
        case let .centerModel(modelID):
            store.centerModel(modelID)
        case let .rotateModel(modelID, degrees):
            store.rotateModel(modelID, by: degrees)
        case let .scaleModel(modelID, percentageDelta):
            store.scaleModel(modelID, by: percentageDelta)
        case let .resetModelTransform(modelID):
            store.resetModelTransform(modelID)
        }
    }

    private func plateModelCard(model: PlacedModel, index: Int, size: CGSize) -> some View {
        let xOffset = CGFloat(model.position.x) + CGFloat(index * 28) - 48
        let yOffset = CGFloat(model.position.y) + CGFloat(index * 18) - 16
        let isSelected = store.selectedModelID == model.id

        return VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: isSelected
                            ? [Color.white.opacity(0.92), Color.green.opacity(0.75)]
                            : [Color.white.opacity(0.78), Color.gray.opacity(0.7)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(isSelected ? Color.white : Color.white.opacity(0.25), lineWidth: isSelected ? 2 : 1)
                )
                .frame(width: 88, height: 118)
                .overlay(alignment: .bottom) {
                    Text(model.name)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.black.opacity(0.7))
                        .padding(.bottom, 10)
                }
        }
        .rotationEffect(.degrees(model.rotationDegrees))
        .scaleEffect(CGFloat(model.scalePercent) / 100)
        .position(
            x: min(max(size.width * 0.5 + xOffset, 120), size.width - 120),
            y: min(max(size.height * 0.5 + yOffset, 120), size.height - 120)
        )
        .overlay(alignment: .bottomTrailing) {
            if store.paintingStrokeCount(for: model.id) > 0 {
                Text("\(store.paintingStrokeCount(for: model.id))")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(6)
                    .background(Color.green.opacity(0.9), in: Circle())
                    .offset(x: 18, y: 14)
            }
        }
        .onTapGesture {
            store.selectModel(model.id)
        }
    }

    private var orientationCluster: some View {
        WorkspaceNavigationCluster(camera: $workspaceCamera)
    }

    private var floatingStatusCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: store.sliceStatus.isWorking ? "gearshape.2.fill" : "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text(store.sliceStatus.message)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white)
            }

            if let latestSliceResult = store.latestSliceResult {
                Text("Preset \(latestSliceResult.selectedQualityPreset.displayName)  Time \(latestSliceResult.estimatedPrintTimeMinutes) min")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.08), lineWidth: 1))
        .frame(width: 250, alignment: .leading)
    }

    private func floatingInfoCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(.white.opacity(0.76))
            content()
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.08), lineWidth: 1))
        .frame(width: 220, alignment: .leading)
    }

    private func infoLine(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.white.opacity(0.56))
            Spacer()
            Text(value)
                .foregroundStyle(.white)
        }
        .font(.caption2)
    }

    private func colorLine(_ label: String, _ color: PrintColorOption) -> some View {
        HStack {
            Circle()
                .fill(color.swatch)
                .frame(width: 10, height: 10)
            Text(label)
                .foregroundStyle(.white.opacity(0.62))
            Spacer()
            Text(color.displayName)
                .foregroundStyle(.white)
        }
        .font(.caption2)
    }

    private func toolLabelStack(labels: [(String, String)], @ViewBuilder overlay: () -> some View, onTap: @escaping (String) -> Void) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(labels, id: \.0) { label, icon in
                Button {
                    onTap(label)
                } label: {
                    HStack(spacing: 10) {
                        roundIconBadge(icon)
                        Text(label)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.9))
                    }
                }
                .buttonStyle(.plain)
            }

            overlay()
        }
    }

    private func sideTagButton(title: String, systemName: String, alignedTrailing: Bool = false, action: (() -> Void)? = nil) -> some View {
        Button {
            action?()
        } label: {
            HStack(spacing: 8) {
                if alignedTrailing == false {
                    roundIconBadge(systemName)
                }

                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.9))

                if alignedTrailing {
                    roundIconBadge(systemName)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func roundIconBadge(_ systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.white.opacity(0.9))
            .frame(width: 32, height: 32)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.08), lineWidth: 1))
    }

    private func compactIconButton(_ systemName: String) -> some View {
        Button {} label: {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white.opacity(0.88))
                .frame(width: 28, height: 28)
        }
        .buttonStyle(.plain)
    }

    private func roundedPlateBadge(_ text: String, isSelected: Bool) -> some View {
        Text(text)
            .font(.caption2.weight(.bold))
            .foregroundStyle(.white)
            .frame(width: 28, height: 36)
            .background(isSelected ? Color.blue.opacity(0.9) : Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
    }
}

private extension UTType {
    static let slicerWorks3mf = UTType(filenameExtension: "3mf") ?? .data
    static let slicerWorksSTL = UTType(filenameExtension: "stl") ?? .data
    static let slicerWorksOBJ = UTType(filenameExtension: "obj") ?? .data
}

private struct WorkspaceGrid: View {
    var body: some View {
        GeometryReader { _ in
            Canvas { context, size in
                let major = Color.white.opacity(0.07)
                let minor = Color.white.opacity(0.028)
                let majorSpacing: CGFloat = 84
                let minorSpacing: CGFloat = 21

                let backgroundRect = Path(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 28)
                context.fill(backgroundRect, with: .color(Color.black.opacity(0.08)))

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
                    context.stroke(path, with: .color(major), lineWidth: 1)
                }

                for y in stride(from: 0, through: size.height, by: majorSpacing) {
                    var path = Path()
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: size.width, y: y))
                    context.stroke(path, with: .color(major), lineWidth: 1)
                }

            }
        }
    }
}

private struct TopBarCapsuleStyle: ButtonStyle {
    let fill: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white.opacity(configuration.isPressed ? 0.75 : 1))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(fill.opacity(configuration.isPressed ? 0.85 : 1), in: Capsule())
    }
}

private struct PlainCapsuleActionStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white.opacity(configuration.isPressed ? 0.72 : 1))
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(configuration.isPressed ? 0.12 : 0.06), in: RoundedRectangle(cornerRadius: 10))
    }
}
