import Foundation

protocol BambuDeviceGateway {
    func upload(result: SliceResult, to printer: BambuPrinterProfile) async throws
}

struct MockBambuDeviceGateway: BambuDeviceGateway {
    func upload(result: SliceResult, to printer: BambuPrinterProfile) async throws {
        print("Mock upload of \(result.gcodeURL.lastPathComponent) to \(printer.displayName)")
    }
}
