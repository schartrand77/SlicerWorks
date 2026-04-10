import Foundation

protocol ProjectImporting {
    func importModels(from urls: [URL], into project: SliceProject) throws -> SliceProject
}

struct ImportedModelDescriptor: Equatable {
    let sourceURL: URL
    let storedURL: URL
    let displayName: String
}

struct ProjectImportError: LocalizedError, Equatable {
    let message: String

    var errorDescription: String? { message }
}

struct FileSystemProjectImporter: ProjectImporting {
    private let fileManager: FileManager
    private let baseDirectoryURL: URL
    private let supportedExtensions = Set(["3mf", "stl", "obj"])

    init(
        fileManager: FileManager = .default,
        baseDirectoryURL: URL? = nil
    ) {
        self.fileManager = fileManager
        self.baseDirectoryURL = baseDirectoryURL
            ?? fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
                .appendingPathComponent("SlicerWorks", isDirectory: true)
                .appendingPathComponent("ImportedModels", isDirectory: true)
    }

    func importModels(from urls: [URL], into project: SliceProject) throws -> SliceProject {
        guard urls.isEmpty == false else {
            throw ProjectImportError(message: "Choose at least one .3mf, .stl, or .obj file.")
        }

        var importedProject = project
        if importedProject.plates.isEmpty {
            importedProject.plates = [BuildPlate(id: UUID(), name: "Plate 1", models: [])]
        }

        try fileManager.createDirectory(at: baseDirectoryURL, withIntermediateDirectories: true)

        let descriptors = try urls.map(importDescriptor(for:))
        let firstPlateIndex = importedProject.plates.startIndex
        let existingModelCount = importedProject.plates[firstPlateIndex].models.count

        for (index, descriptor) in descriptors.enumerated() {
            let offsetIndex = existingModelCount + index
            importedProject.plates[firstPlateIndex].models.append(
                PlacedModel(
                    id: UUID(),
                    name: descriptor.displayName,
                    sourceURL: descriptor.storedURL,
                    position: PlatePosition(
                        x: Double(offsetIndex * 30),
                        y: Double(offsetIndex * 20)
                    ),
                    rotationDegrees: 0,
                    scalePercent: 100,
                    surfacePaintRegions: []
                )
            )
        }

        if project.name == SliceProject.example.name || project.allModels == SliceProject.example.allModels {
            importedProject.name = descriptors.count == 1
                ? descriptors[0].displayName
                : "Imported Models"
        }

        return importedProject
    }

    private func importDescriptor(for url: URL) throws -> ImportedModelDescriptor {
        let fileExtension = url.pathExtension.lowercased()
        guard supportedExtensions.contains(fileExtension) else {
            throw ProjectImportError(message: "Unsupported model format: .\(fileExtension)")
        }

        let accessStarted = url.startAccessingSecurityScopedResource()
        defer {
            if accessStarted {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let filenameStem = url.deletingPathExtension().lastPathComponent
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let displayName = filenameStem.isEmpty ? "Imported Model" : filenameStem
        let storedFilename = "\(UUID().uuidString).\(fileExtension)"
        let storedURL = baseDirectoryURL.appendingPathComponent(storedFilename, isDirectory: false)

        if fileManager.fileExists(atPath: storedURL.path) {
            try fileManager.removeItem(at: storedURL)
        }

        do {
            try fileManager.copyItem(at: url, to: storedURL)
        } catch {
            throw ProjectImportError(message: "Could not import \(url.lastPathComponent). \(error.localizedDescription)")
        }

        return ImportedModelDescriptor(
            sourceURL: url,
            storedURL: storedURL,
            displayName: displayName
        )
    }
}
