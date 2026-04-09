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

        if project.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(ProjectValidationIssue(
                id: "project-name",
                message: "Project name is required."
            ))
        }

        let pathExtension = project.modelURL.pathExtension.lowercased()
        if supportedModelExtensions.contains(pathExtension) == false {
            issues.append(ProjectValidationIssue(
                id: "model-format",
                message: "Model format must be .stl, .obj, or .3mf."
            ))
        }

        if project.layerHeightMM < 0.08 || project.layerHeightMM > 0.32 {
            issues.append(ProjectValidationIssue(
                id: "layer-height",
                message: "Layer height must stay between 0.08 mm and 0.32 mm."
            ))
        }

        if project.infillPercent < 0 || project.infillPercent > 100 {
            issues.append(ProjectValidationIssue(
                id: "infill",
                message: "Infill must stay between 0% and 100%."
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

        if printer.buildVolumeMM.z < 180 && pathExtension == "3mf" {
            issues.append(ProjectValidationIssue(
                id: "printer-profile-review",
                message: "Review imported project scale and plate fit for the selected printer."
            ))
        }

        return issues
    }
}
