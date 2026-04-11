import Foundation
import SwiftUI

struct SliceProject: Identifiable, Equatable, Codable {
    let id: UUID
    var name: String
    var plates: [BuildPlate]
    var materialAssignments: [MaterialAssignment]
    var sliceSettings: SliceSettings

    static let example = SliceProject(
        id: UUID(),
        name: "Axolotl Demo",
        plates: [
            BuildPlate(
                id: UUID(),
                name: "Plate 1",
                models: [
                    .axolotlDemo()
                ]
            )
        ],
        materialAssignments: [],
        sliceSettings: .recommended(for: .x1Carbon, quality: .balanced, material: .pla)
    )

    var allModels: [PlacedModel] {
        plates.flatMap(\.models)
    }
}

struct BuildPlate: Identifiable, Equatable, Codable {
    let id: UUID
    var name: String
    var models: [PlacedModel]
}

struct PlacedModel: Identifiable, Equatable, Codable {
    let id: UUID
    var name: String
    var sourceURL: URL
    var generatedShape: EditableSketchExtrusion?
    var position: PlatePosition
    var rotationDegrees: Double
    var scalePercent: Int
    var surfacePaintRegions: [SurfacePaintRegion]

    static func axolotlDemo(position: PlatePosition = PlatePosition(x: 0, y: 0)) -> PlacedModel {
        PlacedModel(
            id: UUID(),
            name: "Axolotl",
            sourceURL: DemoModelAssets.axolotlSTLURL,
            generatedShape: nil,
            position: position,
            rotationDegrees: 0,
            scalePercent: 100,
            surfacePaintRegions: []
        )
    }
}

struct EditableSketchExtrusion: Equatable, Codable {
    var operation: SketchExtrusionOperation
    var profile: SketchExtrusionProfile
    var widthMM: Double
    var depthMM: Double
    var heightMM: Double
}

enum SketchExtrusionOperation: String, Codable {
    case additive
    case negative
}

enum SketchExtrusionProfile: String, Codable {
    case rectangle
}

enum DemoModelAssets {
    static var axolotlSTLURL: URL {
        Bundle.main.url(forResource: "AxolotlDemo", withExtension: "stl")
            ?? URL(fileURLWithPath: "/Users/stephenchartrand/Documents/slicerworks/ios/SlicerWorksApp/Resources/AxolotlDemo.stl")
    }
}

struct PlatePosition: Equatable, Codable {
    var x: Double
    var y: Double
}

struct SurfacePaintRegion: Identifiable, Equatable, Codable {
    let id: UUID
    var tool: PaintingTool
    var color: PrintColorOption
    var points: [CGPoint]
    var forceSamples: [CGFloat]
    var rollAngle: CGFloat
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

struct SliceSettings: Equatable, Codable {
    var qualityPreset: SliceQualityPreset
    var filamentMaterial: FilamentMaterial
    var surfaceColor: PrintColorOption
    var infillColor: PrintColorOption
    var layerHeightMM: Double
    var firstLayerHeightMM: Double
    var wallLoopCount: Int
    var topLayers: Int
    var bottomLayers: Int
    var infillPercent: Int
    var infillPattern: InfillPattern
    var printSpeedMMPerSecond: Int
    var nozzleTemperatureC: Int
    var bedTemperatureC: Int
    var supportStyle: SupportStyle
    var adhesionType: AdhesionType
    var brimWidthMM: Int

    static func recommended(
        for printer: BambuPrinterProfile,
        quality: SliceQualityPreset,
        material: FilamentMaterial
    ) -> SliceSettings {
        printer.recommendedSettings(quality: quality, material: material)
    }
}

enum PrintColorOption: String, CaseIterable, Identifiable, Codable {
    case white
    case black
    case gray
    case red
    case orange
    case yellow
    case green
    case blue
    case teal
    case purple

    var id: String { rawValue }

    var displayName: String {
        rawValue.capitalized
    }

    var hex: String {
        switch self {
        case .white: return "#F3F2EE"
        case .black: return "#1E1E1E"
        case .gray: return "#80838C"
        case .red: return "#D94B45"
        case .orange: return "#E98839"
        case .yellow: return "#E8C84C"
        case .green: return "#57A66A"
        case .blue: return "#4688D9"
        case .teal: return "#4CB8B8"
        case .purple: return "#8B68D9"
        }
    }

