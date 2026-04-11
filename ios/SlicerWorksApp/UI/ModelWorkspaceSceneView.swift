import SceneKit
import SwiftUI

struct ModelWorkspaceSceneView: UIViewRepresentable {
    let models: [PlacedModel]
    let selectedModelID: PlacedModel.ID?
    let surfaceColor: PrintColorOption
    let onSelectModel: (PlacedModel.ID?) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onSelectModel: onSelectModel)
    }

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.backgroundColor = .clear
        view.allowsCameraControl = true
        view.autoenablesDefaultLighting = false
        view.scene = makeScene(context: context)

        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        view.addGestureRecognizer(tapGesture)
        context.coordinator.sceneView = view

        return view
    }

    func updateUIView(_ view: SCNView, context: Context) {
        context.coordinator.onSelectModel = onSelectModel
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
        weak var sceneView: SCNView?
        var modelIDsByNodeName: [String: PlacedModel.ID] = [:]
        var onSelectModel: (PlacedModel.ID?) -> Void

        init(onSelectModel: @escaping (PlacedModel.ID?) -> Void) {
            self.onSelectModel = onSelectModel
        }

        @objc
        func handleTap(_ recognizer: UITapGestureRecognizer) {
            guard let sceneView else { return }

            let point = recognizer.location(in: sceneView)
            let hitResults = sceneView.hitTest(point, options: [.searchMode: SCNHitTestSearchMode.all.rawValue])
            let selectedID = hitResults.lazy.compactMap { result -> PlacedModel.ID? in
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

            onSelectModel(selectedID)
        }
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
