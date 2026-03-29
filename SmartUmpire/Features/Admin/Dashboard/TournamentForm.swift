import SwiftUI

enum TournamentFormMode: Equatable {
    case create
    case edit(existing: Tournament)
}

enum TournamentFormResult {
    case cancelled
    case saved(Tournament)
}

struct TournamentForm: View {
    let mode: TournamentFormMode
    var onComplete: (TournamentFormResult) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var startDate: Date = Date()
    @State private var endDate: Date = Date().addingTimeInterval(86400)
    @State private var location: String = ""
    @State private var status: TournamentStatus = .upcoming

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Details")) {
                    TextField("Name (e.g. Wimbledon Championships)", text: $name)
                    TextField("Location (e.g. London, United Kingdom)", text: $location)
                    DatePicker(
                        "Start Date",
                        selection: $startDate,
                        displayedComponents: .date
                    )

                    DatePicker(
                        "End Date",
                        selection: $endDate,
                        in: startDate...,
                        displayedComponents: .date
                    )

                    Picker("Status", selection: $status) {
                        Text("Upcoming").tag(TournamentStatus.upcoming)
                        Text("Live").tag(TournamentStatus.live)
                        Text("Completed").tag(TournamentStatus.completed)
                    }
                    .pickerStyle(.menu)
                }
            }
            .accessibilityIdentifier("createTournamentSheet")
            .navigationTitle(mode.isEdit ? "Edit Tournament" : "New Tournament")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                        onComplete(.cancelled)
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        dismiss()
                        onComplete(.saved(buildTournament()))
                    }
                    .disabled(!isValid)
                }
            }
            .onAppear {
                populateIfEditing()
            }
        }
    }

    // MARK: - Helpers

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !location.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var formattedDateRange: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return "\(formatter.string(from: startDate)) – \(formatter.string(from: endDate))"
    }

    private func buildTournament() -> Tournament {
        switch mode {
        case .create:
            return Tournament(
                id: UUID().uuidString,
                name: name,
                dateRange: formattedDateRange,
                location: location,
                matchesCount: 0,
                status: status
            )

        case .edit(let existing):
            return Tournament(
                id: existing.id,
                name: name,
                dateRange: formattedDateRange,
                location: location,
                matchesCount: existing.matchesCount,
                status: status
            )
        }
    }

    private func populateIfEditing() {
        guard case .edit(let existing) = mode else { return }

        name = existing.name
        location = existing.location
        status = existing.status
    }
}

private extension TournamentFormMode {
    var isEdit: Bool {
        if case .edit = self { return true }
        return false
    }
}
