import Foundation
import Combine
import PencilKit
import SwiftUI

@MainActor
final class AppStore: ObservableObject {
    @Published var selectedPlateID: BuildPlate.ID? = SliceProject.example.plates.first?.id
    @Published var selectedModelID: PlacedModel.ID? = SliceProject.example.plates.first?.models.first?.id
    @Published var selectedPrinter: BambuPrinterProfile = .x1Carbon {
        didSet {
            handleProjectStateChange()
        }
    }
    @Published var selectedLANPrinterID: BambuLANPrinter.ID?
    @Published var activeProject: SliceProject = .example {
        didSet {
            handleProjectStateChange()
        }
    }
    @Published var selectedTool: PaintingTool = .paintBrush
    @Published var activePaintingStroke: PaintingStroke?
    @Published var pencilState: PencilState = .idle
    @Published private(set) var latestSliceResult: SliceResult?
    @Published private(set) var sliceStatus: AppStatus = .idle(message: "Ready")
    @Published private(set) var uploadStatus: AppStatus = .idle(message: "No upload yet")
    @Published private(set) var projectStatus: AppStatus = .idle(message: "Example project loaded")
    @Published private(set) var discoveryStatus: AppStatus = .idle(message: "No LAN scan yet")
    @Published private(set) var projectValidationIssues: [ProjectValidationIssue] = []
    @Published private(set) var knownLANPrinters: [BambuLANPrinter] = []
    @Published private(set) var discoveredLANPrinters: [BambuLANPrinter] = []

    private let slicerEngine: SlicerEngine
    private let deviceGateway: BambuDeviceGateway
    private let knownPrinterStore: KnownPrinterStoring
    private let projectRepository: ProjectRepository
    private let projectValidator: ProjectValidating
    private let projectImporter: ProjectImporting
    private var isRestoringProject = false
    private var hasCompletedInitialLoad = false

    init(environment: AppEnvironment? = nil) {
        let resolvedEnvironment = environment ?? .live
        self.slicerEngine = resolvedEnvironment.slicerEngine
        self.deviceGateway = resolvedEnvironment.deviceGateway
        self.knownPrinterStore = resolvedEnvironment.knownPrinterStore
        self.projectRepository = resolvedEnvironment.projectRepository
        self.projectValidator = resolvedEnvironment.projectValidator
        self.projectImporter = resolvedEnvironment.projectImporter
        restoreKnownPrinters()
        refreshProjectValidation()
    }

    func prepareSlice() async {
        sliceStatus = .working(message: "Slicing \(activeProject.name)...")

        do {
            let result = try await slicerEngine.slice(project: activeProject, profile: selectedPrinter)
            latestSliceResult = result
            sliceStatus = .success(message: "Sliced successfully")
            uploadStatus = .idle(message: "Ready to upload")
        } catch {
            latestSliceResult = nil
            sliceStatus = .failure(.sliceFailed(reason: error.localizedDescription))
        }
    }

    func pushLatestSliceToPrinter() async {
        guard let latestSliceResult else {
            uploadStatus = .failure(.missingSliceResult)
            return
        }

        guard let selectedLANPrinter else {
            uploadStatus = .failure(.missingPrinterSelection)
            return
        }

        guard selectedLANPrinter.hasAccessCode else {
            uploadStatus = .failure(.missingPrinterAccessCode)
            return
        }

        uploadStatus = .working(message: "Uploading to \(selectedLANPrinter.name)...")

        do {
            try await deviceGateway.upload(result: latestSliceResult, to: selectedLANPrinter)
            uploadStatus = .success(message: "Upload queued")
        } catch {
            uploadStatus = .failure(.uploadFailed(reason: error.localizedDescription))
        }
    }

    func discoverPrintersOnLAN() async {
        discoveryStatus = .working(message: "Scanning LAN for Bambu printers...")

        do {
            let printers = try await deviceGateway.discoverPrinters()
            discoveredLANPrinters = printers
            discoveryStatus = .success(
                message: printers.isEmpty
                    ? "No Bambu printers found on LAN"
                    : "Found \(printers.count) Bambu printer\(printers.count == 1 ? "" : "s")"
            )
        } catch {
            discoveryStatus = .failure(.printerDiscoveryFailed(reason: error.localizedDescription))
        }
    }

