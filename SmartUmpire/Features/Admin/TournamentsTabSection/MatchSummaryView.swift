import SwiftUI


struct MatchSummaryView: View {
    @EnvironmentObject var appState: AppState
    @State private var showEventLog = false
    @State private var exportURL: URL?
    @State private var showShare = false

    let match: Match
    let tournament: Tournament

    var body: some View {
        VStack(spacing: 16) {
            
            ProTennisScoreboard(
                match: match,
                parsedSets: parsedSets.map { ($0.p1Games, $0.p2Games) }
            )
            
            infoRow(title: "Status", value: match.status.rawValue)
            infoRow(title: "Court", value: match.court)
            infoRow(title: "Round", value: match.round)
            infoRow(title: "Time", value: match.time)
            
            if match.status == .completed, let score = match.score, !score.isEmpty {
                infoRow(title: "Final Score", value: score)
            }
            
            assignedUmpireCard
            
            if match.status == .completed, let score = match.score, !score.isEmpty {
                Button {
                    showEventLog.toggle()
                } label: {
                    HStack {
                        Text("View Event Log")
                            .font(.system(size: 14, weight: .semibold))
                        Spacer()
                        Image(systemName: showEventLog ? "chevron.up" : "chevron.down")
                    }
                    .padding(14)
                    .background(Color.cardBackground)
                    .cornerRadius(14)
                }
            }
            
            
            
            
        }
        .onAppear {
            guard match.status == .completed else { return }
            
            if appState.eventsByMatch[match.id] == nil {
                Task {
                    await appState.loadEvents(
                        tournamentID: tournament.id,
                        matchID: match.id
                    )
                }
            }
        }
        
        .sheet(isPresented: $showEventLog) {
            NavigationStack {
                ScrollView {
                    eventLogSection
                        .padding()
                }
                .navigationTitle("Event Log")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            exportXLSX()
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                }
                .sheet(isPresented: $showShare) {
                    if let url = exportURL {
                        ShareSheet(items: [url])
                    }
                }
            }
        }
    }
    
    private func exportXLSX() {
        let meta = XLSXMatchReportWriter.Meta(
            tournamentName: tournament.name,
            court: match.court,
            round: match.round,
            umpireName: match.assignedUmpire ?? "Not assigned",
            player1: match.player1,
            player2: match.player2,
            status: match.status.rawValue,
            time: match.time,
            finalScore: (match.status == .completed ? match.score : nil),
            generatedAt: Date()
        )

        let logEvents: [XLSXMatchReportWriter.LogEvent] = events.map {
            XLSXMatchReportWriter.LogEvent(
                time: $0.createdAt,              // make sure EventItem.createdAt is Date
                type: $0.type,
                description: $0.description
            )
        }

        do {
            exportURL = try XLSXMatchReportWriter.writeReport(meta: meta, events: logEvents)
            showShare = true
        } catch {
            print("XLSX export failed:", error)
        }
    }

    
    private var events: [EventItem] {
        appState.eventsByMatch[match.id] ?? []
    }

    func eventRow(_ event: EventItem) -> some View {
        HStack(alignment: .top, spacing: 12) {

            Text(event.createdAt, style: .time)
                .font(.system(size: 11))
                .foregroundColor(.textSecondary)
                .frame(width: 50, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                Text(event.type)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.primaryBlue)

                Text(event.description)
                    .font(.system(size: 14))
                    .foregroundColor(.textPrimary)
            }

            Spacer()
        }
    }
    
    var eventLogSection: some View {
        VStack(alignment: .leading, spacing: 12) {

            Text("Event Log")
                .font(.system(size: 16, weight: .semibold))

            if events.isEmpty {
                Text("No events were logged for this match.")
                    .foregroundColor(.textSecondary)
            } else {
                ForEach(events) { event in
                    eventRow(event)
                }
            }
        }
        .padding(16)
        .background(Color.cardBackground)
        .cornerRadius(18)
    }
}




// MARK: - Scoreboard
private extension MatchSummaryView {

    struct ParsedSet {
        let p1Games: Int
        let p2Games: Int
    }

