import SwiftUI

struct CertificationsEditorView: View {
    @EnvironmentObject private var appState: AppState
    let umpire: Umpire

    @State private var certs: [UmpireCertification] = []
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        List {

            Section(header: Text("Certifications")) {
                ForEach($certs) { $cert in
                    VStack(alignment: .leading, spacing: 10) {

                        TextField("Title", text: $cert.title)
                            .font(.system(size: 16, weight: .semibold))

                        TextField("Issuer", text: $cert.issuer)
                            .font(.system(size: 14))

                        TextField("Year", text: $cert.year)
                            .keyboardType(.numberPad)
                            .font(.system(size: 14))

                        Toggle("Active", isOn: $cert.active)
                            .font(.system(size: 14))
                    }
                    .padding(.vertical, 6)
                }
                .onDelete { indexSet in
                    certs.remove(atOffsets: indexSet)
                }
            }

            Section {
                Button {
                    addCertification()
                } label: {
                    Label("Add Certification", systemImage: "plus.circle")
                }
            }
        }
        .navigationTitle("Certifications")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if isSaving {
                    ProgressView()
                } else {
                    Button("Save") {
                        Task { await save() }
                    }
                    .disabled(!canSave)
                }
            }
        }
        .onAppear {
            certs = umpire.certifications ?? []
        }
        .alert("Error", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // MARK: - Validation

    private var canSave: Bool {
        certs.allSatisfy {
            !$0.title.trimmingCharacters(in: .whitespaces).isEmpty &&
            !$0.issuer.trimmingCharacters(in: .whitespaces).isEmpty &&
            !$0.year.trimmingCharacters(in: .whitespaces).isEmpty
        }
    }

    // MARK: - Actions

    private func addCertification() {
        let newCert = UmpireCertification(
            id: UUID().uuidString,
            title: "",
            issuer: "",
            year: "",
            active: true
        )
        certs.append(newCert)
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }

        do {
            try await appState.updateUmpireCertifications(
                umpireID: umpire.id,
                certifications: certs
            )

            await MainActor.run {
                appState.adminPath.removeLast()
            }

        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
