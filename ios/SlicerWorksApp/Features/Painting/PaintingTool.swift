import Foundation

enum PaintingTool: String, CaseIterable, Identifiable {
    case paintBrush
    case smartFill
    case seamMask
    case supportBlocker

    var id: String { rawValue }

    var title: String {
        switch self {
        case .paintBrush: return "Paint Brush"
        case .smartFill: return "Smart Fill"
        case .seamMask: return "Seam Mask"
        case .supportBlocker: return "Support Blocker"
        }
    }
}
