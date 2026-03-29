import SwiftUI

struct UmpireForm: View {
    enum Mode { case create, edit(existing: Umpire) }
    enum Result { case cancelled, saved(Umpire) }

    let mode: Mode
    var onComplete: (Result) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var email = ""
    @State private var phone = ""
    @State private var location = ""
    @State private var status: UmpireStatus = .available
    @State private var specialization = "Hard Court"

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        email.trimmingCharacters(in: .whitespacesAndNewlines).contains("@")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Identity") {
                    TextField("Full name", text: $name)
                        .textInputAutocapitalization(.words)

                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                Section("Profile") {
                    TextField("Phone", text: $phone)
                        .keyboardType(.phonePad)

                    TextField("Location", text: $location)
                        .textInputAutocapitalization(.words)

                    TextField("Specialization", text: $specialization)
                        .textInputAutocapitalization(.words)

                    Picker("Status", selection: $status) {
                        ForEach(UmpireStatus.allCases, id: \.self) { s in
                            Text(s.rawValue.capitalized).tag(s)
                        }
                    }
                }
            }
            .navigationTitle(modeTitle)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onComplete(.cancelled); dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let saved = buildSavedUmpire()
                        onComplete(.saved(saved))
                        dismiss()
                    }
                    .disabled(!isValid)
                }
            }
            .onAppear { preload() }
        }
    }

    private var modeTitle: String {
        switch mode { case .create: return "Add Umpire"; case .edit: return "Edit Umpire" }
    }

    private func preload() {
        if case .edit(let u) = mode {
            name = u.name
            email = u.email
            phone = u.phone ?? ""
            location = u.location ?? ""
            specialization = u.specialization
            status = u.status
        }
    }

    private func buildSavedUmpire() -> Umpire {
        switch mode {
        case .create:
            return Umpire(
                id: UUID().uuidString,
                name: name,
                email: email,
                phone: phone.isEmpty ? nil : phone,
                location: location.isEmpty ? nil : location,
                specialization: specialization,
                rating: 0.0,
                matchesCount: 0,          
                tournaments: 0,
                yearsExperience: 0,
                status: status,
                performance: nil,
                certifications: nil,
                avatarURL: nil
            )

        case .edit(let existing):
            // Preserve system fields and performance/certs
            return Umpire(
                id: existing.id,
                name: name,
                email: email,
                phone: phone.isEmpty ? nil : phone,
                location: location.isEmpty ? nil : location,
                specialization: specialization,
                rating: existing.rating,
                matchesCount: existing.matchesCount,
                tournaments: existing.tournaments,
                yearsExperience: existing.yearsExperience,
                status: status,
                performance: existing.performance,
                certifications: existing.certifications,
                avatarURL: existing.avatarURL
            )
        }
    }
}
