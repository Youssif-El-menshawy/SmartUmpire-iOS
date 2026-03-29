import SwiftUI

struct MatchManagementView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    let tournament: Tournament
    let match: Match

    @State private var goAssign = false
    @State private var confirmDelete = false
    @State private var editingMatch: Match? = nil

    
    //Tries to fetch the latest version of the match from AppState
    //Falls back to the originally passed match if not found
    private var liveMatch: Match {
        appState.matchesByTournament[tournament.id]?
            .first(where: { $0.id == match.id }) ?? match
    }
    
    private var canAssignUmpire: Bool {
        liveMatch.status == .upcoming
    }



    var body: some View {
        VStack(spacing: 24) {

            MatchSummaryView(match: liveMatch, tournament: tournament)

            Spacer()
            
            AppButton(
                primaryActionTitle,
                variant: .primary,
                icon: "person.badge.plus",
                isFullWidth: true
            ) {
                goAssign = true
            }
            .disabled(!canAssignUmpire)
            .opacity(canAssignUmpire ? 1.0 : 0.5)
            
            if !canAssignUmpire {
                Text(
                    liveMatch.status == .completed
                    ? "Umpires cannot be assigned after a match is completed."
                    : "Umpires cannot be changed while a match is live."
                )
                .font(.system(size: 12))
                .foregroundColor(.textSecondary)
            }
        }
        .padding()
        .navigationTitle("Match Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarMenu }
        .navigationDestination(isPresented: $goAssign) {
            SelectUmpireView(tournament: tournament, match: liveMatch)
        }
        .alert("Delete Match?", isPresented: $confirmDelete) {
            Button("Delete", role: .destructive) {
                deleteMatch()
            }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(item: $editingMatch) { m in
            MatchForm(mode: .edit(tournament: tournament, match: m)) { result in
                if case .saved(let data) = result {
                    Task {
                        try await appState.updateMatch(
                            tournamentID: tournament.id,
                            matchID: m.id,
                            time: data.time,
                            court: data.court,
                            player1: data.player1,
                            player2: data.player2,
                            round: data.round,
                            status: data.status
                        )
                    }
                }
            }
        }
        .onAppear {
            let state = appState
            if match.status == .live {
                state.watchMatches(for: tournament.id)
            }
        }
    }
    
    private var primaryActionTitle: String {
        liveMatch.assignedUmpire == nil ? "Assign Umpire" : "Change Umpire"
    }

    
    private var toolbarMenu: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button("Edit Match") {
                    editingMatch = liveMatch
                }
                .disabled(liveMatch.status == .completed)


                Button("Delete Match", role: .destructive) {
                    confirmDelete = true
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 18, weight: .regular))
                    .foregroundColor(.accentColor)
            }
        }
    }
    
    private func deleteMatch() {
        Task {
            do {
                try await appState.deleteMatch(
                    tournamentID: tournament.id,
                    matchID: match.id
                )
                dismiss()
            } catch {
                print(error.localizedDescription)
            }
        }
    }
}
