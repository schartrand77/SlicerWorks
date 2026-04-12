import SceneKit
import SwiftUI
import UIKit

enum ModelWorkspaceContextAction {
    case selectModel(PlacedModel.ID?)
    case duplicateModel(PlacedModel.ID)
    case deleteModel(PlacedModel.ID)
    case centerModel(PlacedModel.ID)
    case moveModel(PlacedModel.ID, xDelta: Double, yDelta: Double)
    case rotateModel(PlacedModel.ID, degrees: Double)
    case scaleModel(PlacedModel.ID, percentageDelta: Int)
    case setModelScale(PlacedModel.ID, percentage: Int)
    case autoOrientModel(PlacedModel.ID)
    case resetModelTransform(PlacedModel.ID)
}

struct ModelWorkspaceSceneView: UIViewRepresentable {
    @Binding var camera: WorkspaceCamera
    let models: [PlacedModel]
    let selectedModelID: PlacedModel.ID?
    let selectedSurfaceSelection: ModelSurfaceSelection?
    let surfaceColor: PrintColorOption
    let onSelectModel: (PlacedModel.ID?) -> Void
    let onSelectSurface: (ModelSurfaceSelection?) -> Void
    var onContextAction: (ModelWorkspaceContextAction) -> Void = { _ in }

    func makeCoordinator() -> Coordinator {
        Coordinator(
            camera: $camera,
            selectedModelID: selectedModelID,
            selectedSurfaceSelection: selectedSurfaceSelection,
            onSelectModel: onSelectModel,
            onSelectSurface: onSelectSurface,
            onContextAction: onContextAction
        )
    }

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.backgroundColor = .clear
        view.allowsCameraControl = true
        view.autoenablesDefaultLighting = false
        view.delegate = context.coordinator
        view.scene = makeScene(context: context)

        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        if #available(iOS 13.4, *) {
            tapGesture.buttonMaskRequired = .primary
        }
        view.addGestureRecognizer(tapGesture)

        let doubleTapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleDoubleTap(_:)))
        doubleTapGesture.numberOfTapsRequired = 2
        if #available(iOS 13.4, *) {
            doubleTapGesture.buttonMaskRequired = .primary
        }
        view.addGestureRecognizer(doubleTapGesture)
        tapGesture.require(toFail: doubleTapGesture)

        let zoomGesture = UIPinchGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleCameraZoom(_:))
        )
        zoomGesture.cancelsTouchesInView = false
        zoomGesture.delegate = context.coordinator
        view.addGestureRecognizer(zoomGesture)

        let panGesture = UIPanGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleModelPan(_:))
        )
        panGesture.maximumNumberOfTouches = 1
        panGesture.cancelsTouchesInView = false
        panGesture.delegate = context.coordinator
        if #available(iOS 13.4, *) {
            panGesture.allowedScrollTypesMask = []
        }
        view.addGestureRecognizer(panGesture)

        let rotationGesture = UIRotationGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleModelRotation(_:))
        )
        rotationGesture.cancelsTouchesInView = false
        rotationGesture.delegate = context.coordinator
        view.addGestureRecognizer(rotationGesture)

        if #available(iOS 13.4, *) {
            let secondaryClickGesture = UITapGestureRecognizer(
                target: context.coordinator,
                action: #selector(Coordinator.handleSecondaryClick(_:))
            )
            secondaryClickGesture.name = Coordinator.secondaryClickGestureName
            secondaryClickGesture.buttonMaskRequired = .secondary
            secondaryClickGesture.cancelsTouchesInView = false
            secondaryClickGesture.delegate = context.coordinator
            view.addGestureRecognizer(secondaryClickGesture)

            let scrollZoomGesture = UIPanGestureRecognizer(
                target: context.coordinator,
                action: #selector(Coordinator.handleCameraScroll(_:))
            )
            scrollZoomGesture.allowedScrollTypesMask = [.continuous, .discrete]
            scrollZoomGesture.cancelsTouchesInView = false
            scrollZoomGesture.delegate = context.coordinator
            view.addGestureRecognizer(scrollZoomGesture)
        }
        let longPressGesture = UILongPressGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleLongPress(_:))
        )
        longPressGesture.minimumPressDuration = 0.42
        longPressGesture.cancelsTouchesInView = false
        longPressGesture.delegate = context.coordinator
        view.addGestureRecognizer(longPressGesture)
        view.installPencilInteraction(delegate: context.coordinator)
        context.coordinator.sceneView = view
        context.coordinator.installPencilFrameRateLock(for: view)
        syncModelNodes(context: context)

        return view
    }

    func updateUIView(_ view: SCNView, context: Context) {
        context.coordinator.camera = $camera
        context.coordinator.selectedModelID = selectedModelID
        context.coordinator.selectedSurfaceSelection = selectedSurfaceSelection
        context.coordinator.onSelectModel = onSelectModel
        context.coordinator.onSelectSurface = onSelectSurface
        context.coordinator.onContextAction = onContextAction
        context.coordinator.sceneView = view
        syncModelNodes(context: context)
        context.coordinator.updateSelection(
            selectedModelID: selectedModelID,
            selectedSurfaceSelection: selectedSurfaceSelection
        )
    }

    private func makeScene(context: Context) -> SCNScene {
        let scene = SCNScene()
        scene.background.contents = UIColor.clear

        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.camera?.zNear = 0.1
        cameraNode.camera?.zFar = 2000
        cameraNode.position = SCNVector3(0, 180, 300)
        cameraNode.eulerAngles = SCNVector3(-Float.pi / 5.2, 0, 0)
        scene.rootNode.addChildNode(cameraNode)
        context.coordinator.cameraNode = cameraNode

        let keyLight = SCNNode()
        keyLight.light = SCNLight()
        keyLight.light?.type = .omni
        keyLight.light?.intensity = 820
        keyLight.position = SCNVector3(-120, 220, 140)
        scene.rootNode.addChildNode(keyLight)

        let fillLight = SCNNode()
        fillLight.light = SCNLight()
        fillLight.light?.type = .ambient
        fillLight.light?.intensity = 420
        fillLight.light?.color = UIColor(white: 0.88, alpha: 1)
        scene.rootNode.addChildNode(fillLight)

        scene.rootNode.addChildNode(makeBuildPlateNode())

        let modelRootNode = SCNNode()
        modelRootNode.name = "ModelWorkspaceSceneView.models"
        scene.rootNode.addChildNode(modelRootNode)
        context.coordinator.modelRootNode = modelRootNode

        return scene
    }

    private func syncModelNodes(context: Context) {
        guard let modelRootNode = context.coordinator.modelRootNode else { return }

        let modelIDs = Set(models.map(\.id))
        for (modelID, node) in context.coordinator.modelNodesByID where modelIDs.contains(modelID) == false {
            node.removeFromParentNode()
            context.coordinator.modelNodesByID[modelID] = nil
            context.coordinator.modelImportScalesByID[modelID] = nil
            context.coordinator.modelSketchOperationsByID[modelID] = nil
            context.coordinator.modelScalePercentsByID[modelID] = nil
        }

        context.coordinator.modelIDsByNodeName.removeAll()
        for model in models {
            let node: SCNNode
            if let existingNode = context.coordinator.modelNodesByID[model.id] {
                node = existingNode
            } else {
                node = makeModelNode(for: model)
                context.coordinator.modelNodesByID[model.id] = node
                context.coordinator.modelImportScalesByID[model.id] = node.scale.x / max(Float(model.scalePercent) / 100, 0.0001)
                modelRootNode.addChildNode(node)
            }

            node.name = model.id.uuidString
            node.enumerateChildNodes { child, _ in
                guard child.name != "ModelWorkspaceSceneView.selectionOutline",
                      child.name != Coordinator.surfaceHighlightNodeName else {
                    return
                }
                child.name = model.id.uuidString
            }
            context.coordinator.modelIDsByNodeName[model.id.uuidString] = model.id
            context.coordinator.modelSketchOperationsByID[model.id] = model.generatedShape?.operation
            context.coordinator.modelScalePercentsByID[model.id] = model.scalePercent
            applyTransform(to: node, for: model, importScale: context.coordinator.modelImportScalesByID[model.id] ?? 1)
            node.applyDefaultMaterial(
                surfaceColor: UIColor(hex: surfaceColor.hex),
                isSelected: selectedModelID == model.id && selectedSurfaceSelection?.modelID != model.id
            )
        }
    }

    private func makeBuildPlateNode() -> SCNNode {
        let plate = SCNBox(width: 256, height: 2, length: 256, chamferRadius: 2)
        let material = SCNMaterial()
        material.diffuse.contents = UIColor.white.withAlphaComponent(0.08)
        material.emission.contents = UIColor.white.withAlphaComponent(0.02)
        plate.materials = [material]

        let node = SCNNode(geometry: plate)
        node.position = SCNVector3(0, -1, 0)

        node.addChildNode(makeGridNode())

        return node
    }

    private func makeGridNode() -> SCNNode {
        let gridRoot = SCNNode()
        gridRoot.name = "ModelWorkspaceSceneView.buildPlateGrid"

        let lineMaterial = SCNMaterial()
        lineMaterial.diffuse.contents = UIColor.white.withAlphaComponent(0.10)
        lineMaterial.emission.contents = UIColor.white.withAlphaComponent(0.04)
        lineMaterial.lightingModel = .constant
        lineMaterial.isDoubleSided = true

        let halfPlate: Float = 128
        let lineCount = 16
        let lineThickness: CGFloat = 0.35

        for index in 0...lineCount {
            let offset = -halfPlate + Float(index) * (halfPlate * 2 / Float(lineCount))

            let xLine = SCNBox(width: CGFloat(halfPlate * 2), height: lineThickness, length: lineThickness, chamferRadius: 0)
            xLine.materials = [lineMaterial]
            let xNode = SCNNode(geometry: xLine)
            xNode.position = SCNVector3(0, 1.12, offset)
            gridRoot.addChildNode(xNode)

            let zLine = SCNBox(width: lineThickness, height: lineThickness, length: CGFloat(halfPlate * 2), chamferRadius: 0)
            zLine.materials = [lineMaterial]
            let zNode = SCNNode(geometry: zLine)
            zNode.position = SCNVector3(offset, 1.13, 0)
            gridRoot.addChildNode(zNode)
        }

        return gridRoot
    }

    private func makeModelNode(for model: PlacedModel) -> SCNNode {
        let isSelected = selectedModelID == model.id
        let sourceNode = generatedShapeNode(for: model, isSelected: isSelected)
            ?? loadModelNode(from: model.sourceURL)
            ?? makeFallbackNode(for: model)

        if model.generatedShape == nil {
            sourceNode.applyDefaultMaterial(
                surfaceColor: UIColor(hex: surfaceColor.hex),
                isSelected: isSelected
            )
        }
        sourceNode.normalizePivotToBottomCenter()

        let bounds = sourceNode.recursiveBoundingBox()
        let maxDimension = max(
            bounds.max.x - bounds.min.x,
            bounds.max.y - bounds.min.y,
            bounds.max.z - bounds.min.z
        )
        let importScale = normalizedImportScale(for: maxDimension)
        applyTransform(to: sourceNode, for: model, importScale: importScale)

        if isSelected {
            sourceNode.addSelectionOutline()
        }

        return sourceNode
    }

    private func generatedShapeNode(for model: PlacedModel, isSelected: Bool) -> SCNNode? {
        guard let shape = model.generatedShape else { return nil }

        let material = SCNMaterial()
        switch shape.operation {
        case .additive:
            material.diffuse.contents = UIColor.systemGreen.withAlphaComponent(isSelected ? 0.86 : 0.70)
            material.emission.contents = UIColor.systemGreen.withAlphaComponent(isSelected ? 0.12 : 0.06)
            material.transparency = 1
        case .negative:
            material.diffuse.contents = UIColor.systemRed.withAlphaComponent(isSelected ? 0.34 : 0.22)
            material.emission.contents = UIColor.systemRed.withAlphaComponent(0.08)
            material.transparency = isSelected ? 0.44 : 0.30
        }
        material.lightingModel = .physicallyBased
        material.isDoubleSided = true

        let node = SCNNode()
        node.name = model.name
        let shapeNode = sketchProfileNode(for: shape)
        shapeNode.geometry?.materials = [material]
        node.addChildNode(shapeNode)

        let label = SCNText(
            string: shape.operation == .negative ? "NEGATIVE" : shape.profile.displayName.uppercased(),
            extrusionDepth: 0.8
        )
        label.font = .systemFont(ofSize: 5, weight: .bold)
        label.flatness = 0.2
        let labelMaterial = SCNMaterial()
        labelMaterial.diffuse.contents = UIColor.white.withAlphaComponent(0.82)
        label.materials = [labelMaterial]
        let labelNode = SCNNode(geometry: label)
        labelNode.position = SCNVector3(
            -Float(shape.widthMM / 2) + 4,
            Float(shape.heightMM / 2) + 2,
            Float(shape.depthMM / 2) + 0.5
        )
        labelNode.eulerAngles.x = -.pi / 2
        node.addChildNode(labelNode)

        return node
    }

    private func sketchProfileNode(for shape: EditableSketchExtrusion) -> SCNNode {
        switch shape.profile {
        case .rectangle:
            let geometry = SCNBox(
                width: CGFloat(shape.widthMM),
                height: CGFloat(shape.heightMM),
                length: CGFloat(shape.depthMM),
                chamferRadius: shape.operation == .negative ? 1.5 : 3
            )
            return SCNNode(geometry: geometry)
        case .cylinder, .circle, .triangle, .hexagon, .octagon:
            let geometry = SCNCylinder(
                radius: CGFloat(max(shape.widthMM, shape.depthMM) / 2),
                height: CGFloat(shape.heightMM)
            )
            geometry.radialSegmentCount = switch shape.profile {
            case .triangle:
                3
            case .hexagon:
                6
            case .octagon:
                8
            default:
                64
            }
            return SCNNode(geometry: geometry)
        case .oval:
            let geometry = SCNCylinder(radius: 1, height: CGFloat(shape.heightMM))
            geometry.radialSegmentCount = 64
            let node = SCNNode(geometry: geometry)
            node.scale = SCNVector3(Float(shape.widthMM / 2), 1, Float(shape.depthMM / 2))
            return node
        }
    }

    private func applyTransform(to node: SCNNode, for model: PlacedModel, importScale: Float) {
        let modelScale = Float(model.scalePercent) / 100 * importScale
        node.scale = SCNVector3(modelScale, modelScale, modelScale)
        node.eulerAngles.y = Float(model.rotationDegrees * .pi / 180)
        node.position = SCNVector3(Float(model.position.x), 0, Float(model.position.y))
    }

    private func loadModelNode(from url: URL) -> SCNNode? {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }

        if url.pathExtension.lowercased() == "stl" {
            return loadSTLNode(from: url)
        }

        guard let scene = try? SCNScene(url: url) else {
            return nil
        }
        let container = SCNNode()

        for child in scene.rootNode.childNodes {
            container.addChildNode(child.clone())
        }

        return container.childNodes.isEmpty ? nil : container
    }

    private func loadSTLNode(from url: URL) -> SCNNode? {
        guard let data = try? Data(contentsOf: url), data.isEmpty == false else {
            return nil
        }

        guard let vertices = binarySTLVertices(from: data) ?? asciiSTLVertices(from: data) else {
            return nil
        }
        guard vertices.count >= 3 else {
            return nil
        }

        let geometrySource = SCNGeometrySource(vertices: vertices)
        let indices: [Int32] = vertices.indices.map(Int32.init)
        let geometryElement = SCNGeometryElement(indices: indices, primitiveType: .triangles)
        let geometry = SCNGeometry(sources: [geometrySource], elements: [geometryElement])

        return SCNNode(geometry: geometry)
    }

    private func binarySTLVertices(from data: Data) -> [SCNVector3]? {
        guard data.count >= 84 else {
            return nil
        }

        let triangleCount = Int(readUInt32(from: data, at: 80))
        let expectedByteCount = 84 + triangleCount * 50
        guard triangleCount > 0, expectedByteCount == data.count else {
            return nil
        }

        var vertices: [SCNVector3] = []
        vertices.reserveCapacity(triangleCount * 3)

        for triangleIndex in 0..<triangleCount {
            let triangleOffset = 84 + triangleIndex * 50
            for vertexIndex in 0..<3 {
                let vertexOffset = triangleOffset + 12 + vertexIndex * 12
                vertices.append(
                    SCNVector3(
                        readFloat32(from: data, at: vertexOffset),
                        readFloat32(from: data, at: vertexOffset + 8),
                        readFloat32(from: data, at: vertexOffset + 4)
                    )
                )
            }
        }

        return vertices
    }

    private func asciiSTLVertices(from data: Data) -> [SCNVector3]? {
        guard let text = String(data: data, encoding: .utf8) else {
            return nil
        }

        let vertices = text
            .split(whereSeparator: \.isNewline)
            .compactMap { line -> SCNVector3? in
                let parts = line.split(whereSeparator: \.isWhitespace)
                guard parts.count == 4, parts[0].lowercased() == "vertex",
                      let x = Float(parts[1]),
                      let y = Float(parts[2]),
                      let z = Float(parts[3]) else {
                    return nil
                }

                return SCNVector3(x, z, y)
            }

        guard vertices.count >= 3 else {
            return nil
        }

        return Array(vertices.prefix(vertices.count - vertices.count % 3))
    }

    private func readUInt32(from data: Data, at offset: Int) -> UInt32 {
        guard offset + 3 < data.count else { return 0 }

        return UInt32(data[offset])
            | UInt32(data[offset + 1]) << 8
            | UInt32(data[offset + 2]) << 16
            | UInt32(data[offset + 3]) << 24
    }

    private func readFloat32(from data: Data, at offset: Int) -> Float {
        Float(bitPattern: readUInt32(from: data, at: offset))
    }

    private func makeFallbackNode(for model: PlacedModel) -> SCNNode {
        let geometry = SCNBox(width: 48, height: 72, length: 48, chamferRadius: 6)
        let node = SCNNode(geometry: geometry)

        let label = SCNText(string: model.sourceURL.pathExtension.uppercased(), extrusionDepth: 1)
        label.font = .systemFont(ofSize: 8, weight: .bold)
        label.flatness = 0.2
        let labelNode = SCNNode(geometry: label)
        labelNode.position = SCNVector3(-14, 40, 24.5)
        labelNode.scale = SCNVector3(1, 1, 1)
        node.addChildNode(labelNode)

        return node
    }

    private func normalizedImportScale(for maxDimension: Float) -> Float {
        guard maxDimension.isFinite, maxDimension > 0 else {
            return 1
        }

        if maxDimension > 180 {
            return 90 / maxDimension
        }

        if maxDimension < 5 {
            return 50 / maxDimension
        }

        return 1
    }

    final class Coordinator: NSObject {
        static let secondaryClickGestureName = "ModelWorkspaceSceneView.secondaryClick"
        static let surfaceHighlightNodeName = "ModelWorkspaceSceneView.surfaceHighlight"

        var camera: Binding<WorkspaceCamera>
        weak var sceneView: SCNView?
        weak var cameraNode: SCNNode?
        weak var modelRootNode: SCNNode?
        var selectedModelID: PlacedModel.ID?
        var selectedSurfaceSelection: ModelSurfaceSelection?
        weak var selectedSurfaceHighlightNode: SCNNode?
        weak var modelActionMenuOverlayView: UIView?
        var modelNodesByID: [PlacedModel.ID: SCNNode] = [:]
        var modelImportScalesByID: [PlacedModel.ID: Float] = [:]
        var modelIDsByNodeName: [String: PlacedModel.ID] = [:]
        var modelSketchOperationsByID: [PlacedModel.ID: SketchExtrusionOperation] = [:]
        var modelScalePercentsByID: [PlacedModel.ID: Int] = [:]
        var activePanModelID: PlacedModel.ID?
        var lastPanPlatePoint: SCNVector3?
        var activeRotationModelID: PlacedModel.ID?
        var lastGestureRotation: CGFloat = 0
        var lastPinchScale: CGFloat = 1
        var lastScrollTranslationY: CGFloat = 0
        private var pencilContactObserver: NSObjectProtocol?
        private var preferredFramesPerSecondBeforePencilContact: Int?
        private var wasPlayingBeforePencilContact: Bool?
        var onSelectModel: (PlacedModel.ID?) -> Void
        var onSelectSurface: (ModelSurfaceSelection?) -> Void
        var onContextAction: (ModelWorkspaceContextAction) -> Void

        init(
            camera: Binding<WorkspaceCamera>,
            selectedModelID: PlacedModel.ID?,
            selectedSurfaceSelection: ModelSurfaceSelection?,
            onSelectModel: @escaping (PlacedModel.ID?) -> Void,
            onSelectSurface: @escaping (ModelSurfaceSelection?) -> Void,
            onContextAction: @escaping (ModelWorkspaceContextAction) -> Void
        ) {
            self.camera = camera
            self.selectedModelID = selectedModelID
            self.selectedSurfaceSelection = selectedSurfaceSelection
            self.onSelectModel = onSelectModel
            self.onSelectSurface = onSelectSurface
            self.onContextAction = onContextAction
        }

        deinit {
            if let pencilContactObserver {
                NotificationCenter.default.removeObserver(pencilContactObserver)
            }
        }

        func installPencilFrameRateLock(for view: SCNView) {
            guard pencilContactObserver == nil else { return }

            pencilContactObserver = NotificationCenter.default.addObserver(
                forName: ApplePencilScreenContactNotification.name,
                object: nil,
                queue: .main
            ) { [weak self, weak view] notification in
                guard let self,
                      let view,
                      let isActive = notification.userInfo?[ApplePencilScreenContactNotification.isActiveKey] as? Bool else {
                    return
                }

                self.setPencilFrameRateLock(isActive, for: view)
            }
        }

        private func setPencilFrameRateLock(_ isActive: Bool, for view: SCNView) {
            if isActive {
                if preferredFramesPerSecondBeforePencilContact == nil {
                    preferredFramesPerSecondBeforePencilContact = view.preferredFramesPerSecond
                    wasPlayingBeforePencilContact = view.isPlaying
                }

                view.preferredFramesPerSecond = 120
                view.isPlaying = true
            } else {
                if let preferredFramesPerSecondBeforePencilContact {
                    view.preferredFramesPerSecond = preferredFramesPerSecondBeforePencilContact
                }
                if let wasPlayingBeforePencilContact {
                    view.isPlaying = wasPlayingBeforePencilContact
                }

                preferredFramesPerSecondBeforePencilContact = nil
                wasPlayingBeforePencilContact = nil
            }
        }

        @objc
        func handleTap(_ recognizer: UITapGestureRecognizer) {
            guard let sceneView else { return }

            dismissModelActionMenu()
            guard let hit = modelHit(at: recognizer.location(in: sceneView)) else {
                clearSurfaceHighlight()
                onSelectSurface(nil)
                onSelectModel(nil)
                return
            }

            selectedSurfaceSelection = hit.selection
            addSurfaceHighlight(for: hit)
            onSelectSurface(hit.selection)
        }

        @objc
        func handleDoubleTap(_ recognizer: UITapGestureRecognizer) {
            guard let sceneView else { return }

            let modelID = modelID(at: recognizer.location(in: sceneView))
            clearSurfaceHighlight()
            onSelectSurface(nil)
            onSelectModel(modelID)
            onContextAction(.selectModel(modelID))
        }

        @objc
        func handleCameraZoom(_ recognizer: UIPinchGestureRecognizer) {
            guard let cameraNode else { return }

            switch recognizer.state {
            case .began:
                lastPinchScale = recognizer.scale
            case .changed:
                let relativeScale = recognizer.scale / max(lastPinchScale, 0.001)
                lastPinchScale = recognizer.scale
                let zoomFactor = 1 / Float(relativeScale)
                zoomCamera(cameraNode, by: zoomFactor)
            case .ended, .cancelled, .failed:
                lastPinchScale = 1
            default:
                break
            }
        }

        @objc
        func handleCameraScroll(_ recognizer: UIPanGestureRecognizer) {
            guard let cameraNode else { return }

            switch recognizer.state {
            case .began:
                lastScrollTranslationY = recognizer.translation(in: recognizer.view).y
            case .changed:
                let translationY = recognizer.translation(in: recognizer.view).y
                let deltaY = min(max(translationY - lastScrollTranslationY, -80), 80)
                lastScrollTranslationY = translationY
                let zoomFactor = pow(Float(1.0035), Float(deltaY))
                zoomCamera(cameraNode, by: zoomFactor)
            case .ended, .cancelled, .failed:
                lastScrollTranslationY = 0
            default:
                break
            }
        }

        @objc
        func handleSecondaryClick(_ recognizer: UITapGestureRecognizer) {
            guard recognizer.state == .ended,
                  let sceneView else {
                return
            }

            let modelID = modelID(at: recognizer.location(in: sceneView))
            dismissModelActionMenu()
            clearSurfaceHighlight()
            onSelectSurface(nil)
            onSelectModel(modelID)
            onContextAction(.selectModel(modelID))

            if let modelID {
                presentModelActionMenu(for: modelID, at: recognizer.location(in: sceneView))
            }
        }

        @objc
        func handleLongPress(_ recognizer: UILongPressGestureRecognizer) {
            guard recognizer.state == .began,
                  let sceneView else {
                return
            }

            let modelID = modelID(at: recognizer.location(in: sceneView))
            dismissModelActionMenu()
            clearSurfaceHighlight()
            onSelectSurface(nil)
            onSelectModel(modelID)
            onContextAction(.selectModel(modelID))
        }

        @objc
        func handleModelPan(_ recognizer: UIPanGestureRecognizer) {
            guard let sceneView else { return }

            let location = recognizer.location(in: sceneView)
            switch recognizer.state {
            case .began:
                dismissModelActionMenu()
                guard let modelID = modelID(at: location),
                      let platePoint = buildPlatePoint(at: location) else {
                    activePanModelID = nil
                    lastPanPlatePoint = nil
                    return
                }

                activePanModelID = modelID
                lastPanPlatePoint = platePoint
                sceneView.allowsCameraControl = false
                onSelectModel(modelID)
                onContextAction(.selectModel(modelID))
            case .changed:
                guard let activePanModelID,
                      let previousPoint = lastPanPlatePoint,
                      let platePoint = buildPlatePoint(at: location) else {
                    return
                }

                lastPanPlatePoint = platePoint
                onContextAction(
                    .moveModel(
                        activePanModelID,
                        xDelta: Double(platePoint.x - previousPoint.x),
                        yDelta: Double(platePoint.z - previousPoint.z)
                    )
                )
            case .ended, .cancelled, .failed:
                activePanModelID = nil
                lastPanPlatePoint = nil
                sceneView.allowsCameraControl = true
            default:
                break
            }
        }

        @objc
        func handleModelRotation(_ recognizer: UIRotationGestureRecognizer) {
            guard let sceneView else { return }

            switch recognizer.state {
            case .began:
                dismissModelActionMenu()
                let location = recognizer.location(in: sceneView)
                guard let modelID = modelID(at: location) ?? selectedModelID else {
                    activeRotationModelID = nil
                    return
                }

                activeRotationModelID = modelID
                lastGestureRotation = recognizer.rotation
                sceneView.allowsCameraControl = false
                onSelectModel(modelID)
                onContextAction(.selectModel(modelID))
            case .changed:
                guard let activeRotationModelID else { return }

                let deltaRadians = recognizer.rotation - lastGestureRotation
                lastGestureRotation = recognizer.rotation
                onContextAction(.rotateModel(activeRotationModelID, degrees: Double(deltaRadians * 180 / .pi)))
            case .ended, .cancelled, .failed:
                activeRotationModelID = nil
                lastGestureRotation = 0
                sceneView.allowsCameraControl = true
            default:
                break
            }
        }

        private struct ModelHit {
            var selection: ModelSurfaceSelection
            var result: SCNHitTestResult
            var edgeVertices: (SCNVector3, SCNVector3)?
        }

        private func modelID(at point: CGPoint) -> PlacedModel.ID? {
            modelHitResult(at: point)?.modelID
        }

        private func modelHit(at point: CGPoint) -> ModelHit? {
            guard let hitResult = modelHitResult(at: point) else { return nil }

            let edgeHit = nearestTriangleEdge(in: hitResult.result, at: point)
            let selection = ModelSurfaceSelection(
                modelID: hitResult.modelID,
                kind: edgeHit == nil ? .face : .edge,
                faceIndex: max(hitResult.result.faceIndex, 0),
                edgeIndex: edgeHit?.index
            )

            return ModelHit(
                selection: selection,
                result: hitResult.result,
                edgeVertices: edgeHit.map { ($0.start, $0.end) }
            )
        }

        private func modelHitResult(at point: CGPoint) -> (modelID: PlacedModel.ID, result: SCNHitTestResult)? {
            guard let sceneView else { return nil }

            let hitResults = sceneView.hitTest(point, options: [.searchMode: SCNHitTestSearchMode.all.rawValue])
            return hitResults.lazy.compactMap { result -> (PlacedModel.ID, SCNHitTestResult)? in
                var node: SCNNode? = result.node
                while let currentNode = node {
                    if let name = currentNode.name,
                       let modelID = self.modelIDsByNodeName[name] {
                        return (modelID, result)
                    }
                    node = currentNode.parent
                }
                return nil
            }.first
        }

        private func nearestTriangleEdge(
            in hitResult: SCNHitTestResult,
            at point: CGPoint
        ) -> (index: Int, start: SCNVector3, end: SCNVector3)? {
            guard let sceneView,
                  let triangle = hitResult.node.geometry?.triangleVertices(
                    geometryIndex: hitResult.geometryIndex,
                    faceIndex: hitResult.faceIndex
                  ) else {
                return nil
            }

            let edges = [
                (triangle.0, triangle.1),
                (triangle.1, triangle.2),
                (triangle.2, triangle.0)
            ]
            let projectedEdges = edges.enumerated().map { index, edge in
                let start = sceneView.projectPoint(hitResult.node.convertPosition(edge.0, to: nil))
                let end = sceneView.projectPoint(hitResult.node.convertPosition(edge.1, to: nil))
                let distance = point.distanceToSegment(
                    from: CGPoint(x: CGFloat(start.x), y: CGFloat(start.y)),
                    to: CGPoint(x: CGFloat(end.x), y: CGFloat(end.y))
                )
                return (index: index, start: edge.0, end: edge.1, distance: distance)
            }

            guard let nearest = projectedEdges.min(by: { $0.distance < $1.distance }),
                  nearest.distance <= 12 else {
                return nil
            }

            return (nearest.index, nearest.1, nearest.2)
        }

        private func addSurfaceHighlight(for hit: ModelHit) {
            clearSurfaceHighlight()

            let highlightNode: SCNNode
            switch hit.selection.kind {
            case .face:
                highlightNode = faceExtrusionHighlightNode(for: hit)
            case .edge:
                if let edgeVertices = hit.edgeVertices {
                    highlightNode = edgeHighlightNode(from: edgeVertices.0, to: edgeVertices.1)
                } else {
                    let marker = SCNSphere(radius: 4)
                    let material = SCNMaterial()
                    material.diffuse.contents = UIColor.systemGreen.withAlphaComponent(0.85)
                    material.emission.contents = UIColor.systemGreen.withAlphaComponent(0.35)
                    marker.materials = [material]
                    highlightNode = SCNNode(geometry: marker)
                    highlightNode.position = hit.result.localCoordinates
                }
            }

            highlightNode.name = Self.surfaceHighlightNodeName
            hit.result.node.addChildNode(highlightNode)
            selectedSurfaceHighlightNode = highlightNode
        }

        private func faceExtrusionHighlightNode(for hit: ModelHit) -> SCNNode {
            let rootNode = SCNNode()
            rootNode.position = hit.result.localCoordinates

            let operation = modelSketchOperationsByID[hit.selection.modelID] ?? .additive
            let color = extrusionColor(for: operation)
            let direction = extrusionDirection(for: operation, normal: hit.result.localNormal.normalized())

            let marker = SCNPlane(width: 12, height: 12)
            let markerMaterial = SCNMaterial()
            markerMaterial.diffuse.contents = color.withAlphaComponent(0.35)
            markerMaterial.emission.contents = color.withAlphaComponent(0.55)
            markerMaterial.isDoubleSided = true
            marker.materials = [markerMaterial]

            let markerNode = SCNNode(geometry: marker)
            markerNode.position = hit.result.localNormal.normalized() * 0.8
            markerNode.look(at: markerNode.position + hit.result.localNormal)
            rootNode.addChildNode(markerNode)

            rootNode.addChildNode(extrusionArrowNode(direction: direction, color: color))
            return rootNode
        }

        private func extrusionArrowNode(direction: SCNVector3, color: UIColor) -> SCNNode {
            let rootNode = SCNNode()
            let shaftLength: CGFloat = 20
            let headHeight: CGFloat = 8

            let material = SCNMaterial()
            material.diffuse.contents = color.withAlphaComponent(0.92)
            material.emission.contents = color.withAlphaComponent(0.45)

            let shaftGeometry = SCNCylinder(radius: 1.2, height: shaftLength)
            shaftGeometry.materials = [material]
            let shaftNode = SCNNode(geometry: shaftGeometry)
            shaftNode.position = direction * Float(shaftLength / 2 + 6)
            shaftNode.alignYAxis(to: direction)
            rootNode.addChildNode(shaftNode)

            let headGeometry = SCNCone(topRadius: 0, bottomRadius: 4.2, height: headHeight)
            headGeometry.materials = [material]
            let headNode = SCNNode(geometry: headGeometry)
            headNode.position = direction * Float(shaftLength + headHeight / 2 + 6)
            headNode.alignYAxis(to: direction)
            rootNode.addChildNode(headNode)

            return rootNode
        }

        private func extrusionDirection(for operation: SketchExtrusionOperation, normal: SCNVector3) -> SCNVector3 {
            switch operation {
            case .additive:
                return normal
            case .negative:
                return normal * -1
            }
        }

        private func extrusionColor(for operation: SketchExtrusionOperation) -> UIColor {
            switch operation {
            case .additive:
                return .systemGreen
            case .negative:
                return .systemRed
            }
        }

        private func edgeHighlightNode(from start: SCNVector3, to end: SCNVector3) -> SCNNode {
            let vector = end - start
            let length = max(CGFloat(vector.length), 0.01)
            let geometry = SCNCylinder(radius: 1.8, height: length)
            let material = SCNMaterial()
            material.diffuse.contents = UIColor.systemGreen.withAlphaComponent(0.90)
            material.emission.contents = UIColor.systemGreen.withAlphaComponent(0.50)
            geometry.materials = [material]

            let node = SCNNode(geometry: geometry)
            node.position = (start + end) * 0.5
            node.eulerAngles = SCNVector3Make(Float.pi / 2, 0, 0)
            node.look(at: end, up: SCNVector3(0, 1, 0), localFront: SCNVector3(0, 1, 0))
            return node
        }

        private func clearSurfaceHighlight() {
            selectedSurfaceHighlightNode?.removeFromParentNode()
            selectedSurfaceHighlightNode = nil
            for node in modelNodesByID.values {
                node.enumerateHierarchy { child in
                    if child.name == Self.surfaceHighlightNodeName {
                        child.removeFromParentNode()
                    }
                }
            }
        }

        private func buildPlatePoint(at point: CGPoint) -> SCNVector3? {
            guard let sceneView else { return nil }

            let nearPoint = sceneView.unprojectPoint(SCNVector3(Float(point.x), Float(point.y), 0))
            let farPoint = sceneView.unprojectPoint(SCNVector3(Float(point.x), Float(point.y), 1))
            let yDelta = farPoint.y - nearPoint.y
            guard abs(yDelta) > 0.0001 else { return nil }

            let t = -nearPoint.y / yDelta
            guard t.isFinite else { return nil }

            return SCNVector3(
                nearPoint.x + (farPoint.x - nearPoint.x) * t,
                0,
                nearPoint.z + (farPoint.z - nearPoint.z) * t
            )
        }

        func presentModelActionMenu(for modelID: PlacedModel.ID, at location: CGPoint) {
            guard let sceneView else { return }

            dismissModelActionMenu()

            let menuContainer = sceneView.window ?? sceneView
            let locationInContainer = sceneView.convert(location, to: menuContainer)
            let overlayView = makeDismissOverlay(in: menuContainer)

            let blurView = UIVisualEffectView(effect: UIBlurEffect(style: .systemChromeMaterial))
            blurView.layer.cornerRadius = 8
            blurView.layer.cornerCurve = .continuous
            blurView.clipsToBounds = true
            blurView.layer.borderColor = UIColor.white.withAlphaComponent(0.16).cgColor
            blurView.layer.borderWidth = 1

            let stackView = UIStackView()
            stackView.axis = .vertical
            stackView.alignment = .fill
            stackView.distribution = .fillEqually
            stackView.spacing = 0
            stackView.translatesAutoresizingMaskIntoConstraints = false
            blurView.contentView.addSubview(stackView)

            NSLayoutConstraint.activate([
                stackView.leadingAnchor.constraint(equalTo: blurView.contentView.leadingAnchor, constant: 8),
                stackView.trailingAnchor.constraint(equalTo: blurView.contentView.trailingAnchor, constant: -8),
                stackView.topAnchor.constraint(equalTo: blurView.contentView.topAnchor, constant: 8),
                stackView.bottomAnchor.constraint(equalTo: blurView.contentView.bottomAnchor, constant: -8)
            ])

            let actions: [(String, String, UIColor, () -> Void)] = [
                ("Duplicate", "plus.square.on.square", .label, { [weak self] in self?.onContextAction(.duplicateModel(modelID)) }),
                ("Center on Plate", "scope", .label, { [weak self] in self?.onContextAction(.centerModel(modelID)) }),
                ("Auto Orient", "cube.transparent", .label, { [weak self] in self?.onContextAction(.autoOrientModel(modelID)) }),
                ("Rotate Left 45 deg", "rotate.left", .label, { [weak self] in self?.onContextAction(.rotateModel(modelID, degrees: -45)) }),
                ("Rotate Right 45 deg", "rotate.right", .label, { [weak self] in self?.onContextAction(.rotateModel(modelID, degrees: 45)) }),
                ("Scale", "arrow.up.left.and.arrow.down.right", .label, { [weak self] in self?.presentScaleActionMenu(for: modelID, at: locationInContainer) }),
                ("Reset Transform", "arrow.counterclockwise", .label, { [weak self] in self?.onContextAction(.resetModelTransform(modelID)) }),
                ("Delete", "trash", .systemRed, { [weak self] in self?.onContextAction(.deleteModel(modelID)) })
            ]

            for action in actions {
                stackView.addArrangedSubview(
                    modelActionButton(
                        title: action.0,
                        systemImage: action.1,
                        tintColor: action.2,
                        action: action.3
                    )
                )
            }

            let menuWidth: CGFloat = 220
            let menuHeight = CGFloat(actions.count * 38 + 16)
            let margin: CGFloat = 14
            let origin = CGPoint(
                x: min(max(locationInContainer.x, margin), max(menuContainer.bounds.width - menuWidth - margin, margin)),
                y: min(max(locationInContainer.y, margin), max(menuContainer.bounds.height - menuHeight - margin, margin))
            )
            blurView.frame = CGRect(origin: origin, size: CGSize(width: menuWidth, height: menuHeight))
            overlayView.addSubview(blurView)
            menuContainer.addSubview(overlayView)
            modelActionMenuOverlayView = overlayView
        }

        private func presentScaleActionMenu(for modelID: PlacedModel.ID, at location: CGPoint) {
            guard let sceneView else { return }

            dismissModelActionMenu()

            let menuContainer = sceneView.window ?? sceneView
            let overlayView = makeDismissOverlay(in: menuContainer)

            let panelView = UIVisualEffectView(effect: UIBlurEffect(style: .systemChromeMaterial))
            panelView.layer.cornerRadius = 8
            panelView.layer.cornerCurve = .continuous
            panelView.clipsToBounds = true
            panelView.layer.borderColor = UIColor.white.withAlphaComponent(0.16).cgColor
            panelView.layer.borderWidth = 1

            let stackView = UIStackView()
            stackView.axis = .vertical
            stackView.alignment = .fill
            stackView.spacing = 9
            stackView.translatesAutoresizingMaskIntoConstraints = false
            panelView.contentView.addSubview(stackView)

            NSLayoutConstraint.activate([
                stackView.leadingAnchor.constraint(equalTo: panelView.contentView.leadingAnchor, constant: 14),
                stackView.trailingAnchor.constraint(equalTo: panelView.contentView.trailingAnchor, constant: -14),
                stackView.topAnchor.constraint(equalTo: panelView.contentView.topAnchor, constant: 12),
                stackView.bottomAnchor.constraint(equalTo: panelView.contentView.bottomAnchor, constant: -12)
            ])

            let scalePercent = modelScalePercentsByID[modelID] ?? 100
            stackView.addArrangedSubview(scaleHeaderRow())
            stackView.addArrangedSubview(scaleValueRow(title: "Scale", values: ["\(scalePercent)"], suffix: "%"))
            stackView.addArrangedSubview(scaleValueRow(title: "Size", values: sizeValues(for: modelID), suffix: "mm"))
            stackView.addArrangedSubview(uniformScaleRow())
            stackView.addArrangedSubview(scaleShortcutRow(modelID: modelID, currentPercent: scalePercent, location: location))

            let menuWidth: CGFloat = 356
            let menuHeight: CGFloat = 150
            let margin: CGFloat = 14
            let origin = CGPoint(
                x: min(max(location.x, margin), max(menuContainer.bounds.width - menuWidth - margin, margin)),
                y: min(max(location.y, margin), max(menuContainer.bounds.height - menuHeight - margin, margin))
            )
            panelView.frame = CGRect(origin: origin, size: CGSize(width: menuWidth, height: menuHeight))
            overlayView.addSubview(panelView)
            menuContainer.addSubview(overlayView)
            modelActionMenuOverlayView = overlayView
        }

        private func makeDismissOverlay(in menuContainer: UIView) -> UIControl {
            let overlayView = UIControl(frame: menuContainer.bounds)
            overlayView.backgroundColor = .clear
            overlayView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            overlayView.isEnabled = false
            overlayView.addAction(
                UIAction { [weak self] _ in
                    self?.dismissModelActionMenu()
                },
                for: .touchUpInside
            )

            DispatchQueue.main.async { [weak overlayView] in
                overlayView?.isEnabled = true
            }
            return overlayView
        }

        private func modelActionButton(
            title: String,
            systemImage: String,
            tintColor: UIColor,
            action: @escaping () -> Void
        ) -> UIButton {
            var configuration = UIButton.Configuration.plain()
            configuration.title = title
            configuration.image = UIImage(systemName: systemImage)
            configuration.imagePadding = 10
            configuration.baseForegroundColor = tintColor
            configuration.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 8, bottom: 0, trailing: 8)

            let button = UIButton(configuration: configuration)
            button.contentHorizontalAlignment = .leading
            button.titleLabel?.font = .systemFont(ofSize: 14, weight: .medium)
            button.addAction(
                UIAction { [weak self] _ in
                    self?.dismissModelActionMenu()
                    action()
                },
                for: .touchUpInside
            )
            return button
        }

        private func scaleHeaderRow() -> UIView {
            let row = UIStackView()
            row.axis = .horizontal
            row.alignment = .center
            row.spacing = 8

            let chevron = UIImageView(image: UIImage(systemName: "chevron.down"))
            chevron.tintColor = .secondaryLabel
            chevron.contentMode = .scaleAspectFit
            chevron.setContentHuggingPriority(.required, for: .horizontal)

            let label = UILabel()
            label.text = "World coordinates"
            label.textColor = .label
            label.font = .systemFont(ofSize: 14, weight: .semibold)

            for view in [chevron, label] {
                row.addArrangedSubview(view)
            }
            return row
        }

        private func scaleValueRow(title: String, values: [String], suffix: String) -> UIView {
            let row = UIStackView()
            row.axis = .horizontal
            row.alignment = .center
            row.spacing = 7

            let titleLabel = UILabel()
            titleLabel.text = title
            titleLabel.textColor = .secondaryLabel
            titleLabel.font = .systemFont(ofSize: 13, weight: .medium)
            titleLabel.widthAnchor.constraint(equalToConstant: 54).isActive = true
            row.addArrangedSubview(titleLabel)

            for value in values {
                row.addArrangedSubview(scaleFieldLabel(value))
            }

            let suffixLabel = UILabel()
            suffixLabel.text = suffix
            suffixLabel.textColor = .secondaryLabel
            suffixLabel.font = .systemFont(ofSize: 12, weight: .medium)
            suffixLabel.widthAnchor.constraint(equalToConstant: 24).isActive = true
            row.addArrangedSubview(suffixLabel)

            return row
        }

        private func scaleFieldLabel(_ text: String) -> UILabel {
            let label = UILabel()
            label.text = text
            label.textAlignment = .center
            label.textColor = .label
            label.font = .monospacedDigitSystemFont(ofSize: 13, weight: .medium)
            label.backgroundColor = UIColor.secondarySystemFill.withAlphaComponent(0.62)
            label.layer.cornerRadius = 4
            label.clipsToBounds = true
            label.heightAnchor.constraint(equalToConstant: 24).isActive = true
            label.widthAnchor.constraint(equalToConstant: 64).isActive = true
            return label
        }

        private func uniformScaleRow() -> UIView {
            let row = UIStackView()
            row.axis = .horizontal
            row.alignment = .center
            row.spacing = 8

            let check = UIImageView(image: UIImage(systemName: "checkmark.square.fill"))
            check.tintColor = .systemGreen
            check.contentMode = .scaleAspectFit
            check.widthAnchor.constraint(equalToConstant: 18).isActive = true

            let label = UILabel()
            label.text = "Uniform scale"
            label.textColor = .label
            label.font = .systemFont(ofSize: 13, weight: .medium)

            row.addArrangedSubview(check)
            row.addArrangedSubview(label)
            return row
        }

        private func scaleShortcutRow(modelID: PlacedModel.ID, currentPercent: Int, location: CGPoint) -> UIView {
            let row = UIStackView()
            row.axis = .horizontal
            row.alignment = .center
            row.distribution = .fillEqually
            row.spacing = 8

            let shortcuts: [(String, Int)] = [
                ("-10%", max(currentPercent - 10, 25)),
                ("100%", 100),
                ("+10%", min(currentPercent + 10, 400)),
                ("200%", 200)
            ]

            for shortcut in shortcuts {
                var configuration = UIButton.Configuration.filled()
                configuration.title = shortcut.0
                configuration.baseBackgroundColor = UIColor.secondarySystemFill
                configuration.baseForegroundColor = .label
                configuration.cornerStyle = .small
                configuration.contentInsets = NSDirectionalEdgeInsets(top: 5, leading: 8, bottom: 5, trailing: 8)

                let button = UIButton(configuration: configuration)
                button.addAction(
                    UIAction { [weak self] _ in
                        guard let self else { return }
                        modelScalePercentsByID[modelID] = shortcut.1
                        onContextAction(.setModelScale(modelID, percentage: shortcut.1))
                        presentScaleActionMenu(for: modelID, at: location)
                    },
                    for: .touchUpInside
                )
                row.addArrangedSubview(button)
            }

            return row
        }

        private func sizeValues(for modelID: PlacedModel.ID) -> [String] {
            guard let node = modelNodesByID[modelID] else {
                return ["--", "--", "--"]
            }

            let bounds = node.recursiveBoundingBox()
            let scale = node.scale
            let width = abs(bounds.max.x - bounds.min.x) * abs(scale.x)
            let height = abs(bounds.max.y - bounds.min.y) * abs(scale.y)
            let depth = abs(bounds.max.z - bounds.min.z) * abs(scale.z)
            return [width, depth, height].map { value in
                value.isFinite ? String(format: "%.1f", value) : "--"
            }
        }

        private func dismissModelActionMenu() {
            modelActionMenuOverlayView?.removeFromSuperview()
            modelActionMenuOverlayView = nil
        }

        func updateSelection(
            selectedModelID: PlacedModel.ID?,
            selectedSurfaceSelection: ModelSurfaceSelection?
        ) {
            self.selectedModelID = selectedModelID
            self.selectedSurfaceSelection = selectedSurfaceSelection
            if selectedSurfaceSelection == nil {
                clearSurfaceHighlight()
            }

            for (modelID, node) in modelNodesByID {
                if modelID == selectedModelID && selectedSurfaceSelection?.modelID != modelID {
                    node.addSelectionOutline()
                } else {
                    node.removeSelectionOutline()
                }
            }
        }

        private func zoomCamera(_ cameraNode: SCNNode, by factor: Float) {
            let current = cameraNode.position
            let distance = max(sqrt(current.x * current.x + current.y * current.y + current.z * current.z), 0.001)
            let nextDistance = min(max(distance * factor, 90), 720)
            let distanceRatio = nextDistance / distance
            cameraNode.position = SCNVector3(
                current.x * distanceRatio,
                current.y * distanceRatio,
                current.z * distanceRatio
            )
        }

        func syncCameraStateFromScene() {
            guard let pointOfView = sceneView?.pointOfView ?? cameraNode else { return }

            let eulerAngles = pointOfView.presentation.eulerAngles
            let nextPitch = -Double(eulerAngles.x) * 180 / .pi
            let nextYaw = Double(eulerAngles.y) * 180 / .pi
            let currentCamera = camera.wrappedValue
            guard abs(currentCamera.pitch - nextPitch) > 0.25 || abs(currentCamera.yaw - nextYaw) > 0.25 else {
                return
            }

            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                var updatedCamera = self.camera.wrappedValue
                updatedCamera.pitch = nextPitch
                updatedCamera.yaw = nextYaw
                self.camera.wrappedValue = updatedCamera
            }
        }
    }
}

