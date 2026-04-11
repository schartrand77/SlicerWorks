import SwiftUI

struct BambuPrinterAccessCodeSheet: View {
    let printer: BambuLANPrinter
    let initialAccessCode: String
    let onSave: (BambuLANPrinter, String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var printerName: String
    @State private var serialNumber: String
    @State private var accessCode: String
    @FocusState private var isAccessCodeFocused: Bool

    init(
        printer: BambuLANPrinter,
        initialAccessCode: String = "",
        onSave: @escaping (BambuLANPrinter, String) -> Void
    ) {
        self.printer = printer
        self.initialAccessCode = initialAccessCode
        self.onSave = onSave
        _printerName = State(initialValue: printer.name)
        _serialNumber = State(initialValue: printer.serialNumber)
        _accessCode = State(initialValue: initialAccessCode)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Printer") {
                    TextField("Printer name", text: $printerName)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .accessibilityIdentifier("printer-name-field")
                    TextField("Serial number", text: $serialNumber)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .accessibilityIdentifier("printer-serial-number-field")
                    detailRow("Model", printer.profile.displayName)
                    detailRow("Host", printer.host)
                }

                Section("LAN Access Code") {
                    SecureField("Access code", text: $accessCode)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .accessibilityIdentifier("printer-access-code-field")
                        .textContentType(.oneTimeCode)
                        .focused($isAccessCodeFocused)
                        .submitLabel(.done)
                        .onSubmit(saveAccessCode)
                    Text("Bambu LAN connections use the printer host, serial number, and LAN access code.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle(initialAccessCode.isEmpty ? "Add Printer" : "Edit Printer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: saveAccessCode)
                        .disabled(trimmedPrinterName.isEmpty || trimmedAccessCode.isEmpty)
                }
            }
        }
        .onAppear {
            isAccessCodeFocused = true
        }
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
        }
    }

    private var trimmedAccessCode: String {
        accessCode.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedPrinterName: String {
        printerName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedSerialNumber: String {
        serialNumber.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func saveAccessCode() {
        guard trimmedPrinterName.isEmpty == false,
              trimmedAccessCode.isEmpty == false else {
            return
        }

        var updatedPrinter = printer
        updatedPrinter.name = trimmedPrinterName
        updatedPrinter.serialNumber = trimmedSerialNumber.isEmpty ? printer.serialNumber : trimmedSerialNumber

        onSave(updatedPrinter, trimmedAccessCode)
        dismiss()
    }
}
