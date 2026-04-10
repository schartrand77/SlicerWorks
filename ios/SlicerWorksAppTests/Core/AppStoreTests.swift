import XCTest
@testable import SlicerWorks

@MainActor
final class AppStoreTests: XCTestCase {
    func testPrepareSliceStoresLatestSliceResultAndSuccessStatus() async {
        let result = SliceResult(
            gcodeURL: URL(fileURLWithPath: "/tmp/test.gcode"),
            estimatedPrintTimeMinutes: 42,
            estimatedFilamentGrams: 12.5,
            estimatedFilamentMeters: 4.11,
            selectedQualityPreset: .balanced,
            selectedMaterial: .pla
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
            estimatedFilamentGrams: 20,
            estimatedFilamentMeters: 6.41,
            selectedQualityPreset: .fine,
            selectedMaterial: .petg
        )
        let deviceGateway = RecordingDeviceGateway()
        let store = AppStore(
            environment: AppEnvironment(
                slicerEngine: TestSlicerEngine(result: result),
                deviceGateway: deviceGateway,
                knownPrinterStore: InMemoryKnownPrinterStore(printers: [.studioP1S]),
                projectRepository: InMemoryProjectRepository(),
                projectValidator: DefaultProjectValidator()
            )
        )

        store.selectLANPrinter(BambuLANPrinter.studioP1S.id)
        await store.prepareSlice()
        await store.pushLatestSliceToPrinter()

        XCTAssertEqual(deviceGateway.uploadedResult, result)
        XCTAssertEqual(deviceGateway.uploadedPrinter, .studioP1S)
        XCTAssertEqual(store.uploadStatus, .success(message: "Upload queued"))
    }

    func testUploadWithoutSelectedLANPrinterSetsFailureStatus() async {
        let store = AppStore(
            environment: AppEnvironment(
                slicerEngine: TestSlicerEngine(result: .example),
                deviceGateway: RecordingDeviceGateway(),
                projectRepository: InMemoryProjectRepository(),
                projectValidator: DefaultProjectValidator()
            )
        )

        await store.prepareSlice()
        await store.pushLatestSliceToPrinter()

        XCTAssertEqual(store.uploadStatus, .failure(.missingPrinterSelection))
    }

    func testUploadWithoutPrinterAccessCodeSetsFailureStatus() async {
        let store = AppStore(
            environment: AppEnvironment(
                slicerEngine: TestSlicerEngine(result: .example),
                deviceGateway: RecordingDeviceGateway(),
                knownPrinterStore: InMemoryKnownPrinterStore(printers: [.studioP1SWithoutCode]),
                projectRepository: InMemoryProjectRepository(),
                projectValidator: DefaultProjectValidator()
            )
        )

        store.selectLANPrinter(BambuLANPrinter.studioP1SWithoutCode.id)
        await store.prepareSlice()
        await store.pushLatestSliceToPrinter()

        XCTAssertEqual(store.uploadStatus, .failure(.missingPrinterAccessCode))
    }

