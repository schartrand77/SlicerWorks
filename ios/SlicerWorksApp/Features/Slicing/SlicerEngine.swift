import Foundation

protocol SlicerEngine {
    func slice(project: SliceProject, profile: BambuPrinterProfile) async throws -> SliceResult
}

struct MockSlicerEngine: SlicerEngine {
    func slice(project: SliceProject, profile: BambuPrinterProfile) async throws -> SliceResult {
        let settings = project.sliceSettings
        let modelCount = max(project.allModels.count, 1)
        let baseMinutes = 72.0 + Double(modelCount * 18)
        let qualityFactor = 0.2 / settings.layerHeightMM
        let infillFactor = 1.0 + (Double(settings.infillPercent) / 100.0) * 0.55
        let wallFactor = 1.0 + Double(max(settings.wallLoopCount - 2, 0)) * 0.12
        let surfaceFactor = 1.0 + Double(settings.topLayers + settings.bottomLayers - 8) * 0.03
        let supportFactor = settings.supportStyle.isEnabled ? 1.18 : 1.0
        let adhesionFactor = switch settings.adhesionType {
        case .none: 1.0
        case .skirt: 1.03
        case .brim: 1.08
        case .raft: 1.2
        }
        let printerSpeedCompensation = Double(profile.maximumPrintSpeedMMPerSecond) / 280.0

        let estimatedMinutes = max(
            24,
            Int((baseMinutes * qualityFactor * infillFactor * wallFactor * surfaceFactor * supportFactor * adhesionFactor) / printerSpeedCompensation)
        )

        let baseFilament = 11.0 + Double(modelCount * 4)
        let materialFactor = switch settings.filamentMaterial {
        case .pla: 1.0
        case .petg: 1.04
        case .abs: 0.97
        case .tpu: 1.08
        }
        let infillMaterialFactor = 1.0 + Double(settings.infillPercent) / 80.0
        let shellMaterialFactor = 1.0 + Double(settings.wallLoopCount + settings.topLayers + settings.bottomLayers) / 30.0
        let supportMaterialFactor = settings.supportStyle.isEnabled ? 1.14 : 1.0
        let adhesionMaterialFactor = settings.adhesionType == .brim ? 1.05 : (settings.adhesionType == .raft ? 1.15 : 1.0)

        let grams = baseFilament * materialFactor * infillMaterialFactor * shellMaterialFactor * supportMaterialFactor * adhesionMaterialFactor
        let meters = grams / filamentDensityCompensation(for: settings.filamentMaterial)

        let outputName = project.name
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "_")
        let path = "/tmp/\(outputName.isEmpty ? "slice" : outputName).gcode"

        return SliceResult(
            gcodeURL: URL(fileURLWithPath: path),
            estimatedPrintTimeMinutes: estimatedMinutes,
            estimatedFilamentGrams: (grams * 10).rounded() / 10,
            estimatedFilamentMeters: (meters * 100).rounded() / 100,
            selectedQualityPreset: settings.qualityPreset,
            selectedMaterial: settings.filamentMaterial
        )
    }

    private func filamentDensityCompensation(for material: FilamentMaterial) -> Double {
        switch material {
        case .pla: return 3.0
        case .petg: return 3.15
        case .abs: return 2.85
        case .tpu: return 3.25
        }
    }
}
