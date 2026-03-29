import SwiftUI

struct AdminTournamentDetailView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    
    let tournament: Tournament
    
    @State private var showAddMatch = false
    @State private var confirmDeleteTournament = false
    @State private var editingTournament: Tournament? = nil
    @State private var selectedMatchForManage: Match? = nil
    @State private var matchFilter: MatchFilter = .all
    @State private var matchSearchQuery: String = ""


    var body: some View {
            VStack(spacing: 0) {
            
                ScrollView {
                    if appState.matches(for: tournament).isEmpty {
                        emptyState
                    } else {
                        VStack(spacing: 16) {
                            filterAndSearchGroup
                            matchesList
                        }
                    }
                }
            
            Divider()
            
                VStack(spacing: 12) {
                    AppButton(
                        "Add Match",
                        variant: .secondary,
                        icon: "plus",
                        isFullWidth: true
                    ) {
                        showAddMatch = true
                    }
                }
            .padding()
        }
        .navigationTitle(tournament.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarMenu }
        .onAppear {
            appState.watchMatches(for: tournament.id)
        }
        .onDisappear {
            appState.stopAllMatchListeners()
        }
        .sheet(isPresented: $showAddMatch) {
            MatchForm(mode: .create(tournament: tournament)) { result in
                if case .saved(let data) = result {
                    Task {
                        try await appState.createMatch(
                            tournamentID: tournament.id,
                            time: data.time,
                            court: data.court,
                            player1: data.player1,
                            player2: data.player2,
                            round: data.round
                        )
                    }
                }
            }
        }
        .alert("Delete Tournament?", isPresented: $confirmDeleteTournament) {
            Button("Delete", role: .destructive) {
                deleteTournament()
            }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(item: $editingTournament) { tournament in
            TournamentForm(mode: .edit(existing: tournament)) { result in
                if case .saved(let updated) = result {
                    Task { try? await appState.updateTournament(updated) }
                }
            }
        }
        .navigationDestination(item: $selectedMatchForManage) { match in
            MatchManagementView(
                tournament: tournament,
                match: match
            )
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "sportscourt")
                .font(.system(size: 40))
                .foregroundColor(.textSecondary)
            
            Text("No matches yet")
                .font(.system(size: 18, weight: .semibold))
            
            Text("Add a match to start assigning umpires.")
                .font(.system(size: 14))
                .foregroundColor(.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }
    
    private var matchesList: some View {
        VStack(spacing: 12) {
            if filteredMatches.isEmpty {
                Text("No matches found")
                    .foregroundColor(.secondary)
                    .padding(.top, 40)
            } else {
                ForEach(filteredMatches) { match in
                    MatchSelectableCard(
                        match: match,
                        onTap: {
                            selectedMatchForManage = match
                        }
                    )
                }
            }
        }
        .padding()
    }
    
    private var toolbarMenu: some ToolbarContent {
        Group {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Edit Tournament") {
                        editingTournament = tournament
                    }

                    Button("Delete Tournament", role: .destructive) {
                        confirmDeleteTournament = true
                    }
                    .disabled(tournament.status == .live)
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 18, weight: .regular))
                        .foregroundColor(.accentColor)
                }
            }
        }
    }

    
    private func deleteTournament() {
        Task {
            do {
                try await appState.deleteTournament(tournament)
                dismiss()
            } catch {
                print(error.localizedDescription)
            }
        }
    }
    
    private var matchFilterView: some View {
        Picker("Match Filter", selection: $matchFilter) {
            ForEach(MatchFilter.allCases) { filter in
                Text(filter.rawValue).tag(filter)
            }
        }
        .pickerStyle(.segmented)
    }

    
    private var filteredMatches: [Match] {
        let matches = appState.matches(for: tournament)

        // Filter by status
        let statusFiltered: [Match] = {
            switch matchFilter {
            case .all:
                return matches
            case .upcoming:
                return matches.filter { $0.status == .upcoming }
            case .live:
                return matches.filter { $0.status == .live }
            case .completed:
                return matches.filter { $0.status == .completed }
            }
        }()

        // Filter by search query
        let query = matchSearchQuery
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        guard !query.isEmpty else {
            return statusFiltered
        }

        return statusFiltered.filter { match in
            match.player1.lowercased().contains(query) ||
            match.player2.lowercased().contains(query) ||
            match.court.lowercased().contains(query) ||
            (match.assignedUmpire?.lowercased().contains(query) ?? false)
        }
    }

    
    private var filterAndSearchGroup: some View {
        VStack(spacing: 12) {

            // Match status filter
            matchFilterView

            Divider()
                .background(Color.border)

            // Search
            SearchBar(
                text: $matchSearchQuery,
                placeholder: "Search by player, court, or umpire..."
            )
        }
        .padding(12)
        .background(Color.cardBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.border)
        )
        .cornerRadius(16)
        .padding(.horizontal)
    }
}

enum MatchFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case upcoming = "Upcoming"
    case live = "Live"
    case completed = "Completed"

    var id: String { rawValue }
}
