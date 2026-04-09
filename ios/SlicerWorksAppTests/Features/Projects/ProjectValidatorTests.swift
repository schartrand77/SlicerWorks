import XCTest
@testable import SlicerWorks

final class ProjectValidatorTests: XCTestCase {
    func testValidatorAcceptsSupportedProject() {
        let project = makeProject(
            name: "Benchy",
            modelURLs: [URL(fileURLWithPath: "/tmp/benchy.3mf")],
            settings: .recommended(for: .x1Carbon, quality: .balanced, material: .pla)
        )

        let issues = DefaultProjectValidator().validate(project: project, printer: .x1Carbon)

        XCTAssertTrue(issues.isEmpty)
    }

    func testValidatorRejectsBlankNameUnsupportedFormatAndOutOfRangeSettings() {
        var settings = SliceSettings.recommended(for: .x1Carbon, quality: .balanced, material: .pla)
        settings.layerHeightMM = 0.4
        settings.infillPercent = 110

        let project = makeProject(
            name: "   ",
            modelURLs: [URL(fileURLWithPath: "/tmp/benchy.gltf")],
            settings: settings
        )

        let issues = DefaultProjectValidator().validate(project: project, printer: .x1Carbon)

        XCTAssertEqual(
            Set(issues.map(\.id)),
            Set(["project-name", "model-format", "layer-height", "infill"])
        )
    }

    func testValidatorRejectsEmptyPlateAndDuplicateFaceAssignments() {
        let material = Filament(brand: "Bambu", material: "PLA", colorHex: "#FFFFFF")
        let project = SliceProject(
            id: UUID(),
            name: "Bracket",
            plates: [BuildPlate(id: UUID(), name: "Plate 1", models: [])],
            materialAssignments: [
                MaterialAssignment(faceIdentifier: "face-1", filament: material),
                MaterialAssignment(faceIdentifier: "face-1", filament: material)
            ],
            sliceSettings: .recommended(for: .p1S, quality: .balanced, material: .pla)
        )

        let issues = DefaultProjectValidator().validate(project: project, printer: .p1S)

        XCTAssertEqual(Set(issues.map(\.id)), Set(["material-assignments", "model-format"]))
    }
}

private func makeProject(name: String, modelURLs: [URL], settings: SliceSettings) -> SliceProject {
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
