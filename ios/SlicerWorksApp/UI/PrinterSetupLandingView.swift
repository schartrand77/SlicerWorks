import SwiftUI

struct PrinterSetupLandingView: View {
    @EnvironmentObject private var store: AppStore
    @State private var printerPendingAccessCodeEntry: BambuLANPrinter?

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

                    Text("Add Your Bambu Printer")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text("SlicerWorks starts with printer setup so slicing and send-to-printer work from the first session. Scan your network, then enter the printer access code for Bambu LAN mode.")
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

                    Button {
                        Task { await store.discoverPrintersOnLAN() }
                    } label: {
                        HStack {
                            Image(systemName: "wifi")
                            Text("Scan Network for Bambu Printers")
                                .fontWeight(.semibold)
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.blue.opacity(0.9), in: RoundedRectangle(cornerRadius: 16))
                    }
                    .buttonStyle(.plain)

                    if store.discoveredLANPrinters.isEmpty {
                        Text("No printers listed yet. Run a LAN scan to find available Bambu devices.")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.55))
                    } else {
                        VStack(spacing: 10) {
                            ForEach(store.discoveredLANPrinters) { printer in
                                discoveredPrinterCard(printer)
                            }
                        }
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
