import SwiftUI
import CoreXLSX
import UniformTypeIdentifiers

enum AdminTab: String, CaseIterable {
    case tournaments = "Tournaments"
    case umpires = "Umpires"
}

struct AdminDashboardView: View {

    @EnvironmentObject private var appState: AppState

    @State private var tab: AdminTab = .tournaments
    @State private var umpireQuery: String = ""

    @State private var showUmpireForm = false
    @State private var editingUmpire: Umpire? = nil

    @State private var showCreateTournament = false
    @State private var selectedTournamentForManage: Tournament? = nil
    
    @State private var showImporter = false


    var body: some View {
        
        ZStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    
                    // Header
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(.primaryBlue)
                            .font(.system(size: 22))
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("SmartUmpire")
                                .font(.system(size: 20, weight: .semibold))
                            Text("Administrator Dashboard")
                                .font(.system(size: 12))
                                .foregroundColor(.textSecondary)
                        }
                        
                        Spacer()
                        
                        Button {
                            appState.adminPath.append(.settings)
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "gearshape.fill")
                                Text("Settings")
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.cardBackground)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.border)
                            )
                            .cornerRadius(10)
                        }
                        .accessibilityIdentifier("settingsButton")
                    }
                    
                    // Stats Grid
                    let stats = appState.adminStats
                    
                    LazyVGrid(
                        columns: [GridItem(.flexible()), GridItem(.flexible())],
                        spacing: 12
                    ) {
                        AdminStatTile(
                            icon: "person.3.fill",
                            title: "Total Umpires",
                            value: "\(stats.umpires)",
                            tint: SwiftUI.Color.primaryBlue.opacity(0.9)
                        )
                        
                        AdminStatTile(
                            icon: "trophy.fill",
                            title: "Total Tourney",
                            value: "\(stats.tournaments)",
                            tint: .successGreen.opacity(0.9)
                        )
                        
                        AdminStatTile(
                            icon: "sportscourt.fill",
                            title: "Total Matches",
                            value: "\(stats.matches)",
                            tint: .purple.opacity(0.9)
                        )
                        
                        AdminStatTile(
                            icon: "star.fill",
                            title: "Avg Rating",
                            value: stats.avgRating,
                            tint: .warningYellow.opacity(0.9)
                        )
                    }
                    
                    // Tabs
                    SegmentedTabs(
                        selection: $tab,
                        tabs: AdminTab.allCases.map(\.rawValue)
                    )
                    
                    // Tab Content
                    Group {
                        switch tab {
                        case .umpires:
                            umpiresTab
                        case .tournaments:
                            tournamentsTab
                        }
                    }
                }
                .padding(16)
                .id(tab) // reset scroll on tab change
            }
            .disabled(appState.isImporting)
            
            .background(Color.appBackground.ignoresSafeArea())
            .refreshable {
                appState.stopAllListeners()
                await appState.fetchTournamentsAndMatches()
                appState.watchTournaments()
                appState.watchUmpires()
            }
            .onAppear {
                Task {
                    await appState.fetchTournamentsAndMatches()
                }
            }
            .task {
                appState.watchTournaments()
            }
            .task {
                appState.watchUmpires()
            }
            .navigationTitle("")
            .navigationDestination(item: $selectedTournamentForManage) { tournament in
                AdminTournamentDetailView(tournament: tournament)
            }
            .accessibilityIdentifier("adminDashboard")
            .sheet(isPresented: $showUmpireForm) {
                if let edit = editingUmpire {
                    UmpireForm(mode: .edit(existing: edit)) { result in
                        if case .saved(let updated) = result {
                            Task {
                                try? await appState.updateUmpire(updated)
                            }
                        }
                    }
                } else {
                    UmpireForm(mode: .create) { result in
                        if case .saved(let created) = result {
                            Task {
                                try? await appState.createUmpire(
                                    name: created.name,
                                    email: created.email,
                                    phone: created.phone,
                                    location: created.location,
                                    rating: 0.0,
                                    matchesCount: 0,
                                    status: created.status,
                                    specialization: created.specialization
                                )
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $showCreateTournament) {
                TournamentForm(mode: .create) { result in
                    if case .saved(let created) = result {
                        Task {
                            try? await appState.createTournament(created)
                        }
                    }
                }
            }
            .fileImporter(
                isPresented: $showImporter,
                allowedContentTypes: [.spreadsheet]
            ) { result in
                switch result {
                case .success(let url):
                    Task {
                        try? await handleImport(url: url)
                    }
                case .failure(let error):
                    print("Import failed:", error)
                }
            }
            
            
            if appState.isImporting {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Importing Excel...")
                        .font(.system(size: 14, weight: .medium))
                }
                .padding(24)
                .background(.ultraThinMaterial)
                .cornerRadius(16)
            }
        }
    }

    // MARK: - Umpires Tab

    private var umpiresTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Manage Umpires")
                    .font(.system(size: 16, weight: .semibold))

                Spacer()

                AppButton(
                    "Add Umpire",
                    variant: .primary,
                    icon: "person.badge.plus",
                    isFullWidth: false
                ) {
                    editingUmpire = nil
                    showUmpireForm = true
                }
                .frame(height: 54)
                .accessibilityIdentifier("addUmpireButton")
            }

            SearchBar(
                text: $umpireQuery,
                placeholder: "Search umpires by name or email..."
            )

            VStack(spacing: 8) {
                ForEach(filteredUmpires) { u in
                    SimpleUmpireRow(umpire: u) {
                        appState.currentUmpire = u
                        appState.adminPath.append(
                            .adminUmpireDetail(umpireID: u.id)
                        )
                    }
                }
            }
        }
    }

    private var filteredUmpires: [Umpire] {
        let q = umpireQuery
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        guard !q.isEmpty else { return appState.umpires }

        return appState.umpires.filter {
            $0.name.lowercased().contains(q) ||
            $0.email.lowercased().contains(q)
        }
    }

    // MARK: - Tournaments Tab

    private var tournamentsTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Manage Tournaments")
                    .font(.system(size: 16, weight: .semibold))

                Spacer()
                
                AppButton(
                        "Import Excel",
                        variant: .secondary,
                        icon: "square.and.arrow.down",
                        isFullWidth: false
                    ) {
                        showImporter = true
                    }
                    .frame(height: 54)
                
                AppButton(
                    "Create Tournament",
                    variant: .primary,
                    icon: "plus",
                    isFullWidth: false
                ) {
                    showCreateTournament = true
                }
                .frame(height: 54)
                .accessibilityIdentifier("addTourneyButton")
            }

            ForEach(appState.tournaments) { t in
                Button {
                    selectedTournamentForManage = t
                } label: {
                    VStack(alignment: .leading, spacing: 10) {

                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(t.name)
                                    .font(.system(size: 18, weight: .semibold))

                                Text("\(t.dateRange) • \(t.location)")
                                    .font(.system(size: 12))
                                    .foregroundColor(.textSecondary)
                            }

                            Spacer()

                            StatusPill(
                                text: t.status.rawValue,
                                color: statusColor(t.status).opacity(0.15),
                                textColor: statusColor(t.status)
                            )
                        }

                        HStack(spacing: 10) {
                            IconTextRow(
                                systemName: "person.3.fill",
                                text: "Umpires: \(appState.umpires.count)"
                            )

                            IconTextRow(
                                systemName: "sportscourt",
                                text: "Matches: \(appState.matches(for: t).count)"
                            )
                        }
                    }
                    .contentShape(Rectangle())
                }
                .accessibilityIdentifier("tournamentCard_\(t.id)")
                .buttonStyle(.plain)
                .cardStyle()
            }
        }
    }

    private func statusColor(_ status: TournamentStatus) -> SwiftUI.Color {
        switch status {
        case .live:
            return .successGreen
        case .upcoming:
            return .warningYellow
        case .completed:
            return .errorRed
        }
    }
    
    func handleImport(url: URL) async throws {

        guard url.startAccessingSecurityScopedResource() else {
            print("Failed to access file")
            return
        }
        defer { url.stopAccessingSecurityScopedResource() }

        guard let file = XLSXFile(filepath: url.path) else { return }

        guard let sharedStrings = try? file.parseSharedStrings() else { return }
        guard let worksheetPath = try file.parseWorksheetPaths().first else { return }
        let worksheet = try file.parseWorksheet(at: worksheetPath)

        var rowsData: [[String]] = []

        for row in worksheet.data?.rows ?? [] {
            var rowValues: [String] = []

            for cell in row.cells {
                let string = cell.stringValue(sharedStrings) ?? ""
                rowValues.append(string)
            }

            rowsData.append(rowValues)
        }

        guard rowsData.count > 1 else { return }

        let dataRows = Array(rowsData.dropFirst())

        await appState.importFromExcel(rows: dataRows)
    }

}