    func testLoadLastProjectRestoresProjectAndPrinter() {
        let savedProject = makeProject(
            name: "Saved Cube",
            modelURLs: [URL(fileURLWithPath: "/tmp/saved.3mf")],
            settings: .recommended(for: .a1Mini, quality: .fine, material: .pla)
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
        let currentProject = makeProject(
            name: "Bracket",
            modelURLs: [URL(fileURLWithPath: "/tmp/bracket.stl")],
            settings: .recommended(for: .p1S, quality: .balanced, material: .petg)
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
        store.activeProject = makeProject(
            name: "Auto Saved Part",
            modelURLs: [URL(fileURLWithPath: "/tmp/part.stl")],
            settings: .recommended(for: .x1Carbon, quality: .draft, material: .pla)
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
        var invalidSettings = SliceSettings.recommended(for: .x1Carbon, quality: .balanced, material: .pla)
        invalidSettings.layerHeightMM = 0.5
        invalidSettings.infillPercent = -1
        invalidSettings.brimWidthMM = 5
        invalidSettings.adhesionType = .none

        store.activeProject = makeProject(
            name: "",
            modelURLs: [URL(fileURLWithPath: "/tmp/part.unsupported")],
            settings: invalidSettings
        )

        XCTAssertEqual(
            Set(store.projectValidationIssues.map(\.id)),
            Set(["project-name", "model-format", "layer-height", "infill", "brim-width"])
        )
    }

    func testApplyRecommendedSettingsUsesCurrentPrinterQualityAndMaterial() {
        let store = AppStore(
            environment: AppEnvironment(
                slicerEngine: TestSlicerEngine(result: .example),
                deviceGateway: RecordingDeviceGateway(),
                projectRepository: InMemoryProjectRepository(),
                projectValidator: DefaultProjectValidator()
            )
        )
        store.selectedPrinter = .a1Mini
        store.activeProject.sliceSettings.qualityPreset = .fine
        store.activeProject.sliceSettings.filamentMaterial = .petg

        store.applyRecommendedSettings()

        XCTAssertEqual(
            store.activeProject.sliceSettings,
            .recommended(for: .a1Mini, quality: .fine, material: .petg)
        )
    }

    func testPaintingCommitsSurfaceRegionToSelectedModelAndPersists() throws {
        let repository = InMemoryProjectRepository()
        let store = AppStore(
            environment: AppEnvironment(
                slicerEngine: TestSlicerEngine(result: .example),
                deviceGateway: RecordingDeviceGateway(),
                projectRepository: repository,
                projectValidator: DefaultProjectValidator()
            )
        )

        let start = CGPoint(x: 24, y: 36)
        let end = CGPoint(x: 40, y: 52)

        store.beginPaintingStroke(at: start, force: 0.8, azimuth: 0.4, roll: 0.2)
        store.continuePaintingStroke(at: end, force: 0.9, azimuth: 0.5, roll: 0.3)
        store.endPaintingStroke()
        store.saveActiveProject()

        XCTAssertEqual(store.selectedModelPaintingStrokes.count, 1)
        XCTAssertEqual(store.paintingStrokeCount(for: try XCTUnwrap(store.selectedModelID)), 1)
        XCTAssertEqual(store.selectedModel?.surfacePaintRegions.count, 1)
        XCTAssertEqual(store.selectedModel?.surfacePaintRegions.first?.color, store.activeProject.sliceSettings.surfaceColor)

        let document = try XCTUnwrap(repository.loadLastProject())
        let savedModel = try XCTUnwrap(document.project.plates.first?.models.first)

        XCTAssertEqual(savedModel.surfacePaintRegions.count, 1)
        XCTAssertEqual(savedModel.surfacePaintRegions.first?.points, [start, end])
    }

    func testImportModelsAppendsImportedFilesAndSelectsLastModel() throws {
        let importer = TestProjectImporter()
        let repository = InMemoryProjectRepository()
        let store = AppStore(
            environment: AppEnvironment(
                slicerEngine: TestSlicerEngine(result: .example),
                deviceGateway: RecordingDeviceGateway(),
                projectRepository: repository,
                projectValidator: DefaultProjectValidator(),
                projectImporter: importer
            )
        )

        store.loadLastProject()
        store.importModels(from: [
            URL(fileURLWithPath: "/tmp/bracket.stl"),
            URL(fileURLWithPath: "/tmp/handle.obj")
        ])

        XCTAssertEqual(importer.importedURLs, [
            URL(fileURLWithPath: "/tmp/bracket.stl"),
            URL(fileURLWithPath: "/tmp/handle.obj")
        ])
        XCTAssertEqual(store.projectStatus, .success(message: "Imported 2 models"))
        XCTAssertEqual(store.selectedPlate?.models.suffix(2).map(\.name), ["bracket", "handle"])
        XCTAssertEqual(store.selectedModel?.name, "handle")

        let savedDocument = try XCTUnwrap(repository.loadLastProject())
        XCTAssertEqual(savedDocument.project.plates.first?.models.suffix(2).map(\.name), ["bracket", "handle"])
    }

    func testImportModelsFailureSetsProjectStatusFailure() {
        let store = AppStore(
            environment: AppEnvironment(
                slicerEngine: TestSlicerEngine(result: .example),
                deviceGateway: RecordingDeviceGateway(),
                projectRepository: InMemoryProjectRepository(),
                projectValidator: DefaultProjectValidator(),
                projectImporter: FailingProjectImporter()
            )
        )

        store.importModels(from: [URL(fileURLWithPath: "/tmp/bad.unsupported")])

        XCTAssertEqual(
            store.projectStatus,
            .failure(.projectImportFailed(reason: "Unsupported model format: .unsupported"))
        )
    }

    func testDiscoverPrintersOnLANStoresDiscoveredDevices() async {
        let gateway = RecordingDeviceGateway(discoveredPrinters: [.studioP1S, .deskA1Mini])
        let store = AppStore(
            environment: AppEnvironment(
                slicerEngine: TestSlicerEngine(result: .example),
                deviceGateway: gateway,
                projectRepository: InMemoryProjectRepository(),
                projectValidator: DefaultProjectValidator()
            )
        )

        await store.discoverPrintersOnLAN()

        XCTAssertEqual(store.discoveredLANPrinters, [.studioP1S, .deskA1Mini])
        XCTAssertEqual(store.discoveryStatus, .success(message: "Found 2 Bambu printers"))
    }

    func testAddKnownLANPrinterPersistsSelectionAndProfile() throws {
        let printerStore = InMemoryKnownPrinterStore()
        let store = AppStore(
            environment: AppEnvironment(
                slicerEngine: TestSlicerEngine(result: .example),
                deviceGateway: RecordingDeviceGateway(),
                knownPrinterStore: printerStore,
                projectRepository: InMemoryProjectRepository(),
                projectValidator: DefaultProjectValidator()
            )
        )

        store.addKnownLANPrinter(.studioP1SWithoutCode, accessCode: "12345678")

        XCTAssertEqual(store.knownLANPrinters, [.studioP1S])
        XCTAssertEqual(store.selectedLANPrinter, .studioP1S)
        XCTAssertEqual(store.selectedPrinter, .p1S)
        XCTAssertEqual(try printerStore.loadPrinters(), [.studioP1S])
    }

    func testUpdateLANPrinterAccessCodePersistsCode() throws {
        let printerStore = InMemoryKnownPrinterStore(printers: [.studioP1SWithoutCode])
        let store = AppStore(
            environment: AppEnvironment(
                slicerEngine: TestSlicerEngine(result: .example),
                deviceGateway: RecordingDeviceGateway(),
                knownPrinterStore: printerStore,
                projectRepository: InMemoryProjectRepository(),
                projectValidator: DefaultProjectValidator()
            )
        )

        store.updateLANPrinterAccessCode(BambuLANPrinter.studioP1SWithoutCode.id, accessCode: "updated-code")

        XCTAssertEqual(store.knownLANPrinters.first?.accessCode, "updated-code")
        XCTAssertEqual(try printerStore.loadPrinters().first?.accessCode, "updated-code")
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

private final class TestProjectImporter: ProjectImporting {
    var importedURLs: [URL] = []

    func importModels(from urls: [URL], into project: SliceProject) throws -> SliceProject {
        importedURLs = urls
        var updatedProject = project
        let existingModelCount = updatedProject.plates[0].models.count

        for (index, url) in urls.enumerated() {
            updatedProject.plates[0].models.append(
                PlacedModel(
                    id: UUID(),
                    name: url.deletingPathExtension().lastPathComponent,
                    sourceURL: url,
                    position: PlatePosition(x: Double((existingModelCount + index) * 30), y: 0),
                    rotationDegrees: 0,
                    scalePercent: 100,
                    surfacePaintRegions: []
                )
            )
        }

        return updatedProject
    }
}

private struct FailingProjectImporter: ProjectImporting {
    func importModels(from urls: [URL], into project: SliceProject) throws -> SliceProject {
        throw ProjectImportError(message: "Unsupported model format: .unsupported")
    }
}

private final class RecordingDeviceGateway: BambuDeviceGateway {
    let discoveredPrinters: [BambuLANPrinter]
    private(set) var uploadedResult: SliceResult?
    private(set) var uploadedPrinter: BambuLANPrinter?

    init(discoveredPrinters: [BambuLANPrinter] = []) {
        self.discoveredPrinters = discoveredPrinters
    }

    func discoverPrinters() async throws -> [BambuLANPrinter] {
        discoveredPrinters
    }

    func upload(result: SliceResult, to printer: BambuLANPrinter) async throws {
        uploadedResult = result
        uploadedPrinter = printer
    }
}

private enum TestError: Error {
    case slice
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
                        position: PlatePosition(x: Double(index * 24), y: Double(index * 18)),
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

private extension SliceResult {
    static let example = SliceResult(
        gcodeURL: URL(fileURLWithPath: "/tmp/example.gcode"),
        estimatedPrintTimeMinutes: 100,
        estimatedFilamentGrams: 18,
        estimatedFilamentMeters: 5.87,
        selectedQualityPreset: .balanced,
        selectedMaterial: .pla
    )
}

private extension BambuLANPrinter {
    static let studioP1S = BambuLANPrinter(
        id: UUID(uuidString: "DCA733BA-B59D-480A-8350-54950901E001") ?? UUID(),
        name: "Studio P1S",
        host: "192.168.1.42",
        serialNumber: "P1S-LAB-042",
        profile: .p1S,
        accessCode: "12345678"
    )

    static let studioP1SWithoutCode = BambuLANPrinter(
        id: UUID(uuidString: "DCA733BA-B59D-480A-8350-54950901E001") ?? UUID(),
        name: "Studio P1S",
        host: "192.168.1.42",
        serialNumber: "P1S-LAB-042",
        profile: .p1S,
        accessCode: nil
    )

    static let deskA1Mini = BambuLANPrinter(
        id: UUID(uuidString: "DCA733BA-B59D-480A-8350-54950901E002") ?? UUID(),
        name: "Desk A1 Mini",
        host: "192.168.1.57",
        serialNumber: "A1M-LAB-057",
        profile: .a1Mini,
        accessCode: "A1MINI42"
    )
}