extension ModelWorkspaceSceneView.Coordinator: SCNSceneRendererDelegate {
    func renderer(_ renderer: any SCNSceneRenderer, updateAtTime time: TimeInterval) {
        syncCameraStateFromScene()
    }
}

extension ModelWorkspaceSceneView.Coordinator: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        true
    }
}

extension ModelWorkspaceSceneView.Coordinator: UIPencilInteractionDelegate {
    func pencilInteractionDidTap(_ interaction: UIPencilInteraction) {
    }

    @available(iOS 17.5, *)
    func pencilInteraction(_ interaction: UIPencilInteraction, didReceiveSqueeze squeeze: UIPencilInteraction.Squeeze) {
    }
}

private extension SCNNode {
    func alignYAxis(to direction: SCNVector3) {
        let normalizedDirection = direction.normalized()
        let up = abs(normalizedDirection.y) > 0.92 ? SCNVector3(0, 0, 1) : SCNVector3(0, 1, 0)
        look(
            at: position + normalizedDirection,
            up: up,
            localFront: SCNVector3(0, 1, 0)
        )
    }

    func recursiveBoundingBox() -> (min: SCNVector3, max: SCNVector3) {
        var resolvedMin = SCNVector3Zero
        var resolvedMax = SCNVector3Zero
        var didResolveBounds = false

        enumerateHierarchy { node in
            let bounds = node.boundingBox
            guard bounds.min.x.isFinite, bounds.max.x.isFinite else { return }

            let corners = [
                SCNVector3(bounds.min.x, bounds.min.y, bounds.min.z),
                SCNVector3(bounds.min.x, bounds.min.y, bounds.max.z),
                SCNVector3(bounds.min.x, bounds.max.y, bounds.min.z),
                SCNVector3(bounds.min.x, bounds.max.y, bounds.max.z),
                SCNVector3(bounds.max.x, bounds.min.y, bounds.min.z),
                SCNVector3(bounds.max.x, bounds.min.y, bounds.max.z),
                SCNVector3(bounds.max.x, bounds.max.y, bounds.min.z),
                SCNVector3(bounds.max.x, bounds.max.y, bounds.max.z)
            ].map { node.convertPosition($0, to: self) }

            for corner in corners {
                if didResolveBounds == false {
                    resolvedMin = corner
                    resolvedMax = corner
                    didResolveBounds = true
                } else {
                    resolvedMin.x = min(resolvedMin.x, corner.x)
                    resolvedMin.y = min(resolvedMin.y, corner.y)
                    resolvedMin.z = min(resolvedMin.z, corner.z)
                    resolvedMax.x = max(resolvedMax.x, corner.x)
                    resolvedMax.y = max(resolvedMax.y, corner.y)
                    resolvedMax.z = max(resolvedMax.z, corner.z)
                }
            }
        }

        return didResolveBounds ? (resolvedMin, resolvedMax) : (SCNVector3Zero, SCNVector3Zero)
    }

