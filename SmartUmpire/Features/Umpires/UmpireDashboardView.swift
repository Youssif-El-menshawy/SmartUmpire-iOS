import SwiftUI
import FirebaseAuth
import FirebaseFirestore


struct UmpireDashboardView: View {
    @EnvironmentObject private var appState: AppState
    @State private var avatarImage: UIImage?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

            
                // Header
                HStack(spacing: 12) {
                    
                    Button {
                        appState.umpirePath.append(.profile)
                    } label: {
                        Group {
                            if let avatarImage {
                                Image(uiImage: avatarImage)
                                    .resizable()
                                    .scaledToFill()
                            } else {
                                Image(systemName: "person.crop.circle.fill")
                                    .resizable()
                                    .scaledToFit()
                                    .padding(6)
                            }
                        }
                        .frame(width: 36, height: 36)
                        .background(Color.cardBackground)
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                    }

                    
                    Spacer()
                    
                    
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(.primaryBlue)
                        .font(.system(size: 22))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("SmartUmpire")
                            .font(.system(size: 20, weight: .bold))
                        Text("Officiator Dashboard")
                            .font(.system(size: 12))
                            .foregroundColor(.textSecondary)
                    }
                    Spacer()
                    

                    
                    Button {
                            appState.umpirePath.append(.settings)
                        } label: {
                            Image(systemName: "gearshape.fill")
                                .font(.system(size: 22))
                                .foregroundColor(.primaryBlue)
                                .frame(width: 36, height: 36)
                                .background(Color.cardBackground)
                                .cornerRadius(18)
                                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                        }
                    }
                    .padding(.horizontal, 4)

                // Section title
                VStack(alignment: .leading, spacing: 4) {
                    Text("My Tournaments")
                        .font(.system(size: 18, weight: .semibold))
                    Text("View and manage your assigned tournaments")
                        .font(.system(size: 12))
                        .foregroundColor(.textSecondary)
                }
                .padding(.top, 4)

                let sortedTournaments = assignedTournaments.sorted { lhs, rhs in
                    let s0 = appState.derivedTournamentStatus(for: lhs)
                    let s1 = appState.derivedTournamentStatus(for: rhs)
                    return sortRank(s0) < sortRank(s1)
                }

                // Tournament cards
                ForEach(sortedTournaments, id: \.id) { t in
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text(t.name)
                                .font(.system(size: 18, weight: .semibold))
                            
                            Spacer()
                            
                            let derivedStatus = appState.derivedTournamentStatus(for: t)

                            StatusPill(
                                text: derivedStatus.rawValue,
                                color: statusBg(derivedStatus),
                                textColor: statusText(derivedStatus)
                            )
                        }
                        IconTextRow(systemName: "calendar", text: t.dateRange)
                        IconTextRow(systemName: "mappin.and.ellipse", text: t.location)
                        IconTextRow(systemName: "person.3.fill", text: "\(t.matchesCount) matches assigned")

                        AppButton("View Matches",
                                  variant: .primary,
                                  isFullWidth: true) {
                            appState.selectedTournament = t
                            appState.umpirePath.append(.tournamentDetail(t))
                        }
                        .accessibilityIdentifier("viewMatchesButton")
                    }
                    .cardStyle()
                }
            }
            .padding(16)
        }
        .accessibilityIdentifier("umpireDashboard")
        .background(Color.appBackground.ignoresSafeArea())
        
        .onAppear {
            guard let email = Auth.auth().currentUser?.email else { return }

            // Ensure listener is active - watchMyMatches handles its own cleanup
            appState.watchMyMatches(for: email)
        }

        .refreshable {
            guard let email = Auth.auth().currentUser?.email else { return }

            // Stop and restart listener to force fresh query
            appState.stopMyMatchesListener()
            
            // Start fresh listener (it will automatically fetch tournaments in its callback)
            appState.watchMyMatches(for: email)
            
            // Give the listener time to fire and fetch tournaments
            // The listener callback will handle fetching tournaments automatically
            try? await Task.sleep(nanoseconds: 800_000_000)
        }
        .onAppear {
            loadAvatar()
        }
        .onChange(of: appState.currentUmpire?.avatarURL) { _, _ in
            loadAvatar()
        }




        
    }

    private func statusBg(_ s: TournamentStatus) -> Color {
        switch s { case .live: return .successGreen.opacity(0.15)
                   case .upcoming: return .warningYellow.opacity(0.15)
                   case .completed: return .textSecondary.opacity(0.12) }
    }
    private func statusText(_ s: TournamentStatus) -> Color {
        switch s { case .completed: return .textSecondary
                   default: return .textPrimary }
    }
    
    private var assignedTournaments: [Tournament] {
        appState.tournaments.filter { tournament in
            let matches = appState.matchesByTournament[tournament.id] ?? []
            return !matches.isEmpty
        }
    }



    private func sortRank(_ status: TournamentStatus) -> Int {
        switch status {
        case .live: return 0
        case .upcoming: return 1
        case .completed: return 2
        }
    }
    
    private func loadAvatar() {
        guard let umpire = appState.currentUmpire else { return }

        Task {
            avatarImage = await AvatarCache.shared.loadAvatar(
                umpireID: umpire.id,
                remoteURL: umpire.avatarURL
            )
        }
    }
}