    func addKnownLANPrinter(_ printer: BambuLANPrinter, accessCode: String) {
        let normalizedAccessCode = accessCode.trimmingCharacters(in: .whitespacesAndNewlines)
        let existingPrinter = knownLANPrinters.first(where: { $0.serialNumber == printer.serialNumber || $0.host == printer.host })

        if let existingPrinter,
           let index = knownLANPrinters.firstIndex(where: { $0.id == existingPrinter.id }) {
            knownLANPrinters[index].name = printer.name
            knownLANPrinters[index].host = printer.host
            knownLANPrinters[index].serialNumber = printer.serialNumber
            knownLANPrinters[index].profile = printer.profile
            knownLANPrinters[index].accessCode = normalizedAccessCode
        } else {
            var storedPrinter = printer
            storedPrinter.accessCode = normalizedAccessCode
            knownLANPrinters.append(storedPrinter)
        }

        selectLANPrinter(existingPrinter?.id ?? printer.id)
        persistKnownPrinters()
    }

    func updateLANPrinterAccessCode(_ printerID: BambuLANPrinter.ID, accessCode: String) {
        guard let index = knownLANPrinters.firstIndex(where: { $0.id == printerID }) else {
            return
        }

        knownLANPrinters[index].accessCode = accessCode.trimmingCharacters(in: .whitespacesAndNewlines)
        persistKnownPrinters()
        discoveryStatus = .success(message: "Updated access code for \(knownLANPrinters[index].name)")
    }

    func selectLANPrinter(_ printerID: BambuLANPrinter.ID?) {
        selectedLANPrinterID = printerID

        guard let selectedLANPrinter else {
            return
        }

        selectedPrinter = selectedLANPrinter.profile
        discoveryStatus = .success(message: "Selected \(selectedLANPrinter.name)")
    }

    func loadLastProject() {
        do {
            guard let document = try projectRepository.loadLastProject() else {
                hasCompletedInitialLoad = true
                selectedPlateID = activeProject.plates.first?.id
                selectedModelID = activeProject.plates.first?.models.first?.id
                refreshProjectValidation()
                projectStatus = .idle(message: "No saved project found")
                return
            }

            isRestoringProject = true
            activeProject = document.project
            selectedPrinter = document.lastUsedPrinter
            selectedPlateID = document.project.plates.first?.id
            selectedModelID = document.project.plates.first?.models.first?.id
            isRestoringProject = false
            hasCompletedInitialLoad = true
            refreshProjectValidation()
            projectStatus = .success(message: "Loaded saved project")
        } catch {
            hasCompletedInitialLoad = true
            projectStatus = .failure(.projectLoadFailed(reason: error.localizedDescription))
        }
    }

    func saveActiveProject() {
        let document = SliceProjectDocument(
            project: activeProject,
            lastUsedPrinter: selectedPrinter,
            updatedAt: .now
        )

        do {
            try projectRepository.saveProject(document)
            projectStatus = .success(message: "Project saved locally")
        } catch {
            projectStatus = .failure(.projectSaveFailed(reason: error.localizedDescription))
        }
    }

    func applyRecommendedSettings() {
        let currentSettings = activeProject.sliceSettings
        activeProject.sliceSettings = .recommended(
            for: selectedPrinter,
            quality: currentSettings.qualityPreset,
            material: currentSettings.filamentMaterial
        )
    }

    func applyQualityPreset(_ preset: SliceQualityPreset) {
        activeProject.sliceSettings = .recommended(
            for: selectedPrinter,
            quality: preset,
            material: activeProject.sliceSettings.filamentMaterial
        )
    }

    func applyMaterialPreset(_ material: FilamentMaterial) {
        activeProject.sliceSettings = .recommended(
            for: selectedPrinter,
            quality: activeProject.sliceSettings.qualityPreset,
            material: material
        )
    }

    func addPlate() {
        let nextIndex = activeProject.plates.count + 1
        let plate = BuildPlate(id: UUID(), name: "Plate \(nextIndex)", models: [])
        activeProject.plates.append(plate)
        selectedPlateID = plate.id
        selectedModelID = nil
    }

