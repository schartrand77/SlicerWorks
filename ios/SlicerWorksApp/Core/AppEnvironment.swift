import Foundation

struct AppEnvironment {
    let slicerEngine: SlicerEngine
    let deviceGateway: BambuDeviceGateway
    let projectRepository: ProjectRepository
    let projectValidator: ProjectValidating

    static let live = AppEnvironment(
        slicerEngine: MockSlicerEngine(),
        deviceGateway: MockBambuDeviceGateway(),
        projectRepository: UserDefaultsProjectRepository(),
        projectValidator: DefaultProjectValidator()
    )
}
