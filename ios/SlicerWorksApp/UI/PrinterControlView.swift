import SwiftUI

struct PrinterControlView: View {
    @EnvironmentObject private var store: AppStore
    @State private var showStatusPanel = true
    @State private var showMaterialsPanel = true
    @State private var workspaceCamera = WorkspaceCamera()
    @State private var printerPendingAccessCodeEntry: BambuLANPrinter?
    @State private var printerPendingAccessCodeEdit: BambuLANPrinter?

    var body: some View {
        GeometryReader { _ in
            ZStack {
                workspaceBackground

                deviceWorkspace
                    .padding(12)

                topBar
                    .padding(.top, 18)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                leftChrome
                    .padding(.leading, 10)
                    .padding(.top, 20)
                    .padding(.bottom, 18)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)

                rightChrome
                    .padding(.trailing, 12)
                    .padding(.top, 20)
                    .padding(.bottom, 18)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)

                bottomChrome
                    .padding(.horizontal, 18)
                    .padding(.bottom, 18)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            }
        }
        .navigationBarHidden(true)
        .background(Color.black)
        .sheet(item: $printerPendingAccessCodeEntry) { printer in
            BambuPrinterAccessCodeSheet(printer: printer) { updatedPrinter, accessCode in
                store.addKnownLANPrinter(updatedPrinter, accessCode: accessCode)
            }
        }
        .sheet(item: $printerPendingAccessCodeEdit) { printer in
            BambuPrinterAccessCodeSheet(
                printer: printer,
                initialAccessCode: printer.accessCode ?? ""
            ) { updatedPrinter, accessCode in
                store.addKnownLANPrinter(updatedPrinter, accessCode: accessCode)
            }
        }
    }

    private var workspaceBackground: some View {
        LinearGradient(
            colors: [
                Color(red: 0.10, green: 0.10, blue: 0.11),
                Color(red: 0.07, green: 0.07, blue: 0.08)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            miniTopIcon("printer.fill")
            Text(store.selectedLANPrinter?.name ?? store.selectedPrinter.displayName)
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white)
            Button("Discover") {
                Task { await store.discoverPrintersOnLAN() }
            }
            .buttonStyle(DeviceCapsuleStyle(fill: Color.white.opacity(0.08)))
            Button("Status") {}
            .buttonStyle(DeviceCapsuleStyle(fill: Color.white.opacity(0.08)))
            Button("Queue") {}
                .buttonStyle(DeviceCapsuleStyle(fill: Color.blue.opacity(0.88)))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().stroke(Color.white.opacity(0.08), lineWidth: 1))
    }

    private var leftChrome: some View {
        VStack(alignment: .leading, spacing: 12) {
            chromeLabel("Status", "wave.3.right") {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showStatusPanel.toggle()
                }
            }
            chromeLabel("Storage", "externaldrive") {}
            chromeLabel("Materials", "square.stack.3d.up") {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showMaterialsPanel.toggle()
                }
            }
            chromeLabel("Assistant", "sparkles") {}

            if showStatusPanel {
                statusPanel
            }

            Spacer()
        }
    }

    private var rightChrome: some View {
        VStack(alignment: .trailing, spacing: 12) {
            orientationCluster

            if showMaterialsPanel {
                materialsPanel
            }

            floatingInfoCard(title: "Discovered on LAN") {
                if store.discoveredLANPrinters.isEmpty {
                    Text("Run Discover to search for nearby Bambu printers.")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.58))
                } else {
                    ForEach(store.discoveredLANPrinters) { printer in
                        discoveredPrinterRow(printer)
                    }
                }
            }
            .frame(width: 260, alignment: .leading)

            floatingInfoCard(title: "Controls") {
                deviceRow("LAN discovery", store.discoveryStatus.message)
                deviceRow("Cloud queue", "Future")
                deviceRow("AMS sync", "Ready")
                if let selectedLANPrinter = store.selectedLANPrinter {
                    deviceRow("Access code", selectedLANPrinter.hasAccessCode ? "Saved" : "Required")
                }
            }

            Spacer()
        }
    }

    private var bottomChrome: some View {
        HStack {
            floatingInfoCard(title: "Printer") {
                deviceRow("Selected", store.selectedLANPrinter?.name ?? "None")
                deviceRow("Profile", store.selectedPrinter.displayName)
                deviceRow("Host", store.selectedLANPrinter?.host ?? "Scan LAN")
                deviceRow("Access code", store.selectedLANPrinter?.hasAccessCode == true ? "Saved" : "Required")
            }
            .frame(width: 240, alignment: .leading)
            Spacer()
        }
    }

    private var deviceWorkspace: some View {
        WorkspaceViewport(camera: $workspaceCamera) {
            DeviceWorkspaceGrid()
                .clipShape(RoundedRectangle(cornerRadius: 28))
        } content: {
            HStack(spacing: 28) {
                deviceCard(title: "Camera") {
                    RoundedRectangle(cornerRadius: 18)
                        .fill(Color.black)
                        .overlay(Text("Live camera").foregroundStyle(.white.opacity(0.5)))
                }

                deviceCard(title: "Printer Stage") {
                    ZStack {
                        RoundedRectangle(cornerRadius: 18)
                            .fill(Color.white.opacity(0.04))
                        RoundedRectangle(cornerRadius: 20)
                            .fill(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.88), Color.green.opacity(0.72)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(width: 90, height: 150)
                            .rotation3DEffect(.degrees(18), axis: (x: 0, y: 1, z: 0))
                    }
                }
            }
            .padding(.horizontal, 120)
        }
    }

    private var statusPanel: some View {
        floatingInfoCard(title: "Bambu Lab") {
            deviceRow("LAN discovery", store.discoveryStatus.message)
            deviceRow("Cloud queue", "Future")
            deviceRow("AMS filament sync", "Available")
        }
        .frame(width: 220, alignment: .leading)
    }

    private var materialsPanel: some View {
        floatingInfoCard(title: "Materials") {
            deviceRow("PLA", "Loaded")
            deviceRow("PETG", "Idle")
            deviceRow("ABS", "Empty")
        }
        .frame(width: 220, alignment: .leading)
    }

    private func discoveredPrinterRow(_ printer: BambuLANPrinter) -> some View {
        let isKnown = store.knownLANPrinters.contains(where: { $0.id == printer.id || $0.serialNumber == printer.serialNumber })
        let isSelected = store.selectedLANPrinterID == printer.id

        return VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(printer.name)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                    Text("\(printer.profile.displayName)  \(printer.host)")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.58))
                }
                Spacer()
                Button(isKnown ? (isSelected ? "Selected" : "Use") : "Add") {
                    if isKnown {
                        if let knownPrinter = store.knownLANPrinters.first(where: { $0.serialNumber == printer.serialNumber || $0.host == printer.host }) {
                            if knownPrinter.hasAccessCode {
                                store.selectLANPrinter(knownPrinter.id)
                            } else {
                                printerPendingAccessCodeEdit = knownPrinter
                            }
                        }
                    } else {
                        printerPendingAccessCodeEntry = printer
                    }
                }
                .buttonStyle(DevicePillActionStyle(fill: isSelected ? Color.blue.opacity(0.9) : Color.white.opacity(0.1)))
            }
        }
        .padding(8)
        .background(Color.white.opacity(isSelected ? 0.10 : 0.04), in: RoundedRectangle(cornerRadius: 12))
    }

    private var orientationCluster: some View {
        WorkspaceNavigationCluster(camera: $workspaceCamera)
    }

    private func chromeLabel(_ title: String, _ systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                roundIconBadge(systemName)
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.9))
            }
        }
        .buttonStyle(.plain)
    }

    private func roundIconBadge(_ systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.white.opacity(0.9))
            .frame(width: 32, height: 32)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.08), lineWidth: 1))
    }

    private func miniTopIcon(_ systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.white.opacity(0.88))
            .frame(width: 28, height: 28)
    }

    private func floatingInfoCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(.white.opacity(0.76))
            content()
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.08), lineWidth: 1))
    }

    private func deviceRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(.white.opacity(0.56))
            Spacer()
            Text(value)
                .foregroundStyle(.white)
        }
        .font(.caption2)
    }

    private func deviceCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(.white.opacity(0.7))
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.black.opacity(0.16), in: RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.white.opacity(0.06), lineWidth: 1))
    }
}