    func addSampleModel() {
        guard let selectedPlateIndex else { return }

        let modelNumber = activeProject.plates[selectedPlateIndex].models.count + 1
        let model = PlacedModel(
            id: UUID(),
            name: "Model \(modelNumber)",
            sourceURL: URL(fileURLWithPath: "/tmp/model_\(modelNumber).stl"),
            position: PlatePosition(x: Double((modelNumber - 1) * 28), y: Double((modelNumber - 1) * 18)),
            rotationDegrees: 0,
            scalePercent: 100,
            surfacePaintRegions: []
        )
        activeProject.plates[selectedPlateIndex].models.append(model)
        selectedModelID = model.id
    }

    func importModels(from urls: [URL]) {
        projectStatus = .working(message: "Importing \(urls.count) model\(urls.count == 1 ? "" : "s")...")

        do {
            let importedProject = try projectImporter.importModels(from: urls, into: activeProject)
            activeProject = importedProject
            selectedPlateID = importedProject.plates.first?.id
            selectedModelID = importedProject.plates.first?.models.last?.id
            projectStatus = .success(
                message: "Imported \(urls.count) model\(urls.count == 1 ? "" : "s")"
            )
        } catch {
            projectStatus = .failure(.projectImportFailed(reason: error.localizedDescription))
        }
    }

    func projectImportDidFail(_ error: Error) {
        projectStatus = .failure(.projectImportFailed(reason: error.localizedDescription))
    }

    func selectModel(_ modelID: PlacedModel.ID?) {
        selectedModelID = modelID
        if let selectedModel {
            pencilState.lastEventSummary = "Selected \(selectedModel.name). Pencil edits apply to this model only."
        }
    }

    func moveSelectedModel(by translation: CGSize) {
        guard let selectedPlateIndex,
              let selectedModelID,
              let selectedModelIndex = activeProject.plates[selectedPlateIndex].models.firstIndex(where: { $0.id == selectedModelID }) else {
            return
        }

        let clampedX = clampWorkspaceCoordinate(
            activeProject.plates[selectedPlateIndex].models[selectedModelIndex].position.x + translation.width,
            limit: 240
        )
        let clampedY = clampWorkspaceCoordinate(
            activeProject.plates[selectedPlateIndex].models[selectedModelIndex].position.y + translation.height,
            limit: 180
        )

        activeProject.plates[selectedPlateIndex].models[selectedModelIndex].position = PlatePosition(
            x: clampedX,
            y: clampedY
        )
    }

    func nudgeSelectedModel(x: Double = 0, y: Double = 0) {
        moveSelectedModel(by: CGSize(width: x, height: y))
    }

    func rotateSelectedModel(by degrees: Double) {
        guard let selectedPlateIndex,
              let selectedModelID,
              let selectedModelIndex = activeProject.plates[selectedPlateIndex].models.firstIndex(where: { $0.id == selectedModelID }) else {
            return
        }

        activeProject.plates[selectedPlateIndex].models[selectedModelIndex].rotationDegrees += degrees
    }

    func scaleSelectedModel(by percentageDelta: Int) {
        guard let selectedPlateIndex,
              let selectedModelID,
              let selectedModelIndex = activeProject.plates[selectedPlateIndex].models.firstIndex(where: { $0.id == selectedModelID }) else {
            return
        }

        let current = activeProject.plates[selectedPlateIndex].models[selectedModelIndex].scalePercent
        activeProject.plates[selectedPlateIndex].models[selectedModelIndex].scalePercent = min(max(current + percentageDelta, 25), 400)
    }

    func handlePencilHover(
        location: CGPoint?,
        azimuth: CGFloat,
        altitude: CGFloat,
        zOffset: CGFloat,
        roll: CGFloat
    ) {
        pencilState.isHovering = location != nil
        pencilState.hoverLocation = location
        pencilState.hoverAzimuthAngle = azimuth
        pencilState.hoverAltitudeAngle = altitude
        pencilState.hoverZOffset = zOffset
        pencilState.barrelRollAngle = roll
        pencilState.lastEventSummary = location == nil ? "Hover ended" : "Hover preview active"
    }

    func handlePencilDoubleTap() {
        selectedTool = selectedTool.next
        pencilState.doubleTapCount += 1
        pencilState.lastEventSummary = "Double-tap switched to \(selectedTool.title)"
    }