// MARK: - Subviews

struct AdminStatTile: View {
    let icon: String
    let title: String
    let value: String
    let tint: SwiftUI.Color
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(tint)
                .frame(width: 36, height: 36)
                .background(tint.opacity(0.15))
                .cornerRadius(8)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 12)).foregroundColor(.textSecondary)
                Text(value).font(.system(size: 24, weight: .semibold)).foregroundColor(.textPrimary)
            }
            Spacer()
        }
        .cardStyle()
    }
}

struct SegmentedTabs: View {
    @Binding var selection: AdminTab
    let tabs: [String]

    init(selection: Binding<AdminTab>, tabs: [String]) {
        _selection = selection
        self.tabs = tabs
    }

    var body: some View {
        HStack(spacing: 8) {
            ForEach(AdminTab.allCases, id: \.self) { tab in
                Button {
                    selection = tab
                } label: {
                    Text(tab.rawValue)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(selection == tab ? .white : .textPrimary)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity)
                        .background(selection == tab ? Color.primaryBlue : Color.appBackground)
                        .cornerRadius(12)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityIdentifier("adminTab_\(tab.rawValue)")
                .accessibilityLabel(tab.rawValue)
                .accessibilityAddTraits(.isButton)
            }
        }
        .padding(6)
        .background(Color.cardBackground)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.border))
        .cornerRadius(14)
    }
}

struct StatusPill: View {
    let text: String
    let color: SwiftUI.Color
    let textColor: SwiftUI.Color
    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(textColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(color)
            .cornerRadius(10)
    }
}

struct IconTextRow: View {
    let systemName: String
    let text: String
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemName).foregroundColor(.textSecondary)
            Text(text).foregroundColor(.textSecondary).font(.system(size: 13))
        }
    }
}

struct SearchBar: View {
    @Binding var text: String
    var placeholder: String = "Search..."
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundColor(.textSecondary)
            TextField(placeholder, text: $text)
                .autocorrectionDisabled()
        }
        .padding(12)
        .background(Color.cardBackground)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.border))
        .cornerRadius(12)
    }
}




struct SimpleUmpireRow: View {
    let umpire: Umpire
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                    Text(umpire.name)
                        .font(.system(size: 16, weight: .semibold))
                
                Spacer()
                
                    StatusPill(
                        text: umpire.status.rawValue,
                        color: Color.primaryBlue.opacity(0.12),
                        textColor: .textPrimary
                    )

                Image(systemName: "chevron.right")
                    .foregroundColor(.textSecondary)
                
            }
            .padding(14)
            .background(Color.cardBackground)
            .cornerRadius(14)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("umpireRow")
    }
}


