import SwiftUI

struct BambuPrinterAccessCodeSheet: View {
    let printer: BambuLANPrinter
    let initialAccessCode: String
    let onSave: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var accessCode: String
    @FocusState private var isAccessCodeFocused: Bool

    init(
        printer: BambuLANPrinter,
        initialAccessCode: String = "",
        onSave: @escaping (String) -> Void
    ) {
        self.printer = printer
        self.initialAccessCode = initialAccessCode
        self.onSave = onSave
        _accessCode = State(initialValue: initialAccessCode)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Printer") {
                    detailRow("Name", printer.name)
                    detailRow("Profile", printer.profile.displayName)
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
                    Text("Bambu printers in LAN mode require the printer access code before they can be added and used.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Add Printer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: saveAccessCode)
                        .disabled(trimmedAccessCode.isEmpty)
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

    private func saveAccessCode() {
        guard trimmedAccessCode.isEmpty == false else {
            return
        }

        onSave(trimmedAccessCode)
        dismiss()
    }
}
