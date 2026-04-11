import SwiftUI
import UIKit

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
    static let minimumZoom: CGFloat = 0.55
    static let maximumZoom: CGFloat = 2.4

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

    mutating func applyDrag(from start: WorkspaceCamera, translation: CGSize, in size: CGSize) {
        switch interactionMode {
        case .orbit:
            yaw = start.yaw + Double(translation.width / max(size.width, 1)) * 140
            pitch = start.pitch - Double(translation.height / max(size.height, 1)) * 120
        case .pan:
            pan = CGSize(
                width: start.pan.width + translation.width,
                height: start.pan.height + translation.height
            )
        }
    }

    mutating func applyMagnification(from startZoom: CGFloat, magnification: CGFloat) {
        zoom = min(max(startZoom * magnification, Self.minimumZoom), Self.maximumZoom)
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

                WorkspaceIndirectInputOverlay(
                    camera: $camera,
                    viewportSize: stageSize
                )
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
                camera.applyDrag(from: start, translation: value.translation, in: size)
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
                camera.applyMagnification(from: startZoom, magnification: value.magnification)
            }
            .onEnded { _ in
                magnifyStartZoom = nil
            }
    }
}

struct WorkspaceIndirectInputOverlay: UIViewRepresentable {
    @Binding var camera: WorkspaceCamera
    let viewportSize: CGSize

    func makeCoordinator() -> Coordinator {
        Coordinator(camera: $camera, viewportSize: viewportSize)
    }

    func makeUIView(context: Context) -> WorkspaceIndirectInputView {
        let view = WorkspaceIndirectInputView()
        view.coordinator = context.coordinator
        return view
    }

    func updateUIView(_ uiView: WorkspaceIndirectInputView, context: Context) {
        context.coordinator.camera = $camera
        context.coordinator.viewportSize = viewportSize
        uiView.coordinator = context.coordinator
    }

    final class Coordinator {
        var camera: Binding<WorkspaceCamera>
        var viewportSize: CGSize
        var dragStartCamera: WorkspaceCamera?
        var magnifyStartZoom: CGFloat?

        init(camera: Binding<WorkspaceCamera>, viewportSize: CGSize) {
            self.camera = camera
            self.viewportSize = viewportSize
        }

        func handlePanChanged(_ recognizer: UIPanGestureRecognizer) {
            if dragStartCamera == nil {
                dragStartCamera = camera.wrappedValue
            }

            guard let start = dragStartCamera else { return }
            let translation = recognizer.translation(in: recognizer.view)
            var updatedCamera = camera.wrappedValue
            updatedCamera.applyDrag(
                from: start,
                translation: CGSize(width: translation.x, height: translation.y),
                in: viewportSize
            )
            camera.wrappedValue = updatedCamera
        }

        func handlePanEnded() {
            dragStartCamera = nil
        }

        func handlePinchChanged(_ recognizer: UIPinchGestureRecognizer) {
            if magnifyStartZoom == nil {
                magnifyStartZoom = camera.wrappedValue.zoom
            }

            let startZoom = magnifyStartZoom ?? camera.wrappedValue.zoom
            var updatedCamera = camera.wrappedValue
            updatedCamera.applyMagnification(from: startZoom, magnification: recognizer.scale)
            camera.wrappedValue = updatedCamera
        }

        func handlePinchEnded() {
            magnifyStartZoom = nil
        }
    }
}

final class WorkspaceIndirectInputView: UIView, UIGestureRecognizerDelegate {
    var coordinator: WorkspaceIndirectInputOverlay.Coordinator?

    private lazy var panGestureRecognizer: UIPanGestureRecognizer = {
        let recognizer = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        recognizer.allowedTouchTypes = [NSNumber(value: UITouch.TouchType.indirectPointer.rawValue)]
        recognizer.delegate = self
        return recognizer
    }()