    func handlePencilSqueeze() {
        pencilState.squeezeEnabled.toggle()
        pencilState.paletteVisible.toggle()
        pencilState.lastEventSummary = pencilState.paletteVisible ? "Squeeze opened quick palette" : "Squeeze closed quick palette"
    }

    func beginPaintingStroke(at location: CGPoint, force: CGFloat, azimuth: CGFloat, roll: CGFloat) {
        guard let selectedModelID else {
            pencilState.lastEventSummary = "Select a model in the Slice workspace before painting."
            activePaintingStroke = nil
            return
        }
        pencilState.lastContactLocation = location
        pencilState.lastPressure = force
        pencilState.barrelRollAngle = roll
        pencilState.hoverAzimuthAngle = azimuth
        pencilState.lastEventSummary = "Painting outer surfaces with \(activeProject.sliceSettings.surfaceColor.displayName)"
        activePaintingStroke = PaintingStroke(
            id: UUID(),
            modelID: selectedModelID,
            tool: selectedTool,
            color: activeProject.sliceSettings.surfaceColor,
            points: [location],
            forceSamples: [force],
            rollAngle: roll
        )
    }

    func continuePaintingStroke(at location: CGPoint, force: CGFloat, azimuth: CGFloat, roll: CGFloat) {
        guard activePaintingStroke != nil else { return }
        pencilState.lastContactLocation = location
        pencilState.lastPressure = force
        pencilState.barrelRollAngle = roll
        pencilState.hoverAzimuthAngle = azimuth
        activePaintingStroke?.points.append(location)
        activePaintingStroke?.forceSamples.append(force)
        activePaintingStroke?.rollAngle = roll
    }

    func endPaintingStroke() {
        if let activePaintingStroke {
            appendSurfacePaintRegion(
                SurfacePaintRegion(
                    id: activePaintingStroke.id,
                    tool: activePaintingStroke.tool,
                    color: activePaintingStroke.color,
                    points: activePaintingStroke.points,
                    forceSamples: activePaintingStroke.forceSamples,
                    rollAngle: activePaintingStroke.rollAngle
                )
            )
        }
        activePaintingStroke = nil
        pencilState.lastEventSummary = "Surface paint committed. Infill stays \(activeProject.sliceSettings.infillColor.displayName) unless changed separately."
    }

    func clearPaintingSession() {
        for plateIndex in activeProject.plates.indices {
            for modelIndex in activeProject.plates[plateIndex].models.indices {
                activeProject.plates[plateIndex].models[modelIndex].surfacePaintRegions.removeAll()
            }
        }
        activePaintingStroke = nil
        pencilState.lastEventSummary = "Cleared painted marks"
    }

    func clearSelectedModelPainting() {
        guard updateSelectedModel({ $0.surfacePaintRegions.removeAll() }) else { return }
        if activePaintingStroke?.modelID == selectedModelID {
            activePaintingStroke = nil
        }
        pencilState.lastEventSummary = "Cleared surface paint for selected model"
    }

    var selectedPlate: BuildPlate? {
        guard let selectedPlateIndex else { return nil }
        return activeProject.plates[selectedPlateIndex]
    }

    var selectedLANPrinter: BambuLANPrinter? {
        guard let selectedLANPrinterID else { return nil }
        return knownLANPrinters.first(where: { $0.id == selectedLANPrinterID })
    }

    var newlyDiscoveredLANPrinters: [BambuLANPrinter] {
        discoveredLANPrinters.filter { discoveredPrinter in
            knownLANPrinters.contains(where: { knownPrinter in
                knownPrinter.serialNumber == discoveredPrinter.serialNumber || knownPrinter.host == discoveredPrinter.host
            }) == false
        }
    }

    var selectedModel: PlacedModel? {
        guard let selectedPlateIndex,
              let selectedModelID,
              let selectedModelIndex = activeProject.plates[selectedPlateIndex].models.firstIndex(where: { $0.id == selectedModelID }) else {
            return nil
        }

        return activeProject.plates[selectedPlateIndex].models[selectedModelIndex]
    }

