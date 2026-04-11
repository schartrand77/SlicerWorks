import SceneKit
import SwiftUI

enum ModelWorkspaceContextAction {
    case selectModel(PlacedModel.ID?)
    case duplicateModel(PlacedModel.ID)
    case deleteModel(PlacedModel.ID)
    case centerModel(PlacedModel.ID)
    case rotateModel(PlacedModel.ID, degrees: Double)
    case scaleModel(PlacedModel.ID, percentageDelta: Int)
    case resetModelTransform(PlacedModel.ID)
}

struct ModelWorkspaceSceneView: UIViewRepresentable {
    let models: [PlacedModel]
    let selectedModelID: PlacedModel.ID?
    let surfaceColor: PrintColorOption
    let onSelectModel: (PlacedModel.ID?) -> Void
    var onContextAction: (ModelWorkspaceContextAction) -> Void = { _ in }

    func makeCoordinator() -> Coordinator {
        Coordinator(
            selectedModelID: selectedModelID,
            onSelectModel: onSelectModel,
            onContextAction: onContextAction
        )
    }

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.backgroundColor = .clear
        view.allowsCameraControl = true
        view.autoenablesDefaultLighting = false
        view.scene = makeScene(context: context)

        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        if #available(iOS 13.4, *) {
            tapGesture.buttonMaskRequired = .primary
        }
        view.addGestureRecognizer(tapGesture)
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
        if #available(iOS 16.0, *) {
            let editMenuInteraction = UIEditMenuInteraction(delegate: context.coordinator)
            view.addInteraction(editMenuInteraction)
            context.coordinator.editMenuInteraction = editMenuInteraction
        }
        context.coordinator.sceneView = view

        return view
    }

    func updateUIView(_ view: SCNView, context: Context) {
        context.coordinator.selectedModelID = selectedModelID
        context.coordinator.onSelectModel = onSelectModel
        context.coordinator.onContextAction = onContextAction
        view.scene = makeScene(context: context)
        context.coordinator.sceneView = view
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

        context.coordinator.modelIDsByNodeName.removeAll()
        for model in models {
            let node = makeModelNode(for: model)
            node.name = model.id.uuidString
            node.enumerateChildNodes { child, _ in
                child.name = model.id.uuidString
            }
            context.coordinator.modelIDsByNodeName[model.id.uuidString] = model.id
            scene.rootNode.addChildNode(node)
        }

        return scene
    }

    private func makeBuildPlateNode() -> SCNNode {
        let plate = SCNBox(width: 256, height: 2, length: 256, chamferRadius: 2)
        let material = SCNMaterial()
        material.diffuse.contents = UIColor.white.withAlphaComponent(0.08)
        material.emission.contents = UIColor.white.withAlphaComponent(0.02)
        plate.materials = [material]

        let node = SCNNode(geometry: plate)
        node.position = SCNVector3(0, -1, 0)

        let grid = SCNFloor()
        grid.reflectivity = 0
        let gridMaterial = SCNMaterial()
        gridMaterial.diffuse.contents = UIColor.white.withAlphaComponent(0.05)
        grid.materials = [gridMaterial]

        let gridNode = SCNNode(geometry: grid)
        gridNode.position = SCNVector3(0, 0.1, 0)
        gridNode.scale = SCNVector3(0.00256, 0.00256, 0.00256)
        node.addChildNode(gridNode)

        return node
    }

    private func makeModelNode(for model: PlacedModel) -> SCNNode {
        let isSelected = selectedModelID == model.id
        let sourceNode = loadModelNode(from: model.sourceURL)
            ?? makeFallbackNode(for: model)

        sourceNode.applyDefaultMaterial(
            surfaceColor: UIColor(hex: surfaceColor.hex),
            isSelected: isSelected
        )
        sourceNode.normalizePivotToBottomCenter()

        let bounds = sourceNode.recursiveBoundingBox()
        let maxDimension = max(
            bounds.max.x - bounds.min.x,
            bounds.max.y - bounds.min.y,
            bounds.max.z - bounds.min.z
        )
        let importScale = normalizedImportScale(for: maxDimension)
        let modelScale = Float(model.scalePercent) / 100 * importScale
        sourceNode.scale = SCNVector3(modelScale, modelScale, modelScale)
        sourceNode.eulerAngles.y = Float(model.rotationDegrees * .pi / 180)
        sourceNode.position = SCNVector3(Float(model.position.x), 0, Float(model.position.y))

        if isSelected {
            sourceNode.addSelectionOutline()
        }

        return sourceNode
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
                        readFloat32(from: data, at: vertexOffset + 4),
                        readFloat32(from: data, at: vertexOffset + 8)
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

                return SCNVector3(x, y, z)
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

        weak var sceneView: SCNView?
        @available(iOS 16.0, *)
        weak var editMenuInteraction: UIEditMenuInteraction?
        var selectedModelID: PlacedModel.ID?
        var modelIDsByNodeName: [String: PlacedModel.ID] = [:]
        var editMenuModelID: PlacedModel.ID?
        var editMenuLocation: CGPoint = .zero
        var onSelectModel: (PlacedModel.ID?) -> Void
        var onContextAction: (ModelWorkspaceContextAction) -> Void

        init(
            selectedModelID: PlacedModel.ID?,
            onSelectModel: @escaping (PlacedModel.ID?) -> Void,
            onContextAction: @escaping (ModelWorkspaceContextAction) -> Void
        ) {
            self.selectedModelID = selectedModelID
            self.onSelectModel = onSelectModel
            self.onContextAction = onContextAction
        }

        @objc
        func handleTap(_ recognizer: UITapGestureRecognizer) {
            guard let sceneView else { return }

            onSelectModel(modelID(at: recognizer.location(in: sceneView)))
        }

        @objc
        func handleSecondaryClick(_ recognizer: UITapGestureRecognizer) {
            guard recognizer.state == .ended,
                  let sceneView else {
                return
            }

            if #available(iOS 16.0, *) {
                presentEditMenu(at: recognizer.location(in: sceneView))
            }
        }

        @objc
        func handleLongPress(_ recognizer: UILongPressGestureRecognizer) {
            guard recognizer.state == .began,
                  let sceneView else {
                return
            }

            if #available(iOS 16.0, *) {
                presentEditMenu(at: recognizer.location(in: sceneView))
            }
        }

        private func modelID(at point: CGPoint) -> PlacedModel.ID? {
            guard let sceneView else { return nil }

            let hitResults = sceneView.hitTest(point, options: [.searchMode: SCNHitTestSearchMode.all.rawValue])
            return hitResults.lazy.compactMap { result -> PlacedModel.ID? in
                var node: SCNNode? = result.node
                while let currentNode = node {
                    if let name = currentNode.name,
                       let modelID = self.modelIDsByNodeName[name] {
                        return modelID
                    }
                    node = currentNode.parent
                }
                return nil
            }.first
        }

        func menu(for modelID: PlacedModel.ID?) -> UIMenu {
            guard let modelID else {
                return UIMenu(children: [
                    UIAction(title: "Clear Selection", image: UIImage(systemName: "xmark.circle")) { [weak self] _ in
                        self?.onSelectModel(nil)
                        self?.onContextAction(.selectModel(nil))
                    }
                ])
            }

            let selectAction = UIAction(title: "Select", image: UIImage(systemName: "checkmark.circle")) { [weak self] _ in
                self?.onSelectModel(modelID)
                self?.onContextAction(.selectModel(modelID))
            }

            let duplicateAction = UIAction(title: "Duplicate", image: UIImage(systemName: "plus.square.on.square")) { [weak self] _ in
                self?.onContextAction(.duplicateModel(modelID))
            }

            let centerAction = UIAction(title: "Center on Plate", image: UIImage(systemName: "scope")) { [weak self] _ in
                self?.onContextAction(.centerModel(modelID))
            }

            let rotateMenu = UIMenu(title: "Rotate", image: UIImage(systemName: "rotate.3d"), children: [
                UIAction(title: "Rotate Left 45 deg", image: UIImage(systemName: "rotate.left")) { [weak self] _ in
                    self?.onContextAction(.rotateModel(modelID, degrees: -45))
                },
                UIAction(title: "Rotate Right 45 deg", image: UIImage(systemName: "rotate.right")) { [weak self] _ in
                    self?.onContextAction(.rotateModel(modelID, degrees: 45))
                }
            ])

            let scaleMenu = UIMenu(title: "Scale", image: UIImage(systemName: "arrow.up.left.and.arrow.down.right"), children: [
                UIAction(title: "Scale Up 10%", image: UIImage(systemName: "plus.magnifyingglass")) { [weak self] _ in
                    self?.onContextAction(.scaleModel(modelID, percentageDelta: 10))
                },
                UIAction(title: "Scale Down 10%", image: UIImage(systemName: "minus.magnifyingglass")) { [weak self] _ in
                    self?.onContextAction(.scaleModel(modelID, percentageDelta: -10))
                }
            ])

            let resetAction = UIAction(title: "Reset Transform", image: UIImage(systemName: "arrow.counterclockwise")) { [weak self] _ in
                self?.onContextAction(.resetModelTransform(modelID))
            }

            let deleteAction = UIAction(title: "Delete", image: UIImage(systemName: "trash"), attributes: .destructive) { [weak self] _ in
                self?.onContextAction(.deleteModel(modelID))
            }

            return UIMenu(children: [
                selectAction,
                duplicateAction,
                centerAction,
                rotateMenu,
                scaleMenu,
                resetAction,
                deleteAction
            ])
        }

        @available(iOS 16.0, *)
        func presentEditMenu(at location: CGPoint) {
            let menuModelID = modelID(at: location) ?? selectedModelID
            editMenuModelID = menuModelID
            editMenuLocation = location
            editMenuInteraction?.presentEditMenu(
                with: UIEditMenuConfiguration(identifier: nil, sourcePoint: location)
            )
        }
    }
}

