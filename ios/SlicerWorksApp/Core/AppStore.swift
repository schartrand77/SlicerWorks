import Foundation
import PencilKit

@MainActor
final class AppStore: ObservableObject {
    @Published var selectedPrinter: BambuPrinterProfile = .x1Carbon
    @Published var activeProject: SliceProject = .example
    @Published var selectedTool: PaintingTool = .paintBrush
    @Published var pencilState: PencilState = .idle

    let slicerEngine: SlicerEngine
    let deviceGateway: BambuDeviceGateway

    init(
        slicerEngine: SlicerEngine = MockSlicerEngine(),
        deviceGateway: BambuDeviceGateway = MockBambuDeviceGateway()
    ) {
        self.slicerEngine = slicerEngine
        self.deviceGateway = deviceGateway
    }

    func prepareSlice() async throws -> SliceResult {
        try await slicerEngine.slice(project: activeProject, profile: selectedPrinter)
    }

    func pushToPrinter(_ result: SliceResult) async throws {
        try await deviceGateway.upload(result: result, to: selectedPrinter)
    }
}

struct PencilState: Equatable {
    var squeezeEnabled: Bool
    var barrelRollAngle: CGFloat

    static let idle = PencilState(squeezeEnabled: false, barrelRollAngle: .zero)
}
