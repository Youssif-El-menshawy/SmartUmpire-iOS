//
//  MatchForm.swift
//  SmartUmpire
//
//  Created by Youssef on 05/01/2026.
//

import SwiftUI

enum MatchFormMode: Equatable {
    case create(tournament: Tournament)
    case edit(tournament: Tournament, match: Match)
}

enum MatchFormResult {
    case cancelled
    case saved(MatchFormData)
}

enum MatchRound: String, CaseIterable {
    case group = "Group Stage"
    case round32 = "Round of 32"
    case round16 = "Round of 16"
    case quarter = "Quarter Finals"
    case semi = "Semi Finals"
    case final = "Final"
}


struct MatchFormData {
    let time: String
    let court: String
    let player1: String
    let player2: String
    let round: String
    let status: MatchStatus
}

struct MatchForm: View {
    let mode: MatchFormMode
    var onComplete: (MatchFormResult) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var court = ""
    @State private var player1 = ""
    @State private var player2 = ""
    @State private var matchDate = Date()
    @State private var selectedRound: MatchRound = .group
    @State private var status: MatchStatus = .upcoming
    

    var body: some View {
        NavigationStack {
            Form {
                Section("Match Details") {
                    DatePicker(
                        "Match Time",
                        selection: $matchDate,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    Picker("Round", selection: $selectedRound) {
                        ForEach(MatchRound.allCases, id: \.self) { round in
                            Text(round.rawValue).tag(round)
                        }
                    }
                    TextField("Court", text: $court)
                }

                Section("Players") {
                    TextField("Player 1", text: $player1)
                    TextField("Player 2", text: $player2)
                }

                Section("Status") {
                    Picker("Status", selection: $status) {
                        ForEach(MatchStatus.allCases, id: \.self) { s in
                            Text(s.rawValue).tag(s)
                        }
                    }
                    .disabled(!mode.isEdit)
                }
            }
            .navigationTitle(mode.isEdit ? "Edit Match" : "Add Match")
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
                        onComplete(.saved(buildData()))
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
    private var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: matchDate)
    }

    private var isValid: Bool {
        !court.trimmingCharacters(in: .whitespaces).isEmpty &&
        !player1.trimmingCharacters(in: .whitespaces).isEmpty &&
        !player2.trimmingCharacters(in: .whitespaces).isEmpty
    }

    
    private func buildData() -> MatchFormData {
        MatchFormData(
            time: formattedTime,
            court: court,
            player1: player1,
            player2: player2,
            round: selectedRound.rawValue,
            status: status
        )
    }


    private func populateIfEditing() {
        guard case .edit(_, let match) = mode else { return }
        
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short

        if let date = formatter.date(from: match.time) {
            matchDate = date
        }
        
        if let r = MatchRound.allCases.first(where: { $0.rawValue == match.round }) {
            selectedRound = r
        }

        court = match.court
        player1 = match.player1
        player2 = match.player2
        status = match.status
    }
}

private extension MatchFormMode {
    var isEdit: Bool {
        if case .edit = self { return true }
        return false
    }
}
