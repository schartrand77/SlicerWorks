import XCTest
@testable import SlicerWorksApp

@MainActor
final class AppStoreTests: XCTestCase {
    func testPrepareSliceStoresLatestSliceResultAndSuccessStatus() async {
        let result = SliceResult(
            gcodeURL: URL(fileURLWithPath: "/tmp/test.gcode"),
            estimatedPrintTimeMinutes: 42,
            estimatedFilamentGrams: 12.5
        )
        let store = AppStore(
            environment: AppEnvironment(
                slicerEngine: TestSlicerEngine(result: result),
                deviceGateway: RecordingDeviceGateway(),
                projectRepository: InMemoryProjectRepository(),
                projectValidator: DefaultProjectValidator()
            )
        )

        await store.prepareSlice()

        XCTAssertEqual(store.latestSliceResult, result)
        XCTAssertEqual(store.sliceStatus, .success(message: "Sliced successfully"))
        XCTAssertEqual(store.uploadStatus, .idle(message: "Ready to upload"))
    }

    func testPrepareSliceFailureClearsLatestResultAndSetsFailureStatus() async {
        let store = AppStore(
            environment: AppEnvironment(
                slicerEngine: FailingSlicerEngine(),
                deviceGateway: RecordingDeviceGateway(),
                projectRepository: InMemoryProjectRepository(),
                projectValidator: DefaultProjectValidator()
            )
        )

        await store.prepareSlice()

        XCTAssertNil(store.latestSliceResult)
        XCTAssertEqual(store.sliceStatus, .failure(.sliceFailed(reason: TestError.slice.localizedDescription)))
    }

    func testUploadWithoutSliceSetsMissingSliceStatus() async {
        let deviceGateway = RecordingDeviceGateway()
        let store = AppStore(
            environment: AppEnvironment(
                slicerEngine: TestSlicerEngine(result: .example),
                deviceGateway: deviceGateway,
                projectRepository: InMemoryProjectRepository(),
                projectValidator: DefaultProjectValidator()
            )
        )

        await store.pushLatestSliceToPrinter()

        XCTAssertEqual(store.uploadStatus, .failure(.missingSliceResult))
        XCTAssertNil(deviceGateway.uploadedResult)
    }

    func testUploadUsesLatestSliceResult() async {
        let result = SliceResult(
            gcodeURL: URL(fileURLWithPath: "/tmp/queued.gcode"),
            estimatedPrintTimeMinutes: 60,
            estimatedFilamentGrams: 20
        )
        let deviceGateway = RecordingDeviceGateway()
        let store = AppStore(
            environment: AppEnvironment(
                slicerEngine: TestSlicerEngine(result: result),
                deviceGateway: deviceGateway,
                projectRepository: InMemoryProjectRepository(),
                projectValidator: DefaultProjectValidator()
            )
        )

        await store.prepareSlice()
        await store.pushLatestSliceToPrinter()

        XCTAssertEqual(deviceGateway.uploadedResult, result)
        XCTAssertEqual(deviceGateway.uploadedPrinter, store.selectedPrinter)
        XCTAssertEqual(store.uploadStatus, .success(message: "Upload queued"))
    }

    func testLoadLastProjectRestoresProjectAndPrinter() {
        let savedProject = SliceProject(
            id: UUID(),
            name: "Saved Cube",
            modelURL: URL(fileURLWithPath: "/tmp/saved.3mf"),
            materialAssignments: [],
            layerHeightMM: 0.12,
            infillPercent: 25
        )
        let repository = InMemoryProjectRepository(
            document: SliceProjectDocument(
                project: savedProject,
                lastUsedPrinter: .a1Mini,
                updatedAt: .now
            )
        )
        let store = AppStore(
            environment: AppEnvironment(
                slicerEngine: TestSlicerEngine(result: .example),
                deviceGateway: RecordingDeviceGateway(),
                projectRepository: repository,
                projectValidator: DefaultProjectValidator()
            )
        )

        store.loadLastProject()

        XCTAssertEqual(store.activeProject, savedProject)
        XCTAssertEqual(store.selectedPrinter, .a1Mini)
        XCTAssertEqual(store.projectStatus, .success(message: "Loaded saved project"))
    }