    func normalizePivotToBottomCenter() {
        let bounds = recursiveBoundingBox()
        let centerX = (bounds.min.x + bounds.max.x) / 2
        let centerZ = (bounds.min.z + bounds.max.z) / 2
        pivot = SCNMatrix4MakeTranslation(centerX, bounds.min.y, centerZ)
    }

    func applyDefaultMaterial(surfaceColor: UIColor, isSelected: Bool) {
        enumerateHierarchy { node in
            guard let geometry = node.geometry else { return }

            if geometry.materials.isEmpty {
                let material = SCNMaterial()
                material.diffuse.contents = surfaceColor
                material.roughness.contents = 0.68
                material.metalness.contents = 0.02
                geometry.materials = [material]
            }

            if isSelected {
                for material in geometry.materials {
                    material.emission.contents = UIColor.white.withAlphaComponent(0.08)
                }
            } else {
                for material in geometry.materials {
                    material.emission.contents = UIColor.clear
                }
            }
        }
    }

    func addSelectionOutline() {
        removeSelectionOutline()

        let bounds = recursiveBoundingBox()
        let width = max(CGFloat(bounds.max.x - bounds.min.x), 8)
        let height = max(CGFloat(bounds.max.y - bounds.min.y), 8)
        let length = max(CGFloat(bounds.max.z - bounds.min.z), 8)
        let outline = SCNBox(width: width + 8, height: height + 8, length: length + 8, chamferRadius: 4)
        let material = SCNMaterial()
        material.diffuse.contents = UIColor.clear
        material.emission.contents = UIColor.systemGreen.withAlphaComponent(0.8)
        material.fillMode = .lines
        outline.materials = [material]

        let outlineNode = SCNNode(geometry: outline)
        outlineNode.name = Self.selectionOutlineNodeName
        outlineNode.position = SCNVector3(0, Float(height / 2), 0)
        addChildNode(outlineNode)
    }

