import SwiftUI
import Combine
import AudioToolbox
import FirebaseFirestore
import FirebaseAuth


enum TimerContext: String, CaseIterable {
    case serve = "Serve Timer (25s)"
    case breakT = "Break Timer (90s)"
    case medical = "Medical Timeout (3min)"
    case warmup = "Warmup (5min)"
    
    // computed property for seconds per timer type
    var seconds: Int {
        switch self {
        case .serve: return 25
        case .breakT: return 90
        case .medical: return 180
        case .warmup: return 300
        }
    }
}

struct MatchScoringView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var voice: VoiceEngine

    let match: Match

    private let engine = TennisScoreEngine()

    // Score
    @State private var score = MatchScore.empty

    // Timer
    @State private var context: TimerContext = .serve
    @State private var remaining: Int = TimerContext.serve.seconds
    @State private var isRunning: Bool = false
    @State private var timerCancellable: AnyCancellable?

    // Event log
    @State private var events: [EventItem] = []

    // Manual override
    @State private var showOverride = false

    // Voice controller
    @State private var voiceController: MatchVoiceController? = nil

    @State private var matchStatus: MatchStatus

    @State private var showEndMatchConfirm = false
    @State private var matchStartTime: Date? = nil

    
    private enum Side { case p1, p2 }

    // MARK: - Helpers

    // time formatting
    private func now() -> String {
        let df = DateFormatter()
        df.dateFormat = "HH:mm"
        return df.string(from: Date())
    }

    // initializer
    init(match: Match) {
        self.match = match
        _matchStatus = State(initialValue: match.status) // initialize matchStatus with match.status but using _ (around the box not wahts inside)
    }

    // add event to screen + save to Firebase
    private func addEvent(_ e: EventItem) {
        withAnimation { events.append(e) }

        Task {
            try? await appState.saveMatchEvent(
                tournamentID: appState.selectedTournament!.id,
                matchID: match.id,
                event: e
            )
        }
    }
    // call this function when a point is given manual/voice.
    private func point(to side: Side) {
        let isP1 = (side == .p1)

      let result = engine.addPoint(
            toPlayer1: isP1,
            current: score,
        )


        score = result.score

        let winnerName = isP1 ? match.player1 : match.player2
        addEvent(
            EventItem(
                time: now(),
                type: "Point",
                description: "Point to \(winnerName) (\(score.player1Points)-\(score.player2Points))",
                color: .successGreen
            )
        )

        persistState() // saves state of score/timer/context

        if case .finished = result.completion {
            // dont end, show conf summary sheet first.
            showEndMatchConfirm = true
        }
    }

    // call this function when a game is given manual/voice.
    private func game(to side: Side) {
        let isP1 = (side == .p1)

        score = engine.forceGameWinner(
            isPlayer1: isP1,
            current: score
        )

        let winnerName = isP1 ? match.player1 : match.player2
        addEvent(
            EventItem(
                time: now(),
                type: "Game",
                description: "Game → \(winnerName)",
                color: .blue600
            )
        )

        persistState()
    }

    // call this function when a warning is given manual/voice.
    private func warn(_ side: Side) {
        if side == .p1 {
            score.player1Warnings = min(3, score.player1Warnings + 1) // add 1, never above 3
        } else {
            score.player2Warnings = min(3, score.player2Warnings + 1)
        }

        let warnedName = (side == .p1) ? match.player1 : match.player2

        addEvent(
            EventItem(
                time: now(),
                type: "Warning",
                description: "Time violation - \(warnedName)",
                color: .warningYellow
            )
        )
        persistState()
    }
    

    // MARK: - Body

    var body: some View {
        
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                // MARK: - Status Pill
                HStack {
                    Spacer()
                    switch matchStatus {
                    case .live:
                        StatusPill(
                            text: "Live",
                            color: Color.successGreen.opacity(0.15),
                            textColor: .successGreen
                        )

                    case .upcoming:
                        StatusPill(
                            text: "Upcoming",
                            color: Color.blue600.opacity(0.15),
                            textColor: .blue600
                        )

                    case .completed:
                        StatusPill(
                            text: "Completed",
                            color: Color.textSecondary.opacity(0.15),
                            textColor: .textSecondary
                        )
                    }
                }

                // MARK: - Header
                VStack(alignment: .leading, spacing: 6) {
                    
                    Text(matchStatus == .completed ? "Match Completed" : "Live Match")
                        .font(.system(size: 20, weight: .semibold))

                    Text(
                        "\(match.court) • \(appState.tournaments.first(where: { $0.id == appState.selectedTournament?.id })?.name ?? "Tournament")"
                    )
                    .font(.system(size: 12))
                    .foregroundColor(.textSecondary)
                }

                // MARK: - Scoreboard
                ScoreboardCard(
                    match: match,
                    score: $score,
                    context: $context,
                    remaining: $remaining,
                    isRunning: $isRunning,
                    startTimer: startTimer,
                    pauseTimer: pauseTimer,
                    resetTimer: resetTimer
                )
                .opacity(matchStatus == .completed ? 0.6 : 1)

                // MARK: - Voice Input (LIVE ONLY)
                if matchStatus == .live {
                    SectionCard(title: "Voice Input") {
                        MicButton(engine: voice)

                        Text(voice.liveCaption)
                            .font(.system(size: 12))
                            .foregroundColor(.textSecondary)
                            .lineLimit(2)

                        if let err = voice.errorMessage {
                            Text(err)
                                .foregroundColor(.errorRed)
                                .font(.system(size: 12))
                        }
                    }
                }

                // MARK: - Manual Controls (LIVE ONLY)
                if matchStatus == .live {
                    SectionCard(title: "Manual Controls") {
                        AppButton(
                            "Timer & Score Override",
                            variant: .primary,
                            icon: "pencil.and.outline",
                            isFullWidth: true
                        ) {
                            showOverride = true
                        }
                        .accessibilityIdentifier("manualOverrideButton")
                    }
                }

                // MARK: - Event Log (Always visible)
                SectionCard(title: "Event Log") {
                    VStack(spacing: 12) {
                        ForEach(events.reversed()) { event in
                            EventRow(event: event)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(16)
        }
        .background(Color.appBackground.ignoresSafeArea())

        // MARK: - Lifecycle
        .onDisappear {
            pauseTimer()
            voice.stop(auto: true) // stop voice when leaving screen auto.
        }

        // MARK: - Manual Override Sheet
        .sheet(isPresented: $showOverride) {
            ManualOverrideSheet(
                score: $score,
                context: $context,
                remaining: $remaining,
                addEvent: addEvent,
                engine: engine,
                onMatchFinished: {
                    showOverride = false
                    showEndMatchConfirm = true
                }
            )
            .presentationDetents([.medium, .large]) // user can drage to large if needed
            .presentationDragIndicator(.visible)
        }


        //  MARK: - End Match Summary Sheet
        .sheet(isPresented: $showEndMatchConfirm) {
            EndMatchConfirmSheet(
                summary: buildMatchSummary(),
                onConfirm: {
                    endMatch()
                    showEndMatchConfirm = false
                },
                onCancel: {
                    showEndMatchConfirm = false
                }
            )
            .presentationDetents([.medium])
        }

        // MARK: - Appear
        .onAppear {
            Task {
                await restoreMatchState() // load match data from Firestore

                if matchStatus == .live {
                    if matchStartTime == nil {
                        matchStartTime = Date()
                    }

                    voice.start()

                    voiceController = MatchVoiceController(
                        engine: voice,
                        match: match,
                        score: $score,
                        context: $context,
                        remaining: $remaining,
                        isPlayer1Serving: { score.isPlayer1Serving },
                        startTimer: startTimer,
                        pauseTimer: pauseTimer,
                        resetTimer: resetTimer,
                        addEvent: addEvent,
                        persistState: persistState
                    )
                }
            }
        }
        
    }

    private struct EndMatchConfirmSheet: View {
        let summary: MatchSummary
        let onConfirm: () -> Void
        let onCancel: () -> Void

        var body: some View {
            VStack(alignment: .leading, spacing: 16) {

                Text("Confirm End Match")
                    .font(.system(size: 18, weight: .semibold))

                VStack(alignment: .leading, spacing: 10) {
                    InfoRow(label: "Final Score", value: summary.finalScore)
                    InfoRow(label: "Duration", value: formatDuration(summary.durationSeconds))
                    InfoRow(label: "Warnings", value: "P1: \(summary.totalWarningsP1) • P2: \(summary.totalWarningsP2)")
                    InfoRow(label: "Tiebreaks Played", value: "\(summary.tiebreaksPlayed)")
                }
                .cardStyle()

                HStack(spacing: 12) {
                    AppButton("Cancel", variant: .ghost, isFullWidth: true) {
                        onCancel()
                    }

                    AppButton("End Match", variant: .destructive, isFullWidth: true) {
                        onConfirm()
                    }
                }
            }
            .padding(16)
            .background(Color.appBackground.ignoresSafeArea())
        }

        private func formatDuration(_ seconds: Int) -> String {
            let h = seconds / 3600
            let m = (seconds % 3600) / 60
            return h > 0 ? "\(h)h \(m)m" : "\(m)m"
        }
    }

    private func buildMatchSummary() -> MatchSummary {
        MatchSummary(
            finalScore: score.finalScoreString,
            durationSeconds: Int(Date().timeIntervalSince(matchStartTime ?? Date())),
            totalWarningsP1: score.player1Warnings,
            totalWarningsP2: score.player2Warnings,
            tiebreaksPlayed: events.filter { $0.type == "Tiebreak" }.count,
            endedAt: Date()
        )
    }


    // end the match: stop timers, voice, save final summary to Firestore
    private func endMatch() {
        pauseTimer()
        voice.stop(auto: true)  // stop voice when leaving screen auto.

        let summary = buildMatchSummary()

        Task {
            try? await appState.completeMatch(
                tournamentID: appState.selectedTournament!.id,
                matchID: match.id,
                summary: summary
            )
        }

        matchStatus = .completed
    }

    // saves the live matches current state to Firestore
    private func persistState() {
        Task {
            try? await appState.saveLiveMatchState(
                tournamentID: appState.selectedTournament!.id,
                matchID: match.id,
                score: score,
                context: context,
                remaining: remaining
            )
        }
    }

    // rebuild amtch as it was before app closed
    private func restoreMatchState() async {
        guard let tid = appState.selectedTournament?.id else { return }
        
        do {
            let doc = try await Firestore.firestore()
                .collection("tournaments")
                .document(tid)
                .collection("matches")
                .document(match.id)
                .getDocument()

            guard let data = doc.data() else { return }
            
            if let status = data["status"] as? String,
               let s = MatchStatus(rawValue: status) {
                matchStatus = s
            }

            if let s = data["scoreState"] as? [String: Any] {
                score.player1Sets = s["player1Sets"] as? Int ?? 0
                score.player2Sets = s["player2Sets"] as? Int ?? 0
                score.player1Games = s["player1Games"] as? Int ?? 0
                score.player2Games = s["player2Games"] as? Int ?? 0
                score.player1Points = s["player1Points"] as? String ?? "0"
                score.player2Points = s["player2Points"] as? String ?? "0"
                score.player1Warnings = s["player1Warnings"] as? Int ?? 0
                score.player2Warnings = s["player2Warnings"] as? Int ?? 0
                score.isPlayer1Serving = s["isPlayer1Serving"] as? Bool ?? true
                score.isTiebreak = s["isTiebreak"] as? Bool ?? false
            }

            // RESTORES TIMER STATE: Calculates time elapsed while app was closed
            // to keep the countdown synced with reality.

            if let t = data["timer"] as? [String: Any],
               let raw = t["context"] as? String,
               let ctx = TimerContext(rawValue: raw) {

                context = ctx

                let savedRemaining = t["remaining"] as? Int ?? ctx.seconds
                let lastUpdated = (t["lastUpdated"] as? Timestamp)?.dateValue()

                if let last = lastUpdated {
                    let elapsed = Int(Date().timeIntervalSince(last))
                    remaining = max(0, savedRemaining - elapsed)
                } else {
                    remaining = savedRemaining
                }

                isRunning = t["running"] as? Bool ?? false
                if isRunning && remaining > 0 {
                    startTimer()
                }
            }
        } catch {
            print("Restore failed:", error)
        }
    }

    // MARK: - Timer controls

    private func startTimer() {
        pauseTimer()
        isRunning = true
        timerCancellable = Timer
            .publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink {_ in
                if remaining > 0 {
                    remaining -= 1
                }

                if remaining == 0 {
                    pauseTimer()
                    playEndBeep()
                }
        }
    }

    private func pauseTimer() {
        isRunning = false
        timerCancellable?.cancel()
        timerCancellable = nil
    }

    private func resetTimer() {
        remaining = context.seconds
    }
    
    private func playEndBeep() {
        AudioServicesPlaySystemSound(SystemSoundID(1005))
    }

}

// MARK: - Subviews

private struct ScoreboardCard: View {
    @Environment(\.colorScheme) var scheme

    let match: Match
    @Binding var score: MatchScore

    @Binding var context: TimerContext
    @Binding var remaining: Int
    @Binding var isRunning: Bool

    var startTimer: () -> Void
    var pauseTimer: () -> Void
    var resetTimer: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            // Timer header
            VStack(spacing: 6) {
                Text(contextTitle)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.9))

                HStack(spacing: 16) {
                    Text(timeString)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(remaining <= 5 ? .errorRed : .white)

                    HStack(spacing: 16) {
                        Button(action: isRunning ? pauseTimer : startTimer) {
                            Image(systemName: isRunning ? "pause.fill" : "play.fill")
                                .foregroundColor(.white)
                        }
                        Button(action: resetTimer) {
                            Image(systemName: "gobackward")
                                .foregroundColor(.white)
                        }
                    }
                }
            }
            .padding(.top, 8)

            Divider().background(.white.opacity(0.3))

            // Player 1
            PlayerRow(
                initials: initials(match.player1),
                name: match.player1,
                servingText: score.isPlayer1Serving ? "Serving" : "Receiving",
                warnings: score.player1Warnings,
                sets: score.player1Sets,
                games: score.player1Games,
                points: score.player1Points
            )

            Divider().background(.white.opacity(0.3))

            // Player 2
            PlayerRow(
                initials: initials(match.player2),
                name: match.player2,
                servingText: score.isPlayer1Serving ? "Receiving" : "Serving",
                warnings: score.player2Warnings,
                sets: score.player2Sets,
                games: score.player2Games,
                points: score.player2Points
            )
        }
        .padding(16)
        .background(
            Group {
                if scheme == .dark {
                    LinearGradient(
                        colors: [
                            Color.primaryBlue.opacity(0.20),
                            Color.appBackground
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                } else {
                    Color.primaryBlue
                }
            }
        )
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 6, x: 0, y: 2)
    }

    // display timer according to context
    private var timeString: String {
        if context == .serve { return "\(remaining)s" }
        let minutes = remaining / 60
        let seconds = remaining % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private var contextTitle: String {
        switch context {
        case .serve: return "Serve Timer"
        case .breakT: return "Break Timer"
        case .medical: return "Medical Timeout"
        case .warmup: return "Warmup"
        }
    }

    // helper to get initials from name
    private func initials(_ name: String) -> String {
        let parts = name.split(separator: " ")
        let letters = parts.prefix(2).compactMap { $0.first }
        return String(letters).uppercased()
    }
}