    var parsedSets: [ParsedSet] {
        guard let score = match.score, !score.isEmpty else { return [] }

        let cleaned = score.replacingOccurrences(of: ",", with: " ")
        let tokens = cleaned.split(separator: " ")

        return tokens.compactMap { token in
            let parts = token.split(separator: "-")
            guard
                parts.count == 2,
                let p1 = Int(parts[0]),
                let p2 = Int(parts[1])
            else { return nil }

            return ParsedSet(p1Games: p1, p2Games: p2)
        }
    }
    

    func infoRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .foregroundColor(.textSecondary)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
        }
        .padding(14)
        .background(Color.cardBackground)
        .cornerRadius(14)
    }

    var assignedUmpireCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Assigned Umpire")
                .font(.system(size: 16, weight: .semibold))

            if let name = match.assignedUmpire, !name.isEmpty {
                line(label: "Name", value: name)

                if let email = match.assignedUmpireEmail, !email.isEmpty {
                    line(label: "Email", value: email)
                }
            } else {
                HStack {
                    Text("Not assigned")
                        .foregroundColor(.errorRed)
                    Spacer()
                }
            }
        }
        .padding(16)
        .background(Color.cardBackground)
        .cornerRadius(18)
    }

    func line(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundColor(.textSecondary)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
        }
    }
}


struct ProTennisScoreboard: View {
    let match: Match
    let parsedSets: [(p1: Int, p2: Int)]

    private var matchStarted: Bool {
        match.status != .upcoming
    }

    private var p1SetsWon: Int {
        parsedSets.filter { $0.p1 > $0.p2 }.count
    }

    private var p2SetsWon: Int {
        parsedSets.filter { $0.p2 > $0.p1 }.count
    }

    var body: some View {
        VStack(spacing: 12) {

            playerRow(
                name: match.player1,
                setsWon: p1SetsWon,
                games: parsedSets,
                isWinner: match.status == .completed && p1SetsWon > p2SetsWon,
                isPlayer1: true
            )

            Divider().opacity(0.4)

            playerRow(
                name: match.player2,
                setsWon: p2SetsWon,
                games: parsedSets,
                isWinner: match.status == .completed && p2SetsWon > p1SetsWon,
                isPlayer1: false
            )
        }
        .padding(16)
        .background(Color.cardBackground)
        .cornerRadius(18)
    }

    // MARK: - Player Row

    private func playerRow(
        name: String,
        setsWon: Int,
        games: [(p1: Int, p2: Int)],
        isWinner: Bool,
        isPlayer1: Bool
    ) -> some View {
        HStack {

            // Player name + winner badge
            HStack(spacing: 8) {
                Text(name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(isWinner ? .primaryBlue : .textPrimary)

                if isWinner {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.primaryBlue)
                        .font(.system(size: 14))
                }
            }
            .frame(width: 170, alignment: .leading)

            Spacer()

            // Sets won (bigger)
            Text("\(setsWon)")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(isWinner ? .primaryBlue : .textPrimary)
                .frame(width: 28)

            // Separator
            Text("|")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.textSecondary)
                .padding(.horizontal, 6)

            // Games per set OR placeholders
            HStack(spacing: 18) {
                if matchStarted {
                    ForEach(games.indices, id: \.self) { i in
                        let p1 = games[i].p1
                        let p2 = games[i].p2
                        let value = isPlayer1 ? p1 : p2
                        let isSetWinner = isPlayer1 ? p1 > p2 : p2 > p1

                        Text("\(value)")
                            .font(.system(
                                size: 18,
                                weight: isSetWinner ? .bold : .regular
                            ))
                            .foregroundColor(
                                isSetWinner ? .textPrimary : .textSecondary
                            )
                            .frame(width: 22)
                    }
                } else {
                    // Placeholders before match starts
                    ForEach(0..<max(3, games.isEmpty ? 3 : games.count), id: \.self) { _ in
                        Text("–")
                            .font(.system(size: 18))
                            .foregroundColor(.textSecondary)
                            .frame(width: 22)
                    }
                }
            }
        }
        .frame(height: 34)
    }
}



