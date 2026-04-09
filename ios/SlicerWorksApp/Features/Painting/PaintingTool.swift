import Foundation
import SwiftUI

enum PaintingTool: String, CaseIterable, Identifiable, Codable {
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

    var systemImage: String {
        switch self {
        case .paintBrush: return "paintbrush.pointed"
        case .smartFill: return "sparkles"
        case .seamMask: return "scribble.variable"
        case .supportBlocker: return "shield.lefthalf.filled"
        }
    }

    var tint: Color {
        switch self {
        case .paintBrush: return .orange
        case .smartFill: return .blue
        case .seamMask: return .mint
        case .supportBlocker: return .pink
        }
    }

    var next: PaintingTool {
        let all = Self.allCases
        guard let index = all.firstIndex(of: self) else { return self }
        return all[(index + 1) % all.count]
    }
}
