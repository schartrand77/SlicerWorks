import SwiftUI

struct BambuPrinterAccessCodeSheet: View {
    let printer: BambuLANPrinter
    let initialAccessCode: String
    let onSave: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var accessCode: String

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
                    Button("Save") {
                        onSave(accessCode)
                        dismiss()
                    }
                    .disabled(accessCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
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
}
