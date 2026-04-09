import Foundation

protocol ProjectRepository {
    func loadLastProject() throws -> SliceProjectDocument?
    func saveProject(_ document: SliceProjectDocument) throws
}

struct UserDefaultsProjectRepository: ProjectRepository {
    private let defaults: UserDefaults
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let storageKey = "SlicerWorks.lastProjectDocument"

    init(
        defaults: UserDefaults = .standard,
        encoder: JSONEncoder = JSONEncoder(),
        decoder: JSONDecoder = JSONDecoder()
    ) {
        self.defaults = defaults
        self.encoder = encoder
        self.decoder = decoder
        self.encoder.dateEncodingStrategy = .iso8601
        self.decoder.dateDecodingStrategy = .iso8601
    }

    func loadLastProject() throws -> SliceProjectDocument? {
        guard let data = defaults.data(forKey: storageKey) else {
            return nil
        }

        return try decoder.decode(SliceProjectDocument.self, from: data)
    }

    func saveProject(_ document: SliceProjectDocument) throws {
        let data = try encoder.encode(document)
        defaults.set(data, forKey: storageKey)
    }
}

struct InMemoryProjectRepository: ProjectRepository {
    private final class Storage {
        var document: SliceProjectDocument?
    }

    private let storage: Storage

    init(document: SliceProjectDocument? = nil, storage: Storage = Storage()) {
        storage.document = document
        self.storage = storage
    }

    func loadLastProject() throws -> SliceProjectDocument? {
        storage.document
    }

    func saveProject(_ document: SliceProjectDocument) throws {
        storage.document = document
    }
}
