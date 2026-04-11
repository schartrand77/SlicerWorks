import SwiftUI

struct RootTabView: View {
    @EnvironmentObject private var store: AppStore
    @State private var hasEnteredWorkspace = false
    @State private var selectedSection: WorkspaceSection = .slice

    var body: some View {
        Group {
            if hasEnteredWorkspace {
                NavigationStack {
                    switch selectedSection {
                    case .slice:
                        SlicerDashboardView(selectedSection: $selectedSection)
                    case .paint:
                        ModelPaintingView(selectedSection: $selectedSection)
                    case .devices:
                        PrinterControlView(selectedSection: $selectedSection)
                    }
                }
            } else {
                PrinterSetupLandingView {
                    hasEnteredWorkspace = true
                }
            }
        }
    }
}

enum WorkspaceSection: String, CaseIterable, Identifiable {
    case slice
    case paint
    case devices

    var id: String { rawValue }

    var title: String {
        switch self {
        case .slice:
            return "Slice"
        case .paint:
            return "Paint"
        case .devices:
            return "Devices"
        }
    }

    var systemImage: String {
        switch self {
        case .slice:
            return "cube"
        case .paint:
            return "paintbrush.pointed"
        case .devices:
            return "wifi"
        }
    }
}

struct WorkspaceSectionPicker: View {
    @Binding var selectedSection: WorkspaceSection

    var body: some View {
        HStack(spacing: 4) {
            ForEach(WorkspaceSection.allCases) { section in
                Button {
                    selectedSection = section
                } label: {
                    Label(section.title, systemImage: section.systemImage)
                        .labelStyle(.titleAndIcon)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white.opacity(selectedSection == section ? 1 : 0.72))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(
                            selectedSection == section ? Color.blue.opacity(0.82) : Color.white.opacity(0.05),
                            in: Capsule()
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Color.black.opacity(0.26), in: Capsule())
        .overlay(Capsule().stroke(Color.white.opacity(0.08), lineWidth: 1))
    }
}
