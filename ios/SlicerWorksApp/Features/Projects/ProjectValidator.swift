import Foundation

protocol ProjectValidating {
    func validate(project: SliceProject, printer: BambuPrinterProfile) -> [ProjectValidationIssue]
}

struct ProjectValidationIssue: Equatable, Identifiable {
    let id: String
    let message: String

    init(id: String, message: String) {
        self.id = id
        self.message = message
    }
}

struct DefaultProjectValidator: ProjectValidating {
    private let supportedModelExtensions = ["3mf", "obj", "stl"]

    func validate(project: SliceProject, printer: BambuPrinterProfile) -> [ProjectValidationIssue] {
        var issues: [ProjectValidationIssue] = []
        let settings = project.sliceSettings

        if project.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(ProjectValidationIssue(
                id: "project-name",
                message: "Project name is required."
            ))
        }

        if project.plates.isEmpty {
            issues.append(ProjectValidationIssue(
                id: "plates",
                message: "Add at least one build plate before slicing."
            ))
        }

        let models = project.allModels
        if models.isEmpty {
            issues.append(ProjectValidationIssue(
                id: "model-format",
                message: "Add at least one model to a build plate before slicing."
            ))
        }

        let unsupportedModels = models.filter { model in
            if model.generatedShape != nil {
                return false
            }

            return supportedModelExtensions.contains(model.sourceURL.pathExtension.lowercased()) == false
        }
        if unsupportedModels.isEmpty == false {
            issues.append(ProjectValidationIssue(
                id: "model-format",
                message: "Model format must be .stl, .obj, or .3mf."
            ))
        }

        if settings.layerHeightMM < printer.minimumLayerHeightMM || settings.layerHeightMM > printer.maximumLayerHeightMM {
            issues.append(ProjectValidationIssue(
                id: "layer-height",
                message: "Layer height must stay between \(printer.minimumLayerHeightMM.formatted()) mm and \(printer.maximumLayerHeightMM.formatted()) mm for this printer."
            ))
        }

        if settings.firstLayerHeightMM < settings.layerHeightMM || settings.firstLayerHeightMM > 0.32 {
            issues.append(ProjectValidationIssue(
                id: "first-layer-height",
                message: "First layer height must be at least the layer height and no more than 0.32 mm."
            ))
        }

        if settings.infillPercent < 0 || settings.infillPercent > 100 {
            issues.append(ProjectValidationIssue(
                id: "infill",
                message: "Infill must stay between 0% and 100%."
            ))
        }

        if settings.wallLoopCount < 1 || settings.wallLoopCount > 8 {
            issues.append(ProjectValidationIssue(
                id: "wall-count",
                message: "Wall loops must stay between 1 and 8."
            ))
        }

        if settings.topLayers < 1 || settings.topLayers > 10 || settings.bottomLayers < 1 || settings.bottomLayers > 10 {
            issues.append(ProjectValidationIssue(
                id: "surface-layers",
                message: "Top and bottom layers must stay between 1 and 10."
            ))
        }

        if settings.printSpeedMMPerSecond < 30 || settings.printSpeedMMPerSecond > printer.maximumPrintSpeedMMPerSecond {
            issues.append(ProjectValidationIssue(
                id: "print-speed",
                message: "Print speed must stay between 30 and \(printer.maximumPrintSpeedMMPerSecond) mm/s for this printer."
            ))
        }

        if settings.nozzleTemperatureC < 180 || settings.nozzleTemperatureC > 300 {
            issues.append(ProjectValidationIssue(
                id: "nozzle-temperature",
                message: "Nozzle temperature must stay between 180 C and 300 C."
            ))
        }

        if settings.bedTemperatureC < 0 || settings.bedTemperatureC > 110 {
            issues.append(ProjectValidationIssue(
                id: "bed-temperature",
                message: "Bed temperature must stay between 0 C and 110 C."
            ))
        }

        if settings.supportStyle == .off && settings.adhesionType == .raft {
            issues.append(ProjectValidationIssue(
                id: "adhesion-support-balance",
                message: "Rafts are usually only worth using when you also need extra support or difficult-bed adhesion."
            ))
        }

        if settings.adhesionType == .none && settings.brimWidthMM > 0 {
            issues.append(ProjectValidationIssue(
                id: "brim-width",
                message: "Brim width must be 0 mm unless brim adhesion is selected."
            ))
        }

        if settings.adhesionType == .brim && settings.brimWidthMM < 3 {
            issues.append(ProjectValidationIssue(
                id: "brim-width",
                message: "Use at least a 3 mm brim when brim adhesion is enabled."
            ))
        }

        let duplicateFaceAssignments = Set(
            project.materialAssignments
                .map(\.faceIdentifier)
                .filter { faceIdentifier in
                    project.materialAssignments.filter { $0.faceIdentifier == faceIdentifier }.count > 1
                }
        )
        if duplicateFaceAssignments.isEmpty == false {
            issues.append(ProjectValidationIssue(
                id: "material-assignments",
                message: "Each face can have only one material assignment."
            ))
        }

        if printer.buildVolumeMM.z < 180 && models.contains(where: { $0.sourceURL.pathExtension.lowercased() == "3mf" }) {
            issues.append(ProjectValidationIssue(
                id: "printer-profile-review",
                message: "Review imported project scale and plate fit for the selected printer."
            ))
        }

        return issues
    }
}
