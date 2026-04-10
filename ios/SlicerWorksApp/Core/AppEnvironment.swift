import Foundation

struct AppEnvironment {
    let slicerEngine: SlicerEngine
    let deviceGateway: BambuDeviceGateway
    let knownPrinterStore: KnownPrinterStoring
    let projectRepository: ProjectRepository
    let projectValidator: ProjectValidating
    let projectImporter: ProjectImporting

    init(
        slicerEngine: SlicerEngine,
        deviceGateway: BambuDeviceGateway,
        knownPrinterStore: KnownPrinterStoring = UserDefaultsKnownPrinterStore(),
        projectRepository: ProjectRepository,
        projectValidator: ProjectValidating,
        projectImporter: ProjectImporting = FileSystemProjectImporter()
    ) {
        self.slicerEngine = slicerEngine
        self.deviceGateway = deviceGateway
        self.knownPrinterStore = knownPrinterStore
        self.projectRepository = projectRepository
        self.projectValidator = projectValidator
        self.projectImporter = projectImporter
    }

    static let live = AppEnvironment(
        slicerEngine: MockSlicerEngine(),
        deviceGateway: MockBambuDeviceGateway(),
        knownPrinterStore: UserDefaultsKnownPrinterStore(),
        projectRepository: UserDefaultsProjectRepository(),
        projectValidator: DefaultProjectValidator(),
        projectImporter: FileSystemProjectImporter()
    )
}
