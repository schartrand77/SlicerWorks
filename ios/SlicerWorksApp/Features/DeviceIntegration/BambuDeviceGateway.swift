import Foundation

protocol BambuDeviceGateway {
    func discoverPrinters() async throws -> [BambuLANPrinter]
    func upload(result: SliceResult, to printer: BambuLANPrinter) async throws
}

struct MockBambuDeviceGateway: BambuDeviceGateway {
    func discoverPrinters() async throws -> [BambuLANPrinter] {
        [
            BambuLANPrinter(
                id: UUID(uuidString: "A4A8E7B4-2E57-41E1-8A4A-52A79D20B001") ?? UUID(),
                name: "Studio P1S",
                host: "192.168.1.42",
                serialNumber: "P1S-LAB-042",
                profile: .p1S
            ),
            BambuLANPrinter(
                id: UUID(uuidString: "A4A8E7B4-2E57-41E1-8A4A-52A79D20B002") ?? UUID(),
                name: "Workbench A1 Mini",
                host: "192.168.1.57",
                serialNumber: "A1M-LAB-057",
                profile: .a1Mini
            )
        ]
    }

    func upload(result: SliceResult, to printer: BambuLANPrinter) async throws {
        print("Mock upload of \(result.gcodeURL.lastPathComponent) to \(printer.name) at \(printer.host)")
    }
}
