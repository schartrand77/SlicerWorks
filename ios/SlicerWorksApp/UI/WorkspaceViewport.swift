import SwiftUI

enum WorkspaceInteractionMode: String {
    case orbit
    case pan

    var systemImage: String {
        switch self {
        case .orbit:
            return "rotate.3d"
        case .pan:
            return "hand.draw"
        }
    }

    var title: String {
        switch self {
        case .orbit:
            return "Orbit"
        case .pan:
            return "Pan"
        }
    }
}

struct WorkspaceCamera {
    var pitch: Double = 58
    var yaw: Double = -16
    var zoom: CGFloat = 1
    var pan: CGSize = .zero
    var interactionMode: WorkspaceInteractionMode = .orbit

    mutating func reset() {
        pitch = 58
        yaw = -16
        zoom = 1
        pan = .zero
        interactionMode = .orbit
    }
}

struct WorkspaceViewport<Background: View, Content: View>: View {
    @Binding var camera: WorkspaceCamera
    @State private var dragStartCamera: WorkspaceCamera?
    @State private var magnifyStartZoom: CGFloat?

    let background: () -> Background
    let content: () -> Content

    init(
        camera: Binding<WorkspaceCamera>,
        @ViewBuilder background: @escaping () -> Background,
        @ViewBuilder content: @escaping () -> Content
    ) {
        _camera = camera
        self.background = background
        self.content = content
    }

    var body: some View {
        GeometryReader { geometry in
            let stageSize = geometry.size

            ZStack {
                background()

                ZStack {
                    content()
                }
                .offset(camera.pan)
                .scaleEffect(camera.zoom, anchor: .center)
                .rotation3DEffect(.degrees(camera.pitch), axis: (x: 1, y: 0, z: 0), perspective: 0.8)
                .rotation3DEffect(.degrees(camera.yaw), axis: (x: 0, y: 1, z: 0), perspective: 0.8)
                .shadow(color: .black.opacity(0.18), radius: 40, y: 22)
            }
            .contentShape(Rectangle())
            .gesture(dragGesture(for: stageSize))
            .simultaneousGesture(magnifyGesture)
            .onTapGesture(count: 2) {
                withAnimation(.spring(response: 0.24, dampingFraction: 0.88)) {
                    camera.reset()
                }
            }
            .animation(.easeOut(duration: 0.12), value: camera.pitch)
            .animation(.easeOut(duration: 0.12), value: camera.yaw)
            .animation(.easeOut(duration: 0.12), value: camera.zoom)
            .animation(.easeOut(duration: 0.12), value: camera.pan)
        }
    }

    private func dragGesture(for size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { value in
                if dragStartCamera == nil {
                    dragStartCamera = camera
                }

                guard let start = dragStartCamera else { return }
                let translation = value.translation

                switch camera.interactionMode {
                case .orbit:
                    camera.yaw = start.yaw + Double(translation.width / max(size.width, 1)) * 140
                    camera.pitch = start.pitch - Double(translation.height / max(size.height, 1)) * 120
                case .pan:
                    camera.pan = CGSize(
                        width: start.pan.width + translation.width,
                        height: start.pan.height + translation.height
                    )
                }
            }
            .onEnded { _ in
                dragStartCamera = nil
            }
    }

    private var magnifyGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                if magnifyStartZoom == nil {
                    magnifyStartZoom = camera.zoom
                }

                let startZoom = magnifyStartZoom ?? camera.zoom
                camera.zoom = min(max(startZoom * value.magnification, 0.55), 2.4)
            }
            .onEnded { _ in
                magnifyStartZoom = nil
            }
    }
}

struct WorkspaceNavigationCluster: View {
    @Binding var camera: WorkspaceCamera

    var body: some View {
        VStack(alignment: .trailing, spacing: 10) {
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.08))
                .frame(width: 62, height: 62)
                .overlay(
                    VStack(spacing: 2) {
                        Text(cubePrimaryLabel)
                            .font(.caption2.weight(.bold))
                        Text(cubeSecondaryLabel)
                            .font(.caption2)
                    }
                    .foregroundStyle(.white.opacity(0.8))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
                .onTapGesture(count: 2) {
                    withAnimation(.spring(response: 0.24, dampingFraction: 0.88)) {
                        camera.reset()
                    }
                }

            VStack(spacing: 8) {
                navigationButton(mode: .orbit)
                navigationButton(mode: .pan)
                navigationActionButton("plus.magnifyingglass") {
                    camera.zoom = min(camera.zoom + 0.14, 2.4)
                }
                navigationActionButton("arrow.counterclockwise") {
                    withAnimation(.spring(response: 0.24, dampingFraction: 0.88)) {
                        camera.reset()
                    }
                }
            }

            WorkspaceXYZDiagram(camera: camera)
        }
    }

    private var cubePrimaryLabel: String {
        camera.pitch > 48 ? "Top" : "Front"
    }

    private var cubeSecondaryLabel: String {
        camera.yaw >= 0 ? "Right" : "Left"
    }

    private func navigationButton(mode: WorkspaceInteractionMode) -> some View {
        Button {
            camera.interactionMode = mode
        } label: {
            Image(systemName: mode.systemImage)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white.opacity(camera.interactionMode == mode ? 1 : 0.78))
                .frame(width: 34, height: 34)
                .background(
                    (camera.interactionMode == mode ? Color.blue.opacity(0.76) : Color.white.opacity(0.08)),
                    in: RoundedRectangle(cornerRadius: 11)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 11)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private func navigationActionButton(_ systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
                .frame(width: 34, height: 34)
                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 11))
                .overlay(
                    RoundedRectangle(cornerRadius: 11)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

struct WorkspaceXYZDiagram: View {
    let camera: WorkspaceCamera

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.black.opacity(0.32))
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.1), lineWidth: 1))

            Canvas { context, size in
                let origin = CGPoint(x: 22, y: size.height - 20)
                let xLength: CGFloat = 30 * camera.zoom
                let yLength: CGFloat = 24 * camera.zoom
                let zLength: CGFloat = 30 * camera.zoom

                var zAxis = Path()
                zAxis.move(to: origin)
                zAxis.addLine(to: CGPoint(x: origin.x, y: origin.y - zLength))
                context.stroke(zAxis, with: .color(.blue.opacity(0.9)), lineWidth: 2)

                var xAxis = Path()
                xAxis.move(to: origin)
                xAxis.addLine(to: CGPoint(x: origin.x + xLength, y: origin.y))
                context.stroke(xAxis, with: .color(.red.opacity(0.9)), lineWidth: 2)

                var yAxis = Path()
                yAxis.move(to: origin)
                yAxis.addLine(to: CGPoint(x: origin.x + yLength, y: origin.y - yLength))
                context.stroke(yAxis, with: .color(.green.opacity(0.9)), lineWidth: 2)

                context.draw(Text("Z").font(.caption.bold()).foregroundColor(.blue.opacity(0.95)), at: CGPoint(x: origin.x, y: origin.y - zLength - 10))
                context.draw(Text("X").font(.caption.bold()).foregroundColor(.red.opacity(0.95)), at: CGPoint(x: origin.x + xLength + 10, y: origin.y))
                context.draw(Text("Y").font(.caption.bold()).foregroundColor(.green.opacity(0.95)), at: CGPoint(x: origin.x + yLength + 8, y: origin.y - yLength - 6))
            }
            .padding(6)
        }
        .frame(width: 92, height: 92)
    }
}
