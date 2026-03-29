//
//  AdminUmpireMatchesView.swift
//  SmartUmpire
//
//  Created by Youssef on 24/12/2025.
//

import SwiftUI

struct AdminUmpireMatchesView: View {

    @EnvironmentObject private var appState: AppState
    let umpireID: String

    private var umpire: Umpire? {
        appState.umpires.first { $0.id == umpireID }
    }

    private var assignedMatches: [Match] {
        guard let email = umpire?.email else { return [] }

        return appState.matchesByTournament
            .values // like this [ [m1, m2], [m3] ] bec its a dictionary "t1": [m1, m2], "t2": [m3]
            .flatMap { $0 } // flatten into one list like this [m1, m2, m3]
            .filter { $0.assignedUmpireEmail == email }
    }


    var body: some View {
        List {
            if assignedMatches.isEmpty {
                emptyState
            } else {
                ForEach(assignedMatches) { match in
                    matchRow(match)
                }
            }
        }
        .navigationTitle("Assigned Matches")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func tournamentFor(_ match: Match) -> Tournament? {
        for t in appState.tournaments {
            if let matches = appState.matchesByTournament[t.id],
               matches.contains(where: { $0.id == match.id }) {
                return t
            }
        }
        return nil
    }

}

private extension AdminUmpireMatchesView {

    func matchRow(_ match: Match) -> some View {
        Button {
            if let tournament = tournamentFor(match) {
                 appState.adminPath.append(
                     .adminUmpireDetailMatchWithTournament(match, tournament)
                 )
             }
        } label: {
            VStack(alignment: .leading, spacing: 8) {

                HStack {
                    Text("\(match.player1) vs \(match.player2)")
                        .font(.system(size: 16, weight: .semibold))

                    Spacer()

                    StatusPill(
                        text: match.status.rawValue.capitalized,
                        color: statusColor(match.status).opacity(0.15),
                        textColor: statusColor(match.status)
                    )
                }

                HStack(spacing: 6) {
                    Image(systemName: "sportscourt")
                        .font(.caption)
                    Text(match.court)
                        .font(.caption)

                    Text("•")
                        .font(.caption)

                    Text(match.round)
                        .font(.caption)
                }
                .foregroundColor(.textSecondary)
            }
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
    }

    func statusColor(_ status: MatchStatus) -> Color {
        switch status {
        case .upcoming: return .warningYellow
        case .live: return .successGreen
        case .completed: return .textSecondary
        }
    }

    
    var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "sportscourt")
                .font(.system(size: 32))
                .foregroundColor(.textSecondary)

            Text("No assigned matches")
                .font(.headline)

            Text("This umpire has not been assigned to any matches yet.")
                .font(.subheadline)
                .foregroundColor(.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 40)
        .listRowSeparator(.hidden)
    }
}
