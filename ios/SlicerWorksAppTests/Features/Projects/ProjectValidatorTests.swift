import XCTest
@testable import SlicerWorksApp

final class ProjectValidatorTests: XCTestCase {
    func testValidatorAcceptsSupportedProject() {
        let project = SliceProject(
            id: UUID(),
            name: "Benchy",
            modelURL: URL(fileURLWithPath: "/tmp/benchy.3mf"),
            materialAssignments: [],
            layerHeightMM: 0.2,
            infillPercent: 15
        )

        let issues = DefaultProjectValidator().validate(project: project, printer: .x1Carbon)

        XCTAssertTrue(issues.isEmpty)
    }

    func testValidatorRejectsBlankNameUnsupportedFormatAndOutOfRangeSettings() {
        let project = SliceProject(
            id: UUID(),
            name: "   ",
            modelURL: URL(fileURLWithPath: "/tmp/benchy.gltf"),
            materialAssignments: [],
            layerHeightMM: 0.4,
            infillPercent: 110
        )

        let issues = DefaultProjectValidator().validate(project: project, printer: .x1Carbon)

        XCTAssertEqual(
            Set(issues.map(\.id)),
            Set(["project-name", "model-format", "layer-height", "infill"])
        )
    }

    func testValidatorRejectsDuplicateFaceAssignments() {
        let material = Filament(brand: "Bambu", material: "PLA", colorHex: "#FFFFFF")
        let project = SliceProject(
            id: UUID(),
            name: "Bracket",
            modelURL: URL(fileURLWithPath: "/tmp/bracket.stl"),
            materialAssignments: [
                MaterialAssignment(faceIdentifier: "face-1", filament: material),
                MaterialAssignment(faceIdentifier: "face-1", filament: material)
            ],
            layerHeightMM: 0.16,
            infillPercent: 20
        )

        let issues = DefaultProjectValidator().validate(project: project, printer: .p1S)

        XCTAssertEqual(issues.map(\.id), ["material-assignments"])
    }
}