    func testSaveActiveProjectPersistsCurrentState() throws {
        let repository = InMemoryProjectRepository()
        let store = AppStore(
            environment: AppEnvironment(
                slicerEngine: TestSlicerEngine(result: .example),
                deviceGateway: RecordingDeviceGateway(),
                projectRepository: repository,
                projectValidator: DefaultProjectValidator()
            )
        )
        let currentProject = SliceProject(
            id: UUID(),
            name: "Bracket",
            modelURL: URL(fileURLWithPath: "/tmp/bracket.stl"),
            materialAssignments: [],
            layerHeightMM: 0.16,
            infillPercent: 30
        )
        store.activeProject = currentProject
        store.selectedPrinter = .p1S

        store.saveActiveProject()

        let document = try XCTUnwrap(repository.loadLastProject())
        XCTAssertEqual(document.project, currentProject)
        XCTAssertEqual(document.lastUsedPrinter, .p1S)
        XCTAssertEqual(store.projectStatus, .success(message: "Project saved locally"))
    }

    func testChangingProjectAfterInitialLoadTriggersAutosave() throws {
        let repository = InMemoryProjectRepository()
        let store = AppStore(
            environment: AppEnvironment(
                slicerEngine: TestSlicerEngine(result: .example),
                deviceGateway: RecordingDeviceGateway(),
                projectRepository: repository,
                projectValidator: DefaultProjectValidator()
            )
        )

        store.loadLastProject()
        store.activeProject = SliceProject(
            id: UUID(),
            name: "Auto Saved Part",
            modelURL: URL(fileURLWithPath: "/tmp/part.stl"),
            materialAssignments: [],
            layerHeightMM: 0.2,
            infillPercent: 10
        )

        let document = try XCTUnwrap(repository.loadLastProject())
        XCTAssertEqual(document.project.name, "Auto Saved Part")
        XCTAssertEqual(store.projectStatus, .success(message: "Project saved locally"))
    }

    func testChangingProjectRefreshesValidationIssues() {
        let store = AppStore(
            environment: AppEnvironment(
                slicerEngine: TestSlicerEngine(result: .example),
                deviceGateway: RecordingDeviceGateway(),
                projectRepository: InMemoryProjectRepository(),
                projectValidator: DefaultProjectValidator()
            )
        )

        store.activeProject = SliceProject(
            id: UUID(),
            name: "",
            modelURL: URL(fileURLWithPath: "/tmp/part.unsupported"),
            materialAssignments: [],
            layerHeightMM: 0.5,
            infillPercent: -1
        )

        XCTAssertEqual(
            Set(store.projectValidationIssues.map(\.id)),
            Set(["project-name", "model-format", "layer-height", "infill"])
        )
    }
}

private struct TestSlicerEngine: SlicerEngine {
    let result: SliceResult

    func slice(project: SliceProject, profile: BambuPrinterProfile) async throws -> SliceResult {
        result
    }
}

private struct FailingSlicerEngine: SlicerEngine {
    func slice(project: SliceProject, profile: BambuPrinterProfile) async throws -> SliceResult {
        throw TestError.slice
    }
}

private final class RecordingDeviceGateway: BambuDeviceGateway {
    private(set) var uploadedResult: SliceResult?
    private(set) var uploadedPrinter: BambuPrinterProfile?

    func upload(result: SliceResult, to printer: BambuPrinterProfile) async throws {
        uploadedResult = result
        uploadedPrinter = printer
    }
}

private enum TestError: Error {
    case slice
}

private extension SliceResult {
    static let example = SliceResult(
        gcodeURL: URL(fileURLWithPath: "/tmp/example.gcode"),
        estimatedPrintTimeMinutes: 100,
        estimatedFilamentGrams: 18
    )
}
