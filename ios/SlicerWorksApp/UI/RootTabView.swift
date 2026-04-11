import SwiftUI

struct RootTabView: View {
    @EnvironmentObject private var store: AppStore
    @State private var hasEnteredWorkspace = false
    @State private var selectedSection: WorkspaceSection = .prepare

    var body: some View {
        Group {
            if hasEnteredWorkspace {
                NavigationStack {
                    switch selectedSection {
                    case .prepare:
                        SlicerDashboardView(selectedSection: $selectedSection)
                    case .print:
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
    case prepare
    case print

    var id: String { rawValue }

    var title: String {
        switch self {
        case .prepare:
            return "Prepare"
        case .print:
            return "Print"
        }
    }

    var systemImage: String {
        switch self {
        case .prepare:
            return "cube"
        case .print:
            return "printer.fill"
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