    private lazy var pinchGestureRecognizer: UIPinchGestureRecognizer = {
        let recognizer = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        recognizer.allowedTouchTypes = [NSNumber(value: UITouch.TouchType.indirectPointer.rawValue)]
        recognizer.delegate = self
        return recognizer
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isOpaque = false
        addGestureRecognizer(panGestureRecognizer)
        addGestureRecognizer(pinchGestureRecognizer)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        true
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        true
    }

    @objc
    private func handlePan(_ recognizer: UIPanGestureRecognizer) {
        switch recognizer.state {
        case .began, .changed:
            coordinator?.handlePanChanged(recognizer)
        default:
            coordinator?.handlePanEnded()
        }
    }

    @objc
    private func handlePinch(_ recognizer: UIPinchGestureRecognizer) {
        switch recognizer.state {
        case .began, .changed:
            coordinator?.handlePinchChanged(recognizer)
        default:
            coordinator?.handlePinchEnded()
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
                    camera.zoom = min(camera.zoom + 0.14, WorkspaceCamera.maximumZoom)
                }
                navigationActionButton("arrow.counterclockwise") {
                    withAnimation(.spring(response: 0.24, dampingFraction: 0.88)) {
                        camera.reset()
                    }
                }
            }

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
                let origin = CGPoint(x: size.width * 0.5, y: size.height * 0.58)
                let axisLength: CGFloat = 31
                let xAxisPoint = projectedAxisEndpoint(axis: (x: 1, y: 0, z: 0), origin: origin, length: axisLength)
                let yAxisPoint = projectedAxisEndpoint(axis: (x: 0, y: 0, z: 1), origin: origin, length: axisLength)
                let zAxisPoint = projectedAxisEndpoint(axis: (x: 0, y: 1, z: 0), origin: origin, length: axisLength)

                var zAxis = Path()
                zAxis.move(to: origin)
                zAxis.addLine(to: zAxisPoint)
                context.stroke(zAxis, with: .color(.blue.opacity(0.9)), lineWidth: 2)

                var xAxis = Path()
                xAxis.move(to: origin)
                xAxis.addLine(to: xAxisPoint)
                context.stroke(xAxis, with: .color(.red.opacity(0.9)), lineWidth: 2)

                var yAxis = Path()
                yAxis.move(to: origin)
                yAxis.addLine(to: yAxisPoint)
                context.stroke(yAxis, with: .color(.green.opacity(0.9)), lineWidth: 2)

                context.draw(Text("Z").font(.caption.bold()).foregroundColor(.blue.opacity(0.95)), at: labelPoint(for: zAxisPoint, from: origin))
                context.draw(Text("X").font(.caption.bold()).foregroundColor(.red.opacity(0.95)), at: labelPoint(for: xAxisPoint, from: origin))
                context.draw(Text("Y").font(.caption.bold()).foregroundColor(.green.opacity(0.95)), at: labelPoint(for: yAxisPoint, from: origin))
            }
            .padding(6)
        }
        .frame(width: 92, height: 92)
    }

    private func projectedAxisEndpoint(axis: (x: CGFloat, y: CGFloat, z: CGFloat), origin: CGPoint, length: CGFloat) -> CGPoint {
        let pitch = CGFloat(camera.pitch * .pi / 180)
        let yaw = CGFloat(camera.yaw * .pi / 180)

        let pitchedY = axis.y * cos(pitch) - axis.z * sin(pitch)
        let pitchedZ = axis.y * sin(pitch) + axis.z * cos(pitch)
        let rotatedX = axis.x * cos(yaw) + pitchedZ * sin(yaw)
        let rotatedY = pitchedY

        return CGPoint(
            x: origin.x + rotatedX * length,
            y: origin.y - rotatedY * length
        )
    }

    private func labelPoint(for endpoint: CGPoint, from origin: CGPoint) -> CGPoint {
        let dx = endpoint.x - origin.x
        let dy = endpoint.y - origin.y
        let distance = max(sqrt(dx * dx + dy * dy), 0.001)

        return CGPoint(
            x: endpoint.x + dx / distance * 10,
            y: endpoint.y + dy / distance * 10
        )
    }
}