private struct PlayerRow: View {
    let initials: String
    let name: String
    let servingText: String
    let warnings: Int
    let sets: Int
    let games: Int
    let points: String

    // NEW: detect serving inside the row
    var isServing: Bool { servingText == "Serving" }


    var body: some View {
        HStack(alignment: .center) {

            // Avatar
            Circle()
                .fill(isServing ? Color.green.opacity(0.25) : Color.cardBackground.opacity(0.2))
                .frame(width: 40, height: 40)
                .overlay(
                    Text(initials)
                        .foregroundColor(.white)
                        .font(.system(size: 14, weight: .bold))
                )
                .shadow(
                    color: isServing ? Color.green.opacity(0.7) : .clear,
                    radius: isServing ? 6 : 0
                )
                .animation(.easeInOut(duration: 0.25), value: isServing)
            VStack(alignment: .leading, spacing: 2) {
                Text(name.split(separator: " ").prefix(2).joined(separator: "\n"))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)
                    .allowsTightening(true)

                Text(servingText)
                    .foregroundColor(isServing ? .green : .white.opacity(0.6))
                    .font(.system(size: 12))
                    .fontWeight(isServing ? .bold : .regular)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)

                HStack(spacing: 4) {
                    ForEach(0..<3, id: \.self) { idx in
                        Circle()
                            .fill(idx < warnings ? Color.warningYellow : Color.cardBackground.opacity(0.3))
                            .frame(width: 6, height: 6)
                    }
                }
                .padding(.top, 2)
            }


