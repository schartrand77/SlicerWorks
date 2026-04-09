import SwiftUI

struct ModelPaintingView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        ViewThatFits(in: .horizontal) {
            wideLayout
            compactLayout
        }
        .navigationTitle("Paint")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(red: 0.95, green: 0.95, blue: 0.93))
    }

    private var wideLayout: some View {
        HStack(spacing: 16) {
            toolRail
                .frame(width: 240)

            paintingWorkspace

            pencilInspector
                .frame(width: 300)
        }
        .padding(16)
    }

    private var compactLayout: some View {
        ScrollView {
            VStack(spacing: 16) {
                paintingWorkspace
                    .frame(height: 520)
                toolRail
                pencilInspector
            }
            .padding(16)
        }
    }

    private var toolRail: some View {
        VStack(alignment: .leading, spacing: 16) {
            panelHeader("Tools", subtitle: "Double-tap cycles tools")

            ForEach(PaintingTool.allCases) { tool in
                Button {
                    store.selectedTool = tool
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: tool.systemImage)
                            .frame(width: 28)
                            .foregroundStyle(tool.tint)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(tool.title)
                                .font(.headline)
                            Text(tool == store.selectedTool ? "Active" : "Available")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(12)
                    .background(store.selectedTool == tool ? tool.tint.opacity(0.18) : Color.white.opacity(0.9), in: RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.plain)
            }

            if store.pencilState.paletteVisible {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Quick Palette")
                        .font(.headline)
                    Text("Squeeze exposed the quick tool palette.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("Preferred tap: \(preferredTapActionLabel)")
                    if #available(iOS 17.5, *) {
                        Text("Preferred squeeze: \(preferredSqueezeActionLabel)")
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white.opacity(0.9), in: RoundedRectangle(cornerRadius: 16))
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Color Plan")
                    .font(.headline)

                colorPickerRow(
                    title: "Surface",
                    subtitle: "Pencil paints only exterior faces",
                    selection: $store.activeProject.sliceSettings.surfaceColor
                )

                colorPickerRow(
                    title: "Infill",
                    subtitle: "Separate choice to avoid accidental time increase",
                    selection: $store.activeProject.sliceSettings.infillColor
                )

                Text("Interior infill is never painted by the Pencil surface tools.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.9), in: RoundedRectangle(cornerRadius: 16))

            Button("Clear painted marks") {
                store.clearSelectedModelPainting()
            }
            .buttonStyle(.bordered)

            Spacer()
        }
        .padding(16)
        .background(Color(red: 0.90, green: 0.91, blue: 0.88), in: RoundedRectangle(cornerRadius: 24))
    }

    private var paintingWorkspace: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28)
                .fill(Color(red: 0.83, green: 0.85, blue: 0.82))

            PaintingGrid()
                .clipShape(RoundedRectangle(cornerRadius: 28))

            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.black.opacity(0.12), lineWidth: 1)
                .padding(24)

            paintSurfaceOverlay

            if store.selectedModel != nil {
                ApplePencilCanvasView(
                    onHoverChanged: { location, azimuth, altitude, zOffset, roll in
                        store.handlePencilHover(
                            location: location,
                            azimuth: azimuth,
                            altitude: altitude,
                            zOffset: zOffset,
                            roll: roll
                        )
                    },
                    onStrokeBegan: { location, force, azimuth, roll in
                        store.beginPaintingStroke(
                            at: location,
                            force: force,
                            azimuth: azimuth,
                            roll: roll
                        )
                    },
                    onStrokeMoved: { location, force, azimuth, roll in
                        store.continuePaintingStroke(
                            at: location,
                            force: force,
                            azimuth: azimuth,
                            roll: roll
                        )
                    },
                    onStrokeEnded: {
                        store.endPaintingStroke()
                    },
                    onTap: { location, azimuth, altitude, zOffset, roll in
                        store.handlePencilHover(
                            location: location,
                            azimuth: azimuth,
                            altitude: altitude,
                            zOffset: zOffset,
                            roll: roll
                        )
                        store.handlePencilDoubleTap()
                    },
                    onSqueeze: { location, azimuth, altitude, zOffset, roll in
                        store.handlePencilHover(
                            location: location,
                            azimuth: azimuth,
                            altitude: altitude,
                            zOffset: zOffset,
                            roll: roll
                        )
                        store.handlePencilSqueeze()
                    }
                )
            }
        }
        .overlay(alignment: .topLeading) {
            Text("Apple Pencil Pro Surface")
                .font(.headline)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color.black.opacity(0.75), in: Capsule())
                .foregroundStyle(.white)
                .padding(24)
        }
        .shadow(color: .black.opacity(0.08), radius: 20, y: 10)
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

                if store.selectedModel == nil {
                    VStack(spacing: 10) {
                        Image(systemName: "cube.transparent")
                            .font(.system(size: 40))
                        Text("Select a model in the Slice workspace first.")
                            .font(.headline)
                        Text("Apple Pencil painting attaches to the currently selected model.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(24)
                    .background(Color.white.opacity(0.78), in: RoundedRectangle(cornerRadius: 20))
                    .frame(maxWidth: geometry.size.width * 0.66)
                } else if store.selectedModelPaintingStrokes.isEmpty && store.activePaintingStroke == nil {
                    VStack(spacing: 10) {
                        Image(systemName: "applepencil.tip")
                            .font(.system(size: 40))
                        Text("Hover, tap, squeeze, and paint directly on the surface.")
                            .font(.headline)
                        Text("Double-tap cycles tools. Squeeze toggles the quick palette. Barrel roll rotates the brush indicator. Infill color is controlled separately.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(24)
                    .background(Color.white.opacity(0.78), in: RoundedRectangle(cornerRadius: 20))
                    .frame(maxWidth: geometry.size.width * 0.66)
                }
            }
        }
    }

    private var pencilInspector: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                panelHeader("Pencil", subtitle: "Hover, tap, squeeze, roll")

                statusCard(title: "Current Tool", value: store.selectedTool.title, accent: store.selectedTool.tint)
                statusCard(title: "Surface Color", value: store.activeProject.sliceSettings.surfaceColor.displayName, accent: store.activeProject.sliceSettings.surfaceColor.swatch)
                statusCard(title: "Infill Color", value: store.activeProject.sliceSettings.infillColor.displayName, accent: store.activeProject.sliceSettings.infillColor.swatch)
                statusCard(title: "Hover", value: store.pencilState.isHovering ? "Detected" : "Idle", accent: .blue)
                statusCard(title: "Squeeze", value: store.pencilState.squeezeEnabled ? "Triggered" : "Idle", accent: .orange)
                statusCard(title: "Double Tap Count", value: "\(store.pencilState.doubleTapCount)", accent: .mint)

                inspectorGroup("Painting Safety") {
                    Text("Paint target: Surface only")
                    Text("Infill color: \(store.activeProject.sliceSettings.infillColor.displayName)")
                    Text("Changing infill is explicit so coloring the outside never silently adds hours of print time.")
                }

                if let selectedModel = store.selectedModel {
                    inspectorGroup("Selected Workspace Model") {
                        Text(selectedModel.name)
                        Text("Surface marks \(store.selectedModelPaintingStrokes.count)")
                        Text("Surface color \(store.activeProject.sliceSettings.surfaceColor.displayName)")
                        Text("Infill color \(store.activeProject.sliceSettings.infillColor.displayName)")
                    }
                }

                inspectorGroup("Pose") {
                    Text("Roll \(Int(store.pencilState.barrelRollAngle * 180 / .pi)) deg")
                    Text("Azimuth \(Int(store.pencilState.hoverAzimuthAngle * 180 / .pi)) deg")
                    Text("Altitude \(Int(store.pencilState.hoverAltitudeAngle * 180 / .pi)) deg")
                    Text("Z offset \(String(format: "%.2f", store.pencilState.hoverZOffset))")
                    Text("Pressure \(String(format: "%.2f", store.pencilState.lastPressure))")
                }

                inspectorGroup("Session") {
                    Text(store.pencilState.lastEventSummary)
                    Text("Committed strokes \(store.selectedModelPaintingStrokes.count)")
                    if let lastContactLocation = store.pencilState.lastContactLocation {
                        Text("Last contact \(Int(lastContactLocation.x)), \(Int(lastContactLocation.y))")
                    }
                    if let hoverLocation = store.pencilState.hoverLocation {
                        Text("Hover \(Int(hoverLocation.x)), \(Int(hoverLocation.y))")
                    }
                }

                if store.pencilState.paletteVisible {
                    inspectorGroup("Quick Palette") {
                        ForEach(PaintingTool.allCases) { tool in
                            HStack {
                                Image(systemName: tool.systemImage)
                                    .foregroundStyle(tool.tint)
                                Text(tool.title)
                                Spacer()
                                if tool == store.selectedTool {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(tool.tint)
                                }
                            }
                        }
                    }
                }
            }
            .padding(16)
        }
        .background(Color(red: 0.90, green: 0.91, blue: 0.88), in: RoundedRectangle(cornerRadius: 24))
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

    private func colorPickerRow(
        title: String,
        subtitle: String,
        selection: Binding<PrintColorOption>
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
            Picker(title, selection: selection) {
                ForEach(PrintColorOption.allCases) { color in
                    HStack {
                        Circle()
                            .fill(color.swatch)
                            .frame(width: 10, height: 10)
                        Text(color.displayName)
                    }
                    .tag(color)
                }
            }
        }
    }

    private func panelHeader(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.title3.weight(.semibold))
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private func inspectorGroup<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.9), in: RoundedRectangle(cornerRadius: 18))
    }

    private func statusCard(title: String, value: String, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(accent.opacity(0.14), in: RoundedRectangle(cornerRadius: 18))
    }

    private var preferredTapActionLabel: String {
        actionLabel(for: UIPencilInteraction.preferredTapAction)
    }

    private var preferredSqueezeActionLabel: String {
        if #available(iOS 17.5, *) {
            return actionLabel(for: UIPencilInteraction.preferredSqueezeAction)
        }
        return "Unavailable"
    }

    private func actionLabel(for action: UIPencilPreferredAction) -> String {
        switch action {
        case .ignore: return "Ignore"
        case .switchEraser: return "Switch Eraser"
        case .switchPrevious: return "Switch Previous"
        case .showColorPalette: return "Show Color Palette"
        case .showInkAttributes: return "Show Ink Attributes"
        case .showContextualPalette: return "Show Contextual Palette"
        case .runSystemShortcut: return "Run Shortcut"
        @unknown default: return "Unknown"
        }
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
            let major = Color.black.opacity(0.10)
            let minor = Color.black.opacity(0.04)

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
                context.stroke(path, with: .color(major), lineWidth: 1.25)
            }

            for y in stride(from: 0, through: size.height, by: 96) {
                var path = Path()
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                context.stroke(path, with: .color(major), lineWidth: 1.25)
            }
        }
    }
}
