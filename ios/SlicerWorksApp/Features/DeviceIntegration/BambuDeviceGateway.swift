@preconcurrency import Foundation
import Network

extension NetService: @retroactive @unchecked Sendable {}

protocol BambuDeviceGateway {
    func discoverPrinters() async throws -> [BambuLANPrinter]
    func upload(result: SliceResult, to printer: BambuLANPrinter) async throws
}

struct BonjourBambuDeviceGateway: BambuDeviceGateway {
    func discoverPrinters() async throws -> [BambuLANPrinter] {
        let bonjourPrinters = try await BonjourBambuLANScanner().discoverPrinters()
        let probedPrinters = await TCPBambuLANScanner().discoverPrinters()
        let allPrinters = bonjourPrinters + probedPrinters
        var printersByHost: [String: BambuLANPrinter] = [:]

        for printer in allPrinters {
            let key = printer.host.lowercased()
            let existingPrinter = printersByHost[key]
            printersByHost[key] = existingPrinter?.name.hasPrefix("Bambu printer") == false
                ? existingPrinter
                : printer
        }

        return printersByHost.values.sorted { $0.name < $1.name }
    }

    func upload(result: SliceResult, to printer: BambuLANPrinter) async throws {
        print("Upload of \(result.gcodeURL.lastPathComponent) to \(printer.name) at \(printer.host) is not implemented yet")
    }
}

private struct TCPBambuLANScanner {
    private let probePorts: [UInt16] = [8883, 990]
    private let probeTimeoutNanoseconds: UInt64 = 500_000_000

    func discoverPrinters() async -> [BambuLANPrinter] {
        let hosts = candidateHosts()

        return await withTaskGroup(of: BambuLANPrinter?.self) { group in
            for host in hosts {
                group.addTask {
                    guard await hasOpenBambuPort(host: host) else {
                        return nil
                    }

                    return BambuLANPrinter(
                        id: StablePrinterID.make(seed: "bambu-\(host)"),
                        name: "Bambu printer \(host)",
                        host: host,
                        serialNumber: "bambu-\(host)",
                        profile: .x1Carbon
                    )
                }
            }

            var printers: [BambuLANPrinter] = []
            for await printer in group {
                if let printer {
                    printers.append(printer)
                }
            }

            return printers.sorted { $0.host.localizedStandardCompare($1.host) == .orderedAscending }
        }
    }

    private func hasOpenBambuPort(host: String) async -> Bool {
        for port in probePorts {
            if await probe(host: host, port: port) {
                return true
            }
        }

        return false
    }

    private func probe(host: String, port: UInt16) async -> Bool {
        await withCheckedContinuation { continuation in
            let connection = NWConnection(
                host: NWEndpoint.Host(host),
                port: NWEndpoint.Port(rawValue: port) ?? 8883,
                using: .tcp
            )
            let completion = ProbeCompletion()

            @Sendable func finish(_ isOpen: Bool) {
                guard completion.markCompleted() else {
                    return
                }

                connection.cancel()
                continuation.resume(returning: isOpen)
            }

            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    finish(true)
                case .failed, .cancelled, .waiting:
                    finish(false)
                default:
                    break
                }
            }

            connection.start(queue: .global(qos: .utility))

            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + .nanoseconds(Int(probeTimeoutNanoseconds))) {
                finish(false)
            }
        }
    }

    private func candidateHosts() -> [String] {
        let localPrefixes = Set(localIPv4Addresses().compactMap(ipv4Prefix))
        var prefixes = localPrefixes
        prefixes.insert("192.168.1")

        return prefixes
            .sorted()
            .flatMap { prefix in
                (1...254).map { "\(prefix).\($0)" }
            }
    }

    private func localIPv4Addresses() -> [String] {
        var addresses: [String] = []
        var interfaces: UnsafeMutablePointer<ifaddrs>?

        guard getifaddrs(&interfaces) == 0, let firstInterface = interfaces else {
            return addresses
        }

        defer { freeifaddrs(interfaces) }

        for interface in sequence(first: firstInterface, next: { $0.pointee.ifa_next }) {
            let flags = Int32(interface.pointee.ifa_flags)
            let address = interface.pointee.ifa_addr.pointee

            guard address.sa_family == UInt8(AF_INET),
                  (flags & IFF_UP) != 0,
                  (flags & IFF_LOOPBACK) == 0 else {
                continue
            }

            var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            getnameinfo(
                interface.pointee.ifa_addr,
                socklen_t(address.sa_len),
                &hostname,
                socklen_t(hostname.count),
                nil,
                0,
                NI_NUMERICHOST
            )

            addresses.append(String(cString: hostname))
        }

        return addresses
    }

    private func ipv4Prefix(_ address: String) -> String? {
        let parts = address.split(separator: ".")
        guard parts.count == 4 else {
            return nil
        }

        return parts.prefix(3).joined(separator: ".")
    }
}