            Spacer()

            // Score columns
            ScoreColumn(label: "Sets", value: "\(sets)")
            ScoreColumn(label: "Games", value: "\(games)")
            ScoreColumn(label: "Points", value: "\(points)")
        }
        .background(
            isServing
            ? Color.green.opacity(0.08)
            : Color.clear
        )
        .cornerRadius(10)
        .animation(.easeInOut(duration: 0.25), value: isServing)
    }
    
    private func splitName(_ name: String) -> (first: String, last: String?) {
        let parts = name.split(separator: " ", maxSplits: 1)
        let first = parts.first.map(String.init) ?? ""
        let last = parts.count > 1 ? String(parts[1]) : nil
        return (first, last)
    }

    


}


private struct ScoreColumn: View {
    let label: String
    let value: String

    var body: some View {
        VStack {
            Text(label)
                .foregroundColor(.white.opacity(0.9))
                .font(.system(size: 12))
            Text(value)
                .foregroundColor(.white)
                .font(.system(size: 32, weight: .semibold))
        }
        .frame(width: 72)
    }
}

private struct SectionCard<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
            content
        }
        .cardStyle()
    }
}

private struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 14))
                .foregroundColor(.textSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .semibold))
        }
        .padding(.vertical, 4)
    }
}

private struct EventRow: View {
    let event: EventItem

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(event.time)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.textSecondary)
                .frame(width: 48, alignment: .leading)
                .padding(.horizontal, 8) //NEWV5 ADDED PADDING FOR TIME AND DESCRIPTION
                .padding(.vertical, 4)

            Text(event.type)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(event.color.opacity(0.9))
                .cornerRadius(8)

            Text(event.description)
                .font(.system(size: 14))
                .foregroundColor(.textPrimary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)

            Spacer()
        }
        .padding(12)
        .background(Color.appBackground)
        .cornerRadius(12)
    }
}

