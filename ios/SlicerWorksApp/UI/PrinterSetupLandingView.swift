import SwiftUI

struct PrinterSetupLandingView: View {
    @EnvironmentObject private var store: AppStore
    let onEnterApp: () -> Void

    @State private var printerPendingAccessCodeEntry: BambuLANPrinter?
    @State private var hasStartedInitialScan = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.09, green: 0.10, blue: 0.11),
                    Color(red: 0.05, green: 0.06, blue: 0.07)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer(minLength: 32)

                VStack(spacing: 12) {
                    Image(systemName: "printer.fill")
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.95))
                        .frame(width: 72, height: 72)
                        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 22))
                        .overlay(
                            RoundedRectangle(cornerRadius: 22)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )

                    Text("Check Your Bambu Printers")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text("SlicerWorks starts on this landing page every time. We scan your LAN for newly detected Bambu printers before you head into the workspace.")
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white.opacity(0.7))
                        .frame(maxWidth: 620)
                }

                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("LAN Setup")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white.opacity(0.72))
                        Spacer()
                        Text(store.discoveryStatus.message)
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.58))
                    }

                    if store.newlyDiscoveredLANPrinters.isEmpty {
                        Text(store.knownLANPrinters.isEmpty
                            ? "No new Bambu printers were detected on the LAN. You can enter the app or run another scan."
                            : "No additional Bambu printers were detected on the LAN. Your saved printers are ready, or you can run another scan."
                        )
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.55))

                        HStack(spacing: 12) {
                            Button {
                                Task { await store.discoverPrintersOnLAN() }
                            } label: {
                                HStack {
                                    Image(systemName: "wifi")
                                    Text("Scan Again")
                                        .fontWeight(.semibold)
                                }
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.blue.opacity(0.9), in: RoundedRectangle(cornerRadius: 16))
                            }
                            .buttonStyle(.plain)

                            Button {
                                onEnterApp()
                            } label: {
                                HStack {
                                    Image(systemName: "arrow.right.circle")
                                    Text("Enter App")
                                        .fontWeight(.semibold)
                                }
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
                            }
                            .buttonStyle(.plain)
                        }
                    } else {
                        Text("New Bambu printers were detected on the LAN. Add any printer you want to use in SlicerWorks.")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.62))

                        VStack(spacing: 10) {
                            ForEach(store.newlyDiscoveredLANPrinters) { printer in
                                discoveredPrinterCard(printer)
                            }
                        }

                        Button {
                            onEnterApp()
                        } label: {
                            Text(store.knownLANPrinters.isEmpty ? "Skip For Now" : "Enter App")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.72))
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.top, 4)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(20)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
                .frame(maxWidth: 720)

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
        }
        .sheet(item: $printerPendingAccessCodeEntry) { printer in
            BambuPrinterAccessCodeSheet(printer: printer) { accessCode in
                store.addKnownLANPrinter(printer, accessCode: accessCode)
            }
        }
        .task {
            guard hasStartedInitialScan == false else { return }
            hasStartedInitialScan = true
            await store.discoverPrintersOnLAN()
        }
    }

    private func discoveredPrinterCard(_ printer: BambuLANPrinter) -> some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.08))
                .frame(width: 48, height: 48)
                .overlay(
                    Image(systemName: "printer.dotmatrix.filled.and.paper")
                        .foregroundStyle(.white.opacity(0.9))
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(printer.name)
                    .font(.headline)
                    .foregroundStyle(.white)
                Text("\(printer.profile.displayName)  \(printer.host)")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.58))
                Text("Access code required for Bambu LAN mode")
                    .font(.caption2)
                    .foregroundStyle(.yellow.opacity(0.92))
            }

            Spacer()

            Button("Add Printer") {
                printerPendingAccessCodeEntry = printer
            }
            .buttonStyle(PrinterSetupActionStyle())
        }
        .padding(14)
        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 18))
    }
}

private struct PrinterSetupActionStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white.opacity(configuration.isPressed ? 0.75 : 1))
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.white.opacity(configuration.isPressed ? 0.14 : 0.08), in: Capsule())
    }
}