private final class ProbeCompletion: @unchecked Sendable {
    nonisolated private let lock = NSLock()
    nonisolated(unsafe) private var isCompleted = false

    nonisolated func markCompleted() -> Bool {
        lock.lock()
        defer { lock.unlock() }

        guard isCompleted == false else {
            return false
        }

        isCompleted = true
        return true
    }
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

@MainActor
private final class BonjourBambuLANScanner: NSObject, NetServiceBrowserDelegate, NetServiceDelegate {
    private let browser = NetServiceBrowser()
    private var servicesByName: [String: NetService] = [:]
    private var printersByID: [BambuLANPrinter.ID: BambuLANPrinter] = [:]
    private var continuation: CheckedContinuation<[BambuLANPrinter], Never>?
    private var timeoutTask: Task<Void, Never>?

    func discoverPrinters(timeoutNanoseconds: UInt64 = 4_000_000_000) async throws -> [BambuLANPrinter] {
        await withCheckedContinuation { continuation in
            self.continuation = continuation
            browser.delegate = self
            browser.searchForServices(ofType: "_bambu._tcp.", inDomain: "local.")

            timeoutTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: timeoutNanoseconds)
                self?.finish()
            }
        }
    }

    nonisolated func netServiceBrowser(
        _ browser: NetServiceBrowser,
        didFind service: NetService,
        moreComing: Bool
    ) {
        Task { @MainActor in
            servicesByName[service.name] = service
            service.delegate = self
            service.resolve(withTimeout: 2)
        }
    }

    nonisolated func netServiceBrowser(_ browser: NetServiceBrowser, didNotSearch errorDict: [String: NSNumber]) {
        Task { @MainActor in
            finish()
        }
    }

    nonisolated func netServiceDidResolveAddress(_ sender: NetService) {
        Task { @MainActor in
            let printer = BambuLANPrinter(
                id: stableID(for: sender),
                name: displayName(for: sender),
                host: host(for: sender),
                serialNumber: serialNumber(for: sender),
                profile: profile(for: sender)
            )
            printersByID[printer.id] = printer
        }
    }

    nonisolated func netService(_ sender: NetService, didNotResolve errorDict: [String: NSNumber]) {
        Task { @MainActor in
            let printer = BambuLANPrinter(
                id: stableID(for: sender),
                name: displayName(for: sender),
                host: sender.hostName ?? sender.name,
                serialNumber: serialNumber(for: sender),
                profile: profile(for: sender)
            )
            printersByID[printer.id] = printer
        }
    }

    private func finish() {
        browser.stop()
        servicesByName.values.forEach { $0.stop() }
        timeoutTask?.cancel()
        timeoutTask = nil
        let printers = printersByID.values.sorted { $0.name < $1.name }
        continuation?.resume(returning: printers)
        continuation = nil
    }

    private func stableID(for service: NetService) -> UUID {
        StablePrinterID.make(seed: serialNumber(for: service))
    }

    private func displayName(for service: NetService) -> String {
        txtValue("name", for: service) ?? service.name
    }

    private func host(for service: NetService) -> String {
        txtValue("ip_addr", for: service) ?? service.hostName ?? service.name
    }

    private func serialNumber(for service: NetService) -> String {
        txtValue("dev_id", for: service) ?? txtValue("serial", for: service) ?? service.name
    }

    private func profile(for service: NetService) -> BambuPrinterProfile {
        let descriptor = [
            txtValue("type", for: service),
            txtValue("model", for: service),
            txtValue("name", for: service),
            service.name
        ]
        .compactMap { $0 }
        .joined(separator: " ")
        .lowercased()

        if descriptor.contains("a1 mini") || descriptor.contains("a1m") {
            return .a1Mini
        }

        if descriptor.contains("a1") {
            return .a1
        }

        if descriptor.contains("p1s") {
            return .p1S
        }

        if descriptor.contains("p1p") {
            return .p1P
        }

        return .x1Carbon
    }

    private func txtValue(_ key: String, for service: NetService) -> String? {
        guard let txtRecordData = service.txtRecordData() else {
            return nil
        }

        let record = NetService.dictionary(fromTXTRecord: txtRecordData)
        let normalizedKey = record.keys.first { $0.lowercased() == key.lowercased() }

        guard let normalizedKey,
              let value = record[normalizedKey] else {
            return nil
        }

        return String(data: value, encoding: .utf8)
    }
}

private enum StablePrinterID {
    nonisolated static func make(seed: String) -> UUID {
        var bytes = [UInt8](repeating: 0, count: 16)

        for (index, byte) in seed.utf8.enumerated() {
            bytes[index % 16] = bytes[index % 16] &* 31 &+ byte &+ UInt8(truncatingIfNeeded: index)
        }

        bytes[6] = (bytes[6] & 0x0F) | 0x50
        bytes[8] = (bytes[8] & 0x3F) | 0x80

        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }
}
