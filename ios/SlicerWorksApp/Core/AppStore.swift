import Foundation
import PencilKit

@MainActor
final class AppStore: ObservableObject {
    @Published var selectedPrinter: BambuPrinterProfile = .x1Carbon {
        didSet {
            handleProjectStateChange()
        }
    }
    @Published var activeProject: SliceProject = .example {
        didSet {
            handleProjectStateChange()
        }
    }
    @Published var selectedTool: PaintingTool = .paintBrush
    @Published var pencilState: PencilState = .idle
    @Published private(set) var latestSliceResult: SliceResult?
    @Published private(set) var sliceStatus: AppStatus = .idle(message: "Ready")
    @Published private(set) var uploadStatus: AppStatus = .idle(message: "No upload yet")
    @Published private(set) var projectStatus: AppStatus = .idle(message: "Example project loaded")
    @Published private(set) var projectValidationIssues: [ProjectValidationIssue] = []

    private let slicerEngine: SlicerEngine
    private let deviceGateway: BambuDeviceGateway
    private let projectRepository: ProjectRepository
    private let projectValidator: ProjectValidating
    private var isRestoringProject = false
    private var hasCompletedInitialLoad = false

    init(environment: AppEnvironment = .live) {
        self.slicerEngine = environment.slicerEngine
        self.deviceGateway = environment.deviceGateway
        self.projectRepository = environment.projectRepository
        self.projectValidator = environment.projectValidator
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

        uploadStatus = .working(message: "Uploading to \(selectedPrinter.displayName)...")

        do {
            try await deviceGateway.upload(result: latestSliceResult, to: selectedPrinter)
            uploadStatus = .success(message: "Upload queued")
        } catch {
            uploadStatus = .failure(.uploadFailed(reason: error.localizedDescription))
        }
    }

    func loadLastProject() {
        do {
            guard let document = try projectRepository.loadLastProject() else {
                hasCompletedInitialLoad = true
                refreshProjectValidation()
                projectStatus = .idle(message: "No saved project found")
                return
            }

            isRestoringProject = true
            activeProject = document.project
            selectedPrinter = document.lastUsedPrinter
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

    private func handleProjectStateChange() {
        refreshProjectValidation()

        guard hasCompletedInitialLoad, isRestoringProject == false else {
            return
        }

        saveActiveProject()
    }

    private func refreshProjectValidation() {
        projectValidationIssues = projectValidator.validate(project: activeProject, printer: selectedPrinter)
    }
}

struct PencilState: Equatable {
    var squeezeEnabled: Bool
    var barrelRollAngle: CGFloat

    static let idle = PencilState(squeezeEnabled: false, barrelRollAngle: .zero)
}
