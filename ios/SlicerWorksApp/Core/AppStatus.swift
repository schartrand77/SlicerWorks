import Foundation

enum AppStatus: Equatable {
    case idle(message: String)
    case working(message: String)
    case success(message: String)
    case failure(AppError)

    var message: String {
        switch self {
        case let .idle(message), let .working(message), let .success(message):
            return message
        case let .failure(error):
            return error.errorDescription ?? "Something went wrong"
        }
    }

    var isWorking: Bool {
        if case .working = self {
            return true
        }

        return false
    }
}

enum AppError: LocalizedError, Equatable {
    case sliceFailed(reason: String)
    case uploadFailed(reason: String)
    case missingSliceResult
    case missingPrinterSelection
    case missingPrinterAccessCode
    case projectLoadFailed(reason: String)
    case projectSaveFailed(reason: String)
    case projectImportFailed(reason: String)
    case printerDiscoveryFailed(reason: String)
    case printerSaveFailed(reason: String)

    var errorDescription: String? {
        switch self {
        case let .sliceFailed(reason):
            return "Slice failed: \(reason)"
        case let .uploadFailed(reason):
            return "Upload failed: \(reason)"
        case .missingSliceResult:
            return "Slice the project before uploading"
        case .missingPrinterSelection:
            return "Add and select a Bambu printer on LAN before uploading"
        case .missingPrinterAccessCode:
            return "Enter the printer access code before using Bambu LAN mode"
        case let .projectLoadFailed(reason):
            return "Project load failed: \(reason)"
        case let .projectSaveFailed(reason):
            return "Project save failed: \(reason)"
        case let .projectImportFailed(reason):
            return "Project import failed: \(reason)"
        case let .printerDiscoveryFailed(reason):
            return "Printer discovery failed: \(reason)"
        case let .printerSaveFailed(reason):
            return "Printer save failed: \(reason)"
        }
    }
}