extension ModelWorkspaceSceneView.Coordinator: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        true
    }
}

extension ModelWorkspaceSceneView.Coordinator: UIPencilInteractionDelegate {
    func pencilInteractionDidTap(_ interaction: UIPencilInteraction) {
        guard #available(iOS 16.0, *),
              let sceneView else {
            return
        }

        presentEditMenu(at: CGPoint(x: sceneView.bounds.midX, y: sceneView.bounds.midY))
    }

    @available(iOS 17.5, *)
    func pencilInteraction(_ interaction: UIPencilInteraction, didReceiveSqueeze squeeze: UIPencilInteraction.Squeeze) {
        guard let sceneView else {
            return
        }

        let location = squeeze.hoverPose?.location ?? CGPoint(x: sceneView.bounds.midX, y: sceneView.bounds.midY)
        presentEditMenu(at: location)
    }
}

@available(iOS 16.0, *)
extension ModelWorkspaceSceneView.Coordinator: UIEditMenuInteractionDelegate {
    func editMenuInteraction(
        _ interaction: UIEditMenuInteraction,
        menuFor configuration: UIEditMenuConfiguration,
        suggestedActions: [UIMenuElement]
    ) -> UIMenu? {
        menu(for: editMenuModelID)
    }

    func editMenuInteraction(
        _ interaction: UIEditMenuInteraction,
        targetRectFor configuration: UIEditMenuConfiguration
    ) -> CGRect {
        CGRect(origin: editMenuLocation, size: CGSize(width: 1, height: 1))
    }
}

private extension SCNNode {
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
            }
        }
    }

    func addSelectionOutline() {
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
        outlineNode.position = SCNVector3(0, Float(height / 2), 0)
        addChildNode(outlineNode)
    }

    func enumerateHierarchy(_ body: (SCNNode) -> Void) {
        body(self)
        for child in childNodes {
            child.enumerateHierarchy(body)
        }
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
