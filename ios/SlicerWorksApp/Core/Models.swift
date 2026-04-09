import Foundation

struct SliceProject: Identifiable, Equatable, Codable {
    let id: UUID
    var name: String
    var modelURL: URL
    var materialAssignments: [MaterialAssignment]
    var layerHeightMM: Double
    var infillPercent: Int

    static let example = SliceProject(
        id: UUID(),
        name: "Bambu Benchy",
        modelURL: URL(fileURLWithPath: "/tmp/benchy.3mf"),
        materialAssignments: [],
        layerHeightMM: 0.2,
        infillPercent: 15
    )
}

struct MaterialAssignment: Equatable, Codable {
    var faceIdentifier: String
    var filament: Filament
}

struct Filament: Equatable, Codable {
    var brand: String
    var material: String
    var colorHex: String
}

struct SliceResult: Equatable, Codable {
    var gcodeURL: URL
    var estimatedPrintTimeMinutes: Int
    var estimatedFilamentGrams: Double
}

struct SliceProjectDocument: Equatable, Codable {
    var project: SliceProject
    var lastUsedPrinter: BambuPrinterProfile
    var updatedAt: Date

    static let example = SliceProjectDocument(
        project: .example,
        lastUsedPrinter: .x1Carbon,
        updatedAt: .now
    )
}

enum BambuPrinterProfile: String, CaseIterable, Identifiable, Codable {
    case a1
    case a1Mini
    case p1S
    case p1P
    case x1Carbon

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .a1: return "Bambu Lab A1"
        case .a1Mini: return "Bambu Lab A1 Mini"
        case .p1S: return "Bambu Lab P1S"
        case .p1P: return "Bambu Lab P1P"
        case .x1Carbon: return "Bambu Lab X1 Carbon"
        }
    }

    var buildVolumeMM: (x: Int, y: Int, z: Int) {
        switch self {
        case .a1: return (256, 256, 256)
        case .a1Mini: return (180, 180, 180)
        case .p1S, .p1P, .x1Carbon: return (256, 256, 256)
        }
    }
}