// MARK: - Manual Override Sheet (UPDATED)

private struct ManualOverrideSheet: View {
    @Binding var score: MatchScore
    @Binding var context: TimerContext
    @Binding var remaining: Int
    var addEvent: (EventItem) -> Void

    let engine: TennisScoreEngine
    let onMatchFinished: () -> Void

    private enum Side { case p1, p2 }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {

                    Text("Timer Context")
                        .font(.system(size: 16, weight: .semibold))

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(TimerContext.allCases, id: \.self) { c in
                            Button {
                                context = c
                                remaining = c.seconds
                                addEvent(
                                    EventItem(
                                        time: now(),
                                        type: "Timer",
                                        description: "Switched to \(c.rawValue)",
                                        color: .blue600
                                    )
                                )
                            } label: {
                                Text(c.rawValue)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(context == c ? .white : .textPrimary)
                                    .frame(maxWidth: .infinity, minHeight: 44)
                                    .background(context == c ? Color.primaryBlue : Color.cardBackground)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.border)
                                    )
                                    .cornerRadius(12)
                            }
                        }
                    }

                    Text("Score Adjustments")
                        .font(.system(size: 16, weight: .semibold))

                    HStack(spacing: 12) {
                        AppButton(
                            "Point to player one",
                            variant: .primary,
                            isFullWidth: true
                        ) {
                            point(to: .p1)
                        }

                        AppButton(
                            "Point to player two",
                            variant: .primary,
                            isFullWidth: true
                        ) {
                            point(to: .p2)
                        }
                    }

                    HStack(spacing: 12) {
                        AppButton(
                            "Game to player one",
                            variant: .primary,
                            isFullWidth: true
                        ) {
                            game(to: .p1)
                        }

                        AppButton(
                            "Game to player two",
                            variant: .primary,
                            isFullWidth: true
                        ) {
                            game(to: .p2)
                        }
                    }

                    Text("Violations & Warnings")
                        .font(.system(size: 16, weight: .semibold))

                    HStack(spacing: 12) {
                        AppButton(
                            "Warning - player one",
                            variant: .primary,
                            isFullWidth: true
                        ) {
                            warn(.p1)
                        }

                        AppButton(
                            "Warning - player two",
                            variant: .primary,
                            isFullWidth: true
                        ) {
                            warn(.p2)
                        }
                    }
                    Divider()
                        .padding(.vertical, 8)

                    Text("Match Lifecycle")
                        .font(.system(size: 16, weight: .semibold))

                    AppButton(
                        "End Match",
                        variant: .destructive,
                        icon: "flag.checkered",
                        isFullWidth: true
                    ) {
                        onMatchFinished()
                    }
                }
                .padding(16)
            }
            .accessibilityIdentifier("matchScoringView")
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle("Manual Override")
            .accessibilityIdentifier("manualOverrideSheet")
        }
    }

    // MARK: - Manual scoring logic for OVERRIDE CARD (aligned with Voice dispatcher, updates points, games, sets, warnings, and date formats)

    private func point(to side: Side) {
        let isP1 = (side == .p1)

        let result = engine.addPoint(
            toPlayer1: isP1,
            current: score,
        )


        score = result.score

        let label = isP1 ? "player one" : "player two"
        addEvent(
            EventItem(
                time: now(),
                type: "Point",
                description: "Manual point → \(label)",
                color: .successGreen
            )
        )

        if case .finished = result.completion {
            onMatchFinished()
        }
  
    }




    private func game(to side: Side) {
        let isP1 = (side == .p1)

        score = engine.forceGameWinner(
            isPlayer1: isP1,
            current: score
        )

        let label = isP1 ? "player one" : "player two"
        addEvent(
            EventItem(
                time: now(),
                type: "Game",
                description: "Manual game → \(label)",
                color: .blue600
            )
        )
        
        if case .finished = engine.checkMatchCompletion(score: score) {
                onMatchFinished()
            }
    }



    private func warn(_ side: Side) {
        var s = score

        if side == .p1 {
            s.player1Warnings = min(3, s.player1Warnings + 1)
        } else {
            s.player2Warnings = min(3, s.player2Warnings + 1)
        }

        score = s

        let label = (side == .p1) ? "player one" : "player two"

        addEvent(
            EventItem(
                time: now(),
                type: "Warning",
                description: "Time violation - \(label)",
                color: .warningYellow
            )
        )
    }

    
    private func now() -> String {
        let df = DateFormatter()
        df.dateFormat = "HH:mm"
        return df.string(from: Date())
    }
}