    func removeSelectionOutline() {
        childNodes
            .filter { $0.name == Self.selectionOutlineNodeName }
            .forEach { $0.removeFromParentNode() }
    }

    func enumerateHierarchy(_ body: (SCNNode) -> Void) {
        body(self)
        for child in childNodes {
            child.enumerateHierarchy(body)
        }
    }

    private static var selectionOutlineNodeName: String {
        "ModelWorkspaceSceneView.selectionOutline"
    }
}

private extension SCNGeometry {
    func triangleVertices(geometryIndex: Int, faceIndex: Int) -> (SCNVector3, SCNVector3, SCNVector3)? {
        guard let vertexSource = sources(for: .vertex).first,
              geometryIndex >= 0,
              elements.indices.contains(geometryIndex),
              faceIndex >= 0 else {
            return nil
        }

        let element = elements[geometryIndex]
        guard element.primitiveType == .triangles,
              faceIndex < element.primitiveCount else {
            return nil
        }

        let indices = (0..<3).compactMap { vertexOffset in
            element.index(at: faceIndex * 3 + vertexOffset)
        }
        guard indices.count == 3,
              let first = vertexSource.vector(at: indices[0]),
              let second = vertexSource.vector(at: indices[1]),
              let third = vertexSource.vector(at: indices[2]) else {
            return nil
        }

        return (first, second, third)
    }
}

