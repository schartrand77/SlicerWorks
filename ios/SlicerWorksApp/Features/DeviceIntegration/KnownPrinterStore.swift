import Foundation

protocol KnownPrinterStoring {
    func loadPrinters() throws -> [BambuLANPrinter]
    func savePrinters(_ printers: [BambuLANPrinter]) throws
}

struct UserDefaultsKnownPrinterStore: KnownPrinterStoring {
    private let defaults: UserDefaults
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let storageKey = "SlicerWorks.knownLANPrinters"

    init(
        defaults: UserDefaults = .standard,
        encoder: JSONEncoder = JSONEncoder(),
        decoder: JSONDecoder = JSONDecoder()
    ) {
        self.defaults = defaults
        self.encoder = encoder
        self.decoder = decoder
    }

    func loadPrinters() throws -> [BambuLANPrinter] {
        guard let data = defaults.data(forKey: storageKey) else {
            return []
        }

        return try decoder.decode([BambuLANPrinter].self, from: data)
    }

    func savePrinters(_ printers: [BambuLANPrinter]) throws {
        let data = try encoder.encode(printers)
        defaults.set(data, forKey: storageKey)
    }
}

struct InMemoryKnownPrinterStore: KnownPrinterStoring {
    final class Storage {
        var printers: [BambuLANPrinter] = []
    }

    private let storage: Storage

    init(printers: [BambuLANPrinter] = [], storage: Storage = Storage()) {
        storage.printers = printers
        self.storage = storage
    }

    func loadPrinters() throws -> [BambuLANPrinter] {
        storage.printers
    }

    func savePrinters(_ printers: [BambuLANPrinter]) throws {
        storage.printers = printers
    }
}