    var swatch: Color {
        Color(hex: hex)
    }
}

enum SliceQualityPreset: String, CaseIterable, Identifiable, Codable {
    case draft
    case balanced
    case fine

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .draft: return "Draft"
        case .balanced: return "Balanced"
        case .fine: return "Fine"
        }
    }
}

enum FilamentMaterial: String, CaseIterable, Identifiable, Codable {
    case pla
    case petg
    case abs
    case tpu

    var id: String { rawValue }

    var displayName: String {
        rawValue.uppercased()
    }

    var recommendedNozzleTemperatureC: Int {
        switch self {
        case .pla: return 220
        case .petg: return 245
        case .abs: return 255
        case .tpu: return 225
        }
    }

    var recommendedBedTemperatureC: Int {
        switch self {
        case .pla: return 60
        case .petg: return 75
        case .abs: return 95
        case .tpu: return 45
        }
    }
}

enum InfillPattern: String, CaseIterable, Identifiable, Codable {
    case grid
    case gyroid
    case cubic
    case lines

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .grid: return "Grid"
        case .gyroid: return "Gyroid"
        case .cubic: return "Cubic"
        case .lines: return "Lines"
        }
    }
}

enum SupportStyle: String, CaseIterable, Identifiable, Codable {
    case off
    case buildPlateOnly
    case everywhere

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .off: return "Off"
        case .buildPlateOnly: return "Build Plate Only"
        case .everywhere: return "Everywhere"
        }
    }

    var isEnabled: Bool {
        self != .off
    }
}

enum AdhesionType: String, CaseIterable, Identifiable, Codable {
    case none
    case skirt
    case brim
    case raft

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .none: return "None"
        case .skirt: return "Skirt"
        case .brim: return "Brim"
        case .raft: return "Raft"
        }
    }
}

struct SliceResult: Equatable, Codable {
    var gcodeURL: URL
    var estimatedPrintTimeMinutes: Int
    var estimatedFilamentGrams: Double
    var estimatedFilamentMeters: Double
    var selectedQualityPreset: SliceQualityPreset
    var selectedMaterial: FilamentMaterial
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

struct BambuLANPrinter: Identifiable, Equatable, Codable {
    let id: UUID
    var name: String
    var host: String
    var serialNumber: String
    var profile: BambuPrinterProfile
    var accessCode: String?

    var hasAccessCode: Bool {
        guard let accessCode else { return false }
        return accessCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }
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

    var minimumLayerHeightMM: Double { 0.08 }
    var maximumLayerHeightMM: Double { 0.28 }
    var maximumPrintSpeedMMPerSecond: Int {
        switch self {
        case .a1Mini: return 280
        case .a1: return 320
        case .p1P, .p1S, .x1Carbon: return 350
        }
    }

    func recommendedSettings(
        quality: SliceQualityPreset,
        material: FilamentMaterial
    ) -> SliceSettings {
        let qualitySettings: (layerHeight: Double, speed: Int, walls: Int, topBottom: Int, infill: Int) = switch quality {
        case .draft:
            (0.24, 240, 2, 4, 10)
        case .balanced:
            (0.20, 180, 3, 5, 15)
        case .fine:
            (0.12, 120, 3, 6, 18)
        }

        let adhesion: AdhesionType = material == .abs ? .brim : .skirt
        let supportStyle: SupportStyle = quality == .fine ? .buildPlateOnly : .off

        return SliceSettings(
            qualityPreset: quality,
            filamentMaterial: material,
            surfaceColor: .orange,
            infillColor: .gray,
            layerHeightMM: max(minimumLayerHeightMM, qualitySettings.layerHeight),
            firstLayerHeightMM: 0.24,
            wallLoopCount: qualitySettings.walls,
            topLayers: qualitySettings.topBottom,
            bottomLayers: qualitySettings.topBottom,
            infillPercent: qualitySettings.infill,
            infillPattern: quality == .fine ? .gyroid : .grid,
            printSpeedMMPerSecond: min(qualitySettings.speed, maximumPrintSpeedMMPerSecond),
            nozzleTemperatureC: material.recommendedNozzleTemperatureC,
            bedTemperatureC: material.recommendedBedTemperatureC,
            supportStyle: supportStyle,
            adhesionType: adhesion,
            brimWidthMM: adhesion == .brim ? 6 : 0
        )
    }
}

private extension Color {
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)

        let red = Double((value >> 16) & 0xFF) / 255
        let green = Double((value >> 8) & 0xFF) / 255
        let blue = Double(value & 0xFF) / 255

        self.init(red: red, green: green, blue: blue)
    }
}