private extension SCNGeometryElement {
    func index(at primitiveVertexIndex: Int) -> Int? {
        let offset = primitiveVertexIndex * bytesPerIndex
        guard offset + bytesPerIndex <= data.count else {
            return nil
        }

        return data.withUnsafeBytes { rawBuffer in
            guard let base = rawBuffer.baseAddress else { return nil }
            let pointer = base.advanced(by: offset)
            switch bytesPerIndex {
            case 1:
                return Int(pointer.load(as: UInt8.self))
            case 2:
                return Int(UInt16(littleEndian: pointer.load(as: UInt16.self)))
            case 4:
                return Int(UInt32(littleEndian: pointer.load(as: UInt32.self)))
            default:
                return nil
            }
        }
    }
}

private extension SCNGeometrySource {
    func vector(at index: Int) -> SCNVector3? {
        guard usesFloatComponents,
              index >= 0,
              index < vectorCount,
              componentsPerVector >= 3 else {
            return nil
        }

        let baseOffset = dataOffset + index * dataStride
        guard baseOffset + bytesPerComponent * 3 <= data.count else {
            return nil
        }

        return data.withUnsafeBytes { rawBuffer in
            guard let base = rawBuffer.baseAddress else { return nil }
            let pointer = base.advanced(by: baseOffset)
            switch bytesPerComponent {
            case 4:
                return SCNVector3(
                    pointer.load(fromByteOffset: 0, as: Float.self),
                    pointer.load(fromByteOffset: 4, as: Float.self),
                    pointer.load(fromByteOffset: 8, as: Float.self)
                )
            case 8:
                return SCNVector3(
                    Float(pointer.load(fromByteOffset: 0, as: Double.self)),
                    Float(pointer.load(fromByteOffset: 8, as: Double.self)),
                    Float(pointer.load(fromByteOffset: 16, as: Double.self))
                )
            default:
                return nil
            }
        }
    }
}