private struct DevicePillActionStyle: ButtonStyle {
    let fill: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white.opacity(configuration.isPressed ? 0.75 : 1))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(fill.opacity(configuration.isPressed ? 0.8 : 1), in: Capsule())
    }
}

private struct DeviceCapsuleStyle: ButtonStyle {
    let fill: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white.opacity(configuration.isPressed ? 0.75 : 1))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(fill.opacity(configuration.isPressed ? 0.85 : 1), in: Capsule())
    }
}

private struct DeviceWorkspaceGrid: View {
    var body: some View {
        Canvas { context, size in
            let major = Color.white.opacity(0.07)
            let minor = Color.white.opacity(0.028)

            for x in stride(from: 0, through: size.width, by: 24) {
                var path = Path()
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                context.stroke(path, with: .color(minor), lineWidth: 1)
            }

            for y in stride(from: 0, through: size.height, by: 24) {
                var path = Path()
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                context.stroke(path, with: .color(minor), lineWidth: 1)
            }

            for x in stride(from: 0, through: size.width, by: 96) {
                var path = Path()
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                context.stroke(path, with: .color(major), lineWidth: 1.1)
            }

            for y in stride(from: 0, through: size.height, by: 96) {
                var path = Path()
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                context.stroke(path, with: .color(major), lineWidth: 1.1)
            }
        }
    }
}
