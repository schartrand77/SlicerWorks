import Foundation

struct AppEnvironment {
    let slicerEngine: SlicerEngine
    let deviceGateway: BambuDeviceGateway
    let projectRepository: ProjectRepository
    let projectValidator: ProjectValidating
    let projectImporter: ProjectImporting

    init(
        slicerEngine: SlicerEngine,
        deviceGateway: BambuDeviceGateway,
        projectRepository: ProjectRepository,
        projectValidator: ProjectValidating,
        projectImporter: ProjectImporting = FileSystemProjectImporter()
    ) {
        self.slicerEngine = slicerEngine
        self.deviceGateway = deviceGateway
        self.projectRepository = projectRepository
        self.projectValidator = projectValidator
        self.projectImporter = projectImporter
    }

    static let live = AppEnvironment(
        slicerEngine: MockSlicerEngine(),
        deviceGateway: MockBambuDeviceGateway(),
        projectRepository: UserDefaultsProjectRepository(),
        projectValidator: DefaultProjectValidator(),
        projectImporter: FileSystemProjectImporter()
    )
}
