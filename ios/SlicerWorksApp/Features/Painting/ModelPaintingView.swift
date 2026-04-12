import SwiftUI

struct ModelPaintingView: View {
    @EnvironmentObject private var store: AppStore
    @Binding var selectedSection: WorkspaceSection
    @State private var showToolsPanel = true
    @State private var showColorPanel = true
    @State private var showPencilPanel = true
    @State private var workspaceCamera = WorkspaceCamera()

    var body: some View {
        GeometryReader { _ in
            ZStack {
                workspaceBackground

                paintingWorkspace
                    .padding(12)

                topBar
                    .padding(.top, 18)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                leftChrome
                    .padding(.leading, 10)
                    .padding(.top, 88)
                    .padding(.bottom, 18)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)

                rightChrome
                    .padding(.trailing, 12)
                    .padding(.top, 88)
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

    private var topBar: some View {
        HStack(spacing: 12) {
            WorkspaceSectionPicker(selectedSection: $selectedSection)

            miniTopIcon("paintbrush.pointed.fill")

            Text(store.selectedModel?.name ?? "Paint")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white)

            Button(store.selectedTool.title) {}
                .buttonStyle(PaintTopCapsuleStyle(fill: Color.white.opacity(0.08)))

            Button("Clear") {
                store.clearSelectedModelPainting()
            }
            .buttonStyle(PaintTopCapsuleStyle(fill: Color.white.opacity(0.08)))

            compactColorSwatch(store.activeProject.sliceSettings.surfaceColor)
            compactColorSwatch(store.activeProject.sliceSettings.infillColor)

            miniTopIcon("ellipsis")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().stroke(Color.white.opacity(0.08), lineWidth: 1))
    }

    private var leftChrome: some View {
        VStack(alignment: .leading, spacing: 12) {
            chromeLabel(title: "Paint", systemName: "paintbrush.pointed") {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showToolsPanel.toggle()
                }
            }
            chromeLabel(title: "Colors", systemName: "paintpalette") {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showColorPanel.toggle()
                }
            }
            chromeLabel(title: "Models", systemName: "cube.transparent") {}

            if showToolsPanel {
                toolsPanel
            }

            Spacer()

            chromeLabel(title: "Surface", systemName: "applepencil.tip") {}
            chromeLabel(title: "Hover", systemName: "hand.draw") {}
        }
    }

    private var rightChrome: some View {
        VStack(alignment: .trailing, spacing: 12) {
            WorkspaceNavigationCluster(camera: $workspaceCamera)

            VStack(alignment: .trailing, spacing: 10) {
                chromeLabel(title: "Pencil", systemName: "applepencil") {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showPencilPanel.toggle()
                    }
                }
                chromeLabel(title: "Pose", systemName: "gyroscope") {}
                chromeLabel(title: "Session", systemName: "clock.arrow.circlepath") {}
            }

            if showPencilPanel {
                pencilPanel
            }

            if showColorPanel {
                colorPlanPanel
            }

            Spacer()
        }
    }

    private var bottomChrome: some View {
        HStack {
            floatingStatus
            Spacer()
        }
    }

    private var toolsPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(PaintingTool.allCases) { tool in
                Button {
                    store.selectedTool = tool
                } label: {
                    HStack(spacing: 10) {
                        toolIcon(tool)
                        Text(tool.title)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white)
                        Spacer()
                    }
                    .padding(8)
                    .background(Color.white.opacity(store.selectedTool == tool ? 0.12 : 0.04), in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }

            if store.pencilState.paletteVisible {
                Text("Quick palette open")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.62))
            }
        }
        .padding(10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.08), lineWidth: 1))
        .frame(width: 200)
    }

    private var pencilPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            panelRow("Tool", store.selectedTool.title)
            panelRow("Hover", store.pencilState.isHovering ? "Detected" : "Idle")
            panelRow("Squeeze", store.pencilState.squeezeEnabled ? "Triggered" : "Idle")
            panelRow("Double tap", "\(store.pencilState.doubleTapCount)")
            panelRow("Pressure", String(format: "%.2f", store.pencilState.lastPressure))
            panelRow("Roll", "\(Int(store.pencilState.barrelRollAngle * 180 / .pi)) deg")
        }
        .padding(10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.08), lineWidth: 1))
        .frame(width: 220)
    }

    private var colorPlanPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            colorRow("Surface", store.activeProject.sliceSettings.surfaceColor)
            colorRow("Infill", store.activeProject.sliceSettings.infillColor)
            Text("Pencil paints only exterior surfaces.")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.58))
        }
        .padding(10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.08), lineWidth: 1))
        .frame(width: 220)
    }

    private var paintingWorkspace: some View {
        WorkspaceViewport(camera: $workspaceCamera) {
            PaintingGrid()
                .clipShape(RoundedRectangle(cornerRadius: 28))
        } content: {
            GeometryReader { geometry in
                ZStack {
                    modelStage
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    paintSurfaceOverlay

                    if store.selectedModel != nil {
                        ApplePencilCanvasView(
                            onHoverChanged: { location, azimuth, altitude, zOffset, roll in
                                store.handlePencilHover(location: location, azimuth: azimuth, altitude: altitude, zOffset: zOffset, roll: roll)
                            },
                            onStrokeBegan: { location, force, azimuth, roll in
                                store.beginPaintingStroke(at: location, force: force, azimuth: azimuth, roll: roll)
                            },
                            onStrokeMoved: { location, force, azimuth, roll in
                                store.continuePaintingStroke(at: location, force: force, azimuth: azimuth, roll: roll)
                            },
                            onStrokeEnded: {
                                store.endPaintingStroke()
                            },
                            onTap: { location, azimuth, altitude, zOffset, roll in
                                store.handlePencilHover(location: location, azimuth: azimuth, altitude: altitude, zOffset: zOffset, roll: roll)
                                store.handlePencilDoubleTap()
                            },
                            onSqueeze: { location, azimuth, altitude, zOffset, roll in
                                store.handlePencilHover(location: location, azimuth: azimuth, altitude: altitude, zOffset: zOffset, roll: roll)
                                store.handlePencilSqueeze()
                            }
                        )
                    }

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

                    if store.selectedModel == nil {
                        centerHint(
                            icon: "cube.transparent",
                            title: "Select a model in Prepare first",
                            subtitle: "Every loaded model stays in the same 3D workspace."
                        )
                    }

                    if store.selectedModel != nil && store.selectedModelPaintingStrokes.isEmpty && store.activePaintingStroke == nil {
                        centerHint(
                            icon: "applepencil.tip",
                            title: "Hover, squeeze, and paint in 3D",
                            subtitle: "Touch stays for navigation. Apple Pencil edits the selected model surface."
                        )
                        .frame(maxWidth: geometry.size.width * 0.5)
                    }
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if store.selectedModel == nil {
                store.selectModel(store.selectedPlate?.models.first?.id)
            }
        }
    }

    private var modelStage: some View {
        ZStack {
            if let selectedModel = store.selectedModel {
                ModelWorkspaceSceneView(
                    camera: $workspaceCamera,
                    models: [selectedModel],
                    selectedModelID: selectedModel.id,
                    selectedSurfaceSelection: store.selectedSurfaceSelection,
                    surfaceColor: store.activeProject.sliceSettings.surfaceColor,
                    onSelectModel: { modelID in
                        store.selectModel(modelID)
                    },
                    onSelectSurface: { selection in
                        store.selectSurface(selection)
                    },
                    onContextAction: handleModelContextAction
                )
            } else {
                mockModelStage
            }
        }
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
        case let .moveModel(modelID, xDelta, yDelta):
            store.moveModel(modelID, xDelta: xDelta, yDelta: yDelta)
        case let .rotateModel(modelID, degrees):
            store.rotateModel(modelID, by: degrees)
        case let .scaleModel(modelID, percentageDelta):
            store.scaleModel(modelID, by: percentageDelta)
        case let .setModelScale(modelID, percentage):
            store.setModelScale(modelID, percentage: percentage)
        case let .autoOrientModel(modelID):
            store.autoOrientModel(modelID)
        case let .resetModelTransform(modelID):
            store.resetModelTransform(modelID)
        }
    }

    private var mockModelStage: some View {
        GeometryReader { geometry in
            let center = CGPoint(x: geometry.size.width * 0.52, y: geometry.size.height * 0.52)

            ZStack {
                RoundedRectangle(cornerRadius: 24)
                    .stroke(Color.white.opacity(0.04), lineWidth: 1)
                    .frame(width: 320, height: 220)
                    .rotationEffect(.degrees(-12))
                    .position(x: center.x, y: center.y + 60)

                if store.selectedModel != nil {
                    RoundedRectangle(cornerRadius: 22)
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.9), store.activeProject.sliceSettings.surfaceColor.swatch.opacity(0.82)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 120, height: 170)
                        .overlay(
                            RoundedRectangle(cornerRadius: 22)
                                .stroke(Color.white.opacity(0.8), lineWidth: 2)
                        )
                        .rotation3DEffect(.degrees(18), axis: (x: 0, y: 1, z: 0))
                        .position(x: center.x, y: center.y)

                    selectionBracket
                        .position(x: center.x, y: center.y)
                }
            }
        }
    }

    private var selectionBracket: some View {
        RoundedRectangle(cornerRadius: 8)
            .stroke(style: StrokeStyle(lineWidth: 2, dash: [10, 8]))
            .foregroundStyle(.white.opacity(0.9))
            .frame(width: 150, height: 200)
    }

    private var paintSurfaceOverlay: some View {
        GeometryReader { geometry in
            ZStack {
                Canvas { context, _ in
                    for stroke in store.selectedModelPaintingStrokes {
                        draw(stroke: stroke, in: &context)
                    }
                    if let activePaintingStroke = store.activePaintingStroke,
                       activePaintingStroke.modelID == store.selectedModelID {
                        draw(stroke: activePaintingStroke, in: &context)
                    }
                }

                if let hoverLocation = store.pencilState.hoverLocation {
                    HoverPreviewView(
                        tool: store.selectedTool,
                        hoverLocation: hoverLocation,
                        rollAngle: store.pencilState.barrelRollAngle,
                        isActive: store.pencilState.isHovering
                    )
                }
            }
        }
    }

    private var floatingStatus: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(store.pencilState.lastEventSummary)
                .font(.caption.weight(.medium))
                .foregroundStyle(.white)

            Text("Surface marks \(store.selectedModelPaintingStrokes.count)  Infill \(store.activeProject.sliceSettings.infillColor.displayName)")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.58))
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.08), lineWidth: 1))
        .frame(width: 260, alignment: .leading)
    }

    private func draw(stroke: PaintingStroke, in context: inout GraphicsContext) {
        guard let first = stroke.points.first else { return }

        var path = Path()
        path.move(to: first)
        for point in stroke.points.dropFirst() {
            path.addLine(to: point)
        }

        let width = max(4, 8 + (stroke.forceSamples.last ?? 0) * 2)
        context.stroke(
            path,
            with: .color(stroke.color.swatch.opacity(0.92)),
            style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round)
        )
    }

    private func centerHint(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 34))
                .foregroundStyle(.white.opacity(0.85))
            Text(title)
                .font(.headline)
                .foregroundStyle(.white)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.62))
                .multilineTextAlignment(.center)
        }
        .padding(22)
        .background(Color.black.opacity(0.26), in: RoundedRectangle(cornerRadius: 18))
    }

    private func chromeLabel(title: String, systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                roundIconBadge(systemName)
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.9))
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

    private func toolIcon(_ tool: PaintingTool) -> some View {
        Image(systemName: tool.systemImage)
            .foregroundStyle(tool.tint)
            .frame(width: 22)
    }

    private func panelRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(.white.opacity(0.56))
            Spacer()
            Text(value)
                .foregroundStyle(.white)
        }
        .font(.caption2)
    }

    private func colorRow(_ title: String, _ color: PrintColorOption) -> some View {
        HStack {
            Circle()
                .fill(color.swatch)
                .frame(width: 10, height: 10)
            Text(title)
                .foregroundStyle(.white.opacity(0.62))
            Spacer()
            Text(color.displayName)
                .foregroundStyle(.white)
        }
        .font(.caption2)
    }

    private func compactColorSwatch(_ color: PrintColorOption) -> some View {
        Circle()
            .fill(color.swatch)
            .frame(width: 18, height: 18)
            .overlay(Circle().stroke(Color.white.opacity(0.5), lineWidth: 1))
    }

    private func miniTopIcon(_ systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.white.opacity(0.88))
            .frame(width: 28, height: 28)
    }
}

