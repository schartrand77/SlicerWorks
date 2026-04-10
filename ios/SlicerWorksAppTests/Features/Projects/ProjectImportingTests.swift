import XCTest
@testable import SlicerWorks

final class ProjectImportingTests: XCTestCase {
    func testImporterCopiesSupportedModelsIntoAppStorageAndBuildsProjectEntries() throws {
        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        let importDirectory = tempRoot.appendingPathComponent("Imported", isDirectory: true)
        let sourceSTL = tempRoot.appendingPathComponent("benchy.stl")
        let sourceOBJ = tempRoot.appendingPathComponent("clip.obj")
        try Data("solid benchy".utf8).write(to: sourceSTL)
        try Data("o clip".utf8).write(to: sourceOBJ)

        let importer = FileSystemProjectImporter(
            fileManager: .default,
            baseDirectoryURL: importDirectory
        )

        let importedProject = try importer.importModels(
            from: [sourceSTL, sourceOBJ],
            into: makeImportProject(
                name: "Empty",
                modelURLs: [],
                settings: SliceSettings.recommended(
                    for: .x1Carbon,
                    quality: .balanced,
                    material: .pla
                )
            )
        )

        let importedModels = importedProject.plates[0].models
        XCTAssertEqual(importedModels.count, 2)
        XCTAssertEqual(importedModels.map { $0.name }, ["benchy", "clip"])
        XCTAssertTrue(FileManager.default.fileExists(atPath: importedModels[0].sourceURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: importedModels[1].sourceURL.path))
        XCTAssertNotEqual(importedModels[0].sourceURL, sourceSTL)
        XCTAssertNotEqual(importedModels[1].sourceURL, sourceOBJ)
    }

    func testImporterRejectsUnsupportedModelExtensions() {
        let importer = FileSystemProjectImporter(
            fileManager: .default,
            baseDirectoryURL: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        )

        XCTAssertThrowsError(
            try importer.importModels(
                from: [URL(fileURLWithPath: "/tmp/model.usdz")],
                into: SliceProject.example
            )
        ) { error in
            XCTAssertEqual(error as? ProjectImportError, ProjectImportError(message: "Unsupported model format: .usdz"))
        }
    }
}

private func makeImportProject(name: String, modelURLs: [URL], settings: SliceSettings) -> SliceProject {
    SliceProject(
        id: UUID(),
        name: name,
        plates: [
            BuildPlate(
                id: UUID(),
                name: "Plate 1",
                models: modelURLs.enumerated().map { index, url in
                    PlacedModel(
                        id: UUID(),
                        name: "Model \(index + 1)",
                        sourceURL: url,
                        position: PlatePosition(x: Double(index * 30), y: Double(index * 20)),
                        rotationDegrees: 0,
                        scalePercent: 100,
                        surfacePaintRegions: []
                    )
                }
            )
        ],
        materialAssignments: [],
        sliceSettings: settings
    )
}