private extension CGPoint {
    func distanceToSegment(from start: CGPoint, to end: CGPoint) -> CGFloat {
        let dx = end.x - start.x
        let dy = end.y - start.y
        let lengthSquared = dx * dx + dy * dy
        guard lengthSquared > 0 else {
            return hypot(x - start.x, y - start.y)
        }

        let projection = max(0, min(1, ((x - start.x) * dx + (y - start.y) * dy) / lengthSquared))
        let closest = CGPoint(x: start.x + projection * dx, y: start.y + projection * dy)
        return hypot(x - closest.x, y - closest.y)
    }
}

private extension SCNVector3 {
    var length: Float {
        sqrt(x * x + y * y + z * z)
    }

    func normalized() -> SCNVector3 {
        let length = max(length, 0.0001)
        return SCNVector3(x / length, y / length, z / length)
    }

    static func + (left: SCNVector3, right: SCNVector3) -> SCNVector3 {
        SCNVector3(left.x + right.x, left.y + right.y, left.z + right.z)
    }

    static func - (left: SCNVector3, right: SCNVector3) -> SCNVector3 {
        SCNVector3(left.x - right.x, left.y - right.y, left.z - right.z)
    }

    static func * (vector: SCNVector3, scalar: Float) -> SCNVector3 {
        SCNVector3(vector.x * scalar, vector.y * scalar, vector.z * scalar)
    }
}

private extension UIColor {
    convenience init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)

        let red = CGFloat((value >> 16) & 0xFF) / 255
        let green = CGFloat((value >> 8) & 0xFF) / 255
        let blue = CGFloat(value & 0xFF) / 255

        self.init(red: red, green: green, blue: blue, alpha: 1)
    }
}

private extension UIView {
    func installPencilInteraction(delegate: UIPencilInteractionDelegate) {
        if #available(iOS 17.5, *) {
            addInteraction(UIPencilInteraction(delegate: delegate))
        } else {
            let interaction = UIPencilInteraction()
            interaction.delegate = delegate
            addInteraction(interaction)
        }
    }
}