private struct HoverPreviewView: View {
    let tool: PaintingTool
    let hoverLocation: CGPoint
    let rollAngle: CGFloat
    let isActive: Bool

    var body: some View {
        Circle()
            .strokeBorder(tool.tint.opacity(isActive ? 0.9 : 0.3), lineWidth: 2)
            .background(Circle().fill(tool.tint.opacity(0.12)))
            .frame(width: 46, height: 46)
            .overlay {
                Image(systemName: tool.systemImage)
                    .foregroundStyle(tool.tint)
                    .rotationEffect(.radians(Double(rollAngle)))
            }
            .position(hoverLocation)
            .allowsHitTesting(false)
    }
}

private struct PaintingGrid: View {
    var body: some View {
        Canvas { context, size in
            let major = Color.white.opacity(0.07)
            let minor = Color.white.opacity(0.028)

            for x in stride(from: 0, through: size.width, by: 24) {
                var path = Path()
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                context.stroke(path, with: .color(minor), lineWidth: 1)
            }

            for y in stride(from: 0, through: size.height, by: 24) {
                var path = Path()
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                context.stroke(path, with: .color(minor), lineWidth: 1)
            }

            for x in stride(from: 0, through: size.width, by: 96) {
                var path = Path()
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                context.stroke(path, with: .color(major), lineWidth: 1.1)
            }

            for y in stride(from: 0, through: size.height, by: 96) {
                var path = Path()
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                context.stroke(path, with: .color(major), lineWidth: 1.1)
            }
        }
    }
}

private struct PaintTopCapsuleStyle: ButtonStyle {
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
