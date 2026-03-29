import SwiftUI
import FirebaseAuth

struct TournamentDetailView: View {
    @EnvironmentObject private var appState: AppState
    let tournament: Tournament

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                VStack(alignment: .leading, spacing: 4) {
                    Text(tournament.name).font(.system(size: 22, weight: .semibold))
                    Text("\(tournament.dateRange) • \(tournament.location)")
                        .font(.system(size: 12)).foregroundColor(.textSecondary)
                }
                VStack(alignment: .leading, spacing: 4){
                    Text("Assigned Matches")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Tap a match to view details or start officiating")
                        .font(.system(size: 12)).foregroundColor(.textSecondary)
                }
                
                VStack(spacing: 12) {
                    ForEach(appState.matches(for: tournament)) { m in
                        MatchRowCard(match: m) {
                            // Navigate based on status
                            switch m.status {
                            case .live:
                                appState.selectedMatch = m
                                appState.umpirePath.append(.matchScoring(m))
                                
                            case .upcoming:
                                Task {
                                    guard let tid = appState.selectedTournament?.id else { return }

                                    // Write to Firestore (async, but not blocking UI)
                                    try? await appState.markMatchLive(
                                        tournamentID: tid,
                                        matchID: m.id
                                    )

                                    // Create a LOCAL live copy for navigation
                                    var liveMatch = m
                                    liveMatch.status = .live

                                    await MainActor.run {
                                        appState.selectedMatch = liveMatch
                                        appState.umpirePath.append(.matchScoring(liveMatch))
                                    }
                                }

                                
                            case .completed:
                                appState.umpirePath.append(.matchDetails(m))
                            }
                        }
                    }
                }
            }
            .padding(16)
        }
        .accessibilityIdentifier("tournamentDetail")
        .refreshable {
            guard let email = Auth.auth().currentUser?.email else { return }
            await appState.refreshMatchesForKnownTournament(
                tournamentID: tournament.id,
                email: email
            )
        }

        .background(Color.appBackground.ignoresSafeArea())
        .navigationTitle("Matches")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct MatchRowCard: View {
    let match: Match
    var onPrimary: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                // Status pill + time
                StatusPill(text: match.status.rawValue,
                           color: statusBg.opacity(0.15),
                           textColor: statusBg)
                Spacer()
                HStack(spacing: 6) {
                    Image(systemName: "clock")
                    Text(match.time)
                }
                .foregroundColor(.textSecondary)
                .font(.system(size: 12))
            }

            HStack(alignment: .center, spacing: 12) {
                Avatar(initials: initials(match.player1), color: .primaryBlue)
                VStack(alignment: .leading, spacing: 2) {
                    Text(match.player1).font(.system(size: 16, weight: .semibold))
                    Text("Player 1").font(.system(size: 12)).foregroundColor(.textSecondary)
                }
                Spacer()
                Text(match.status == .upcoming ? "–" : "\(setsWon.p1)")
                    .font(.system(size: 16, weight: .semibold))
            }

            VStack(spacing: 2) {
                Divider()
                Text("vs")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }

            HStack(alignment: .center, spacing: 12) {
                Avatar(initials: initials(match.player2), color: .successGreen)
                VStack(alignment: .leading, spacing: 2) {
                    Text(match.player2).font(.system(size: 16, weight: .semibold))
                    Text("Player 2").font(.system(size: 12)).foregroundColor(.textSecondary)
                }
                Spacer()
                Text(match.status == .upcoming ? "–" : "\(setsWon.p2)")
                    .font(.system(size: 16, weight: .semibold))
            }

            Divider()

            HStack(spacing: 12) {
                IconTextRow(systemName: "sportscourt", text: match.court)
                Spacer()
                AppButton(primaryTitle,
                          variant: .primary,
                          isFullWidth: true,
                          action: onPrimary)
                .frame(maxWidth: 180)
            }
            .accessibilityIdentifier("startMatchButton")

        }
        .cardStyle()
    }

    private var primaryTitle: String {
        switch match.status {
        case .upcoming: return "Start Match"
        case .live: return "Continue Match"
        case .completed: return "View Details"
        }
    }

    private var statusBg: Color {
        switch match.status {
        case .live: return .successGreen
        case .upcoming: return .blue600
        case .completed: return .textSecondary
        }
    }

    private func initials(_ name: String) -> String {
        let parts = name.split(separator: " ")
        let letters = parts.prefix(2).compactMap { $0.first }
        return String(letters).uppercased()
    }
    
    private var setsWon: (p1: Int, p2: Int) {
        guard let score = match.score else { return (0, 0) }

        let cleaned = score.replacingOccurrences(of: ",", with: " ")
        let tokens = cleaned.split(separator: " ")

        var p1 = 0
        var p2 = 0

        for token in tokens {
            let parts = token.split(separator: "-")
            guard parts.count == 2,
                  let g1 = Int(parts[0]),
                  let g2 = Int(parts[1]) else { continue }

            if g1 > g2 { p1 += 1 }
            else if g2 > g1 { p2 += 1 }
        }

        return (p1, p2)
    }
}

private struct Avatar: View {
    let initials: String
    let color: Color
    var body: some View {
        Text(initials)
            .font(.system(size: 14, weight: .bold))
            .foregroundColor(.white)
            .frame(width: 36, height: 36)
            .background(color)
            .clipShape(Circle())
    }
}

