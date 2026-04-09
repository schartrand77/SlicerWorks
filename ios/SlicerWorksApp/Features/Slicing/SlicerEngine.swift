import Foundation

protocol SlicerEngine {
    func slice(project: SliceProject, profile: BambuPrinterProfile) async throws -> SliceResult
}

struct MockSlicerEngine: SlicerEngine {
    func slice(project: SliceProject, profile: BambuPrinterProfile) async throws -> SliceResult {
        let path = "/tmp/\(project.name.replacingOccurrences(of: " ", with: "_")).gcode"
        return SliceResult(
            gcodeURL: URL(fileURLWithPath: path),
            estimatedPrintTimeMinutes: 143,
            estimatedFilamentGrams: 28.4
        )
    }
}