    var selectedModelPaintingStrokes: [PaintingStroke] {
        guard let selectedModel else { return [] }

        return selectedModel.surfacePaintRegions.map { region in
            PaintingStroke(
                id: region.id,
                modelID: selectedModel.id,
                tool: region.tool,
                color: region.color,
                points: region.points,
                forceSamples: region.forceSamples,
                rollAngle: region.rollAngle
            )
        }
    }

    func paintingStrokeCount(for modelID: PlacedModel.ID) -> Int {
        activeProject.allModels.first(where: { $0.id == modelID })?.surfacePaintRegions.count ?? 0
    }

    private var selectedPlateIndex: Int? {
        if let selectedPlateID,
           let selectedPlateIndex = activeProject.plates.firstIndex(where: { $0.id == selectedPlateID }) {
            return selectedPlateIndex
        }

        if activeProject.plates.isEmpty == false {
            selectedPlateID = activeProject.plates[0].id
            return 0
        }

        return nil
    }

    private func clampWorkspaceCoordinate(_ value: Double, limit: Double) -> Double {
        min(max(value, -limit), limit)
    }

    @discardableResult
    private func updateSelectedModel(_ update: (inout PlacedModel) -> Void) -> Bool {
        guard let selectedPlateIndex,
              let selectedModelID,
              let selectedModelIndex = activeProject.plates[selectedPlateIndex].models.firstIndex(where: { $0.id == selectedModelID }) else {
            return false
        }

        update(&activeProject.plates[selectedPlateIndex].models[selectedModelIndex])
        return true
    }

    private func appendSurfacePaintRegion(_ region: SurfacePaintRegion) {
        _ = updateSelectedModel { model in
            model.surfacePaintRegions.append(region)
        }
    }

    private func handleProjectStateChange() {
        refreshProjectValidation()
        invalidateSlicePreview()

        guard hasCompletedInitialLoad, isRestoringProject == false else {
            return
        }

        saveActiveProject()
    }

    private func refreshProjectValidation() {
        projectValidationIssues = projectValidator.validate(project: activeProject, printer: selectedPrinter)
    }

    private func invalidateSlicePreview() {
        latestSliceResult = nil
        if sliceStatus.isWorking == false {
            sliceStatus = .idle(message: "Settings changed. Slice to refresh estimates.")
        }
        uploadStatus = .idle(message: "No upload yet")
    }

    private func restoreKnownPrinters() {
        do {
            knownLANPrinters = try knownPrinterStore.loadPrinters()
            if let firstPrinter = knownLANPrinters.first {
                selectedLANPrinterID = firstPrinter.id
                selectedPrinter = firstPrinter.profile
                discoveryStatus = .idle(message: "Loaded \(knownLANPrinters.count) saved printer\(knownLANPrinters.count == 1 ? "" : "s")")
            }
        } catch {
            discoveryStatus = .failure(.printerDiscoveryFailed(reason: error.localizedDescription))
        }
    }

    private func persistKnownPrinters() {
        do {
            try knownPrinterStore.savePrinters(knownLANPrinters)
        } catch {
            discoveryStatus = .failure(.printerSaveFailed(reason: error.localizedDescription))
        }
    }
}

struct PencilState: Equatable {
    var isHovering: Bool
    var hoverLocation: CGPoint?
    var lastContactLocation: CGPoint?
    var hoverAzimuthAngle: CGFloat
    var hoverAltitudeAngle: CGFloat
    var hoverZOffset: CGFloat
    var lastPressure: CGFloat
    var squeezeEnabled: Bool
    var paletteVisible: Bool
    var doubleTapCount: Int
    var barrelRollAngle: CGFloat
    var lastEventSummary: String

    static let idle = PencilState(
        isHovering: false,
        hoverLocation: nil,
        lastContactLocation: nil,
        hoverAzimuthAngle: .zero,
        hoverAltitudeAngle: .zero,
        hoverZOffset: .zero,
        lastPressure: .zero,
        squeezeEnabled: false,
        paletteVisible: false,
        doubleTapCount: 0,
        barrelRollAngle: .zero,
        lastEventSummary: "Ready for Apple Pencil input"
    )
}

struct PaintingStroke: Identifiable, Equatable {
    let id: UUID
    var modelID: PlacedModel.ID
    var tool: PaintingTool
    var color: PrintColorOption
    var points: [CGPoint]
    var forceSamples: [CGFloat]
    var rollAngle: CGFloat
}
