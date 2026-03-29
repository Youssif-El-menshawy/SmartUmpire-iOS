//
//  VoiceIntentDispatcher.swift
//  SmartUmpire
//

import Foundation
import SwiftUI

/// Takes high-level VoiceIntent commands and applies them to the live match.
/// V5 strict mode: no voice overrides, strict point progression, auto-game, auto-set.
final class VoiceIntentDispatcher {
    
    // MARK: - Dependencies
    
    private let match: Match
    private let score: Binding<MatchScore>
    private let context: Binding<TimerContext>
    private let remaining: Binding<Int>
    
    private let isPlayer1Serving: () -> Bool
    
    private let startTimer: () -> Void
    private let pauseTimer: () -> Void
    private let resetTimer: () -> Void
    private let addEvent: (EventItem) -> Void
    
    init(
        match: Match,
        score: Binding<MatchScore>,
        context: Binding<TimerContext>,
        remaining: Binding<Int>,
        isPlayer1Serving: @escaping () -> Bool,
        startTimer: @escaping () -> Void,
        pauseTimer: @escaping () -> Void,
        resetTimer: @escaping () -> Void,
        addEvent: @escaping (EventItem) -> Void
    ) {
        self.match = match
        self.score = score
        self.context = context
        self.remaining = remaining
        self.isPlayer1Serving = isPlayer1Serving
        self.startTimer = startTimer
        self.pauseTimer = pauseTimer
        self.resetTimer = resetTimer
        self.addEvent = addEvent
    }
    
    // MARK: - PUBLIC API
    
    func handle(_ intent: VoiceIntent) {
        switch intent {
            
            // TIMERS
        case .timerStart:
            startTimer()
            addEvent(timerEvent("Timer started"))
            
        case .timerPause:
            pauseTimer()
            addEvent(timerEvent("Timer paused"))
            
        case .timerReset:
            resetTimer()
            addEvent(timerEvent("Timer reset"))
            
        case .timerContext(let c):
            context.wrappedValue = c
            remaining.wrappedValue = c.seconds
            startTimer()
            
            // More specific event descriptions based on context
            let eventDescription: String
            switch c {
            case .medical:
                eventDescription = "Medical timeout started (3min)"
            case .warmup:
                eventDescription = "Warmup period started (5min)"
            case .breakT:
                eventDescription = "Break timer started (90s)"
            case .serve:
                eventDescription = "Serve timer started (25s)"
            }
            
            addEvent(EventItem(
                time: now(),
                type: "Timer",
                description: eventDescription,
                color: .blue600
            ))
            
            // SET SERVER
        case .setServer(let playerRef):
            applyServerChange(playerRef)
            
            // POINT (strict)
        case .point(let playerRef):
            applyPoint(playerRef)
            
      //SPOKEN SCORE
        case .scoreSpoken(let s, let r):
            applySpokenScore(serverScore: s, receiverScore: r)

            // GAME (explicit - but system auto-detects winner)
        case .game(_):
            applyGameFromVoice()
            
            // NEW: ADVANTAGE
        case .advantage(let playerRef):
            applyAdvantage(playerRef)
            
            // NEW: SCORE ALL (15 all, 30 all, 40 all)
        case .scoreAll(let score):
            applyScoreAll(score)
            
            // SANCTIONS
        case .warning(let p):
            applyWarning(p)
            
        case .violation(let p, let reason):
            applyViolation(p, reason: reason)
            
        case .undoLast:
            addEvent(EventItem(
                time: now(),
                type: "Undo",
                description: "Undo not yet implemented in V5",
                color: .warningYellow
            ))
        }
    }
    
    // MARK: - POINT LOGIC (STRICT V5)
    
    
    
    private func applySpokenScore(serverScore s: String, receiverScore r: String) {
        var sc = score.wrappedValue
        let isP1Server = isPlayer1Serving()

        // --- TIEBREAK-ONLY GLUED NUMBER SPLITTING ---
        func splitIfTiebreak(_ token: String) -> [String] {
            if !sc.isTiebreak { return [token] }

            if token.allSatisfy({ $0.isNumber }) {
                let chars = Array(token)

                if chars.count == 2 {
                    return [String(chars[0]), String(chars[1])]
                }

                if chars.count == 3 {
                    let first = String(chars[0...1])
                    let second = String(chars[2])
                    return [first, second]
                }
            }

            return [token]
        }

        // Apply splitting to the provided server-first spoken scores
        let expandedS = splitIfTiebreak(s)
        let expandedR = splitIfTiebreak(r)

        var sFixed = s
        var rFixed = r

        if expandedS.count == 2 {
            sFixed = expandedS[0]
            rFixed = expandedS[1]
        } else if expandedR.count == 2 {
            sFixed = expandedR[0]
            rFixed = expandedR[1]
        }

        // --- If we are in a tiebreak, do strict numeric progression ---
        if sc.isTiebreak {
            applyTiebreakSpokenScore(
                serverScore: sFixed,
                receiverScore: rFixed,
                isP1Server: isP1Server
            )
            return
        }

        // --- NORMAL GAME LOGIC (0,15,30,40,Ad) ---

        let currentP1 = sc.player1Points
        let currentP2 = sc.player2Points

        // spoken server-first → map to (P1, P2)
        let spokenP1: String
        let spokenP2: String

        if isP1Server {
            spokenP1 = sFixed
            spokenP2 = rFixed
        } else {
            spokenP1 = rFixed
            spokenP2 = sFixed
        }

        // CASE 1 — no change (umpire repeated score)
        if spokenP1 == currentP1 && spokenP2 == currentP2 {
            restartServeTimer()
            return
        }

        // CASE 2 — P1 advances by one legal step
        if let next = nextPointStrict(a: currentP1, b: currentP2),
           next.pA == spokenP1 && next.pB == spokenP2 {

            if next.gameWon {
                applyGame(winner: true)
            } else {
                sc.player1Points = next.pA
                sc.player2Points = next.pB
                score.wrappedValue = sc
                
                // Add event for score change
                addEvent(EventItem(
                    time: now(),
                    type: "Point",
                    description: "Point → \(match.player1) (\(next.pA)-\(next.pB))",
                    color: .successGreen
                ))
            }

            restartServeTimer()
            return
        }

        // CASE 3 — P2 advances by one legal step
        if let next = nextPointStrict(a: currentP2, b: currentP1),
           next.pA == spokenP2 && next.pB == spokenP1 {

            if next.gameWon {
                applyGame(winner: false)
            } else {
                sc.player2Points = next.pA
                sc.player1Points = next.pB
                score.wrappedValue = sc
                
                // Add event for score change
                addEvent(EventItem(
                    time: now(),
                    type: "Point",
                    description: "Point → \(match.player2) (\(next.pB)-\(next.pA))",
                    color: .successGreen
                ))
            }

            restartServeTimer()
            return
        }

        // If nothing matched, throw an error
        addEvent(EventItem(
            time: now(),
            type: "Error",
            description: "Illegal spoken score \(sFixed)-\(rFixed)",
            color: .errorRed
        ))

        restartServeTimer()
    }



    
    private func applyPoint(_ ref: PlayerRef) {
        var s = score.wrappedValue
        let isP1 = resolvePlayer(ref)
        
        // Check if in tiebreak
        if s.isTiebreak {
            applyTiebreakPoint(isP1)
            return
        }
        
        // Normal game scoring
        let currentA = isP1 ? s.player1Points : s.player2Points
        let currentB = isP1 ? s.player2Points : s.player1Points
        
        // Strict progression validation
        guard let next = nextPointStrict(a: currentA, b: currentB) else {
            addEvent(EventItem(
                time: now(),
                type: "Error",
                description: "Illegal point progression from \(currentA)-\(currentB)",
                color: .errorRed
            ))
            return
        }
        
        // Check if game is won
        if next.gameWon {
            applyGame(winner: isP1)
            return
        }
        
        // Normal point - update score
        if isP1 {
            s.player1Points = next.pA
            s.player2Points = next.pB
        } else {
            s.player2Points = next.pA
            s.player1Points = next.pB
        }
        
        score.wrappedValue = s
        
        addEvent(EventItem(
            time: now(),
            type: "Point",
            description: "Point → \(isP1 ? match.player1 : match.player2) (\(s.player1Points)-\(s.player2Points))",
            color: .successGreen
        ))
        
        // Restart serve timer after every point
        context.wrappedValue = .serve
        remaining.wrappedValue = TimerContext.serve.seconds
        startTimer()
    }
    
    // MARK: - ADVANTAGE LOGIC (NEW)
    
    private func applyAdvantage(_ ref: PlayerRef) {
        var s = score.wrappedValue
        let isP1 = resolvePlayer(ref)
        
        // Can only call advantage from deuce (40-40)
        guard s.player1Points == "40" && s.player2Points == "40" else {
            addEvent(EventItem(
                time: now(),
                type: "Error",
                description: "Can only call advantage from deuce (40-40)",
                color: .errorRed
            ))
            return
        }
        
        // Set advantage
        if isP1 {
            s.player1Points = "Ad"
            s.player2Points = "40"
        } else {
            s.player2Points = "Ad"
            s.player1Points = "40"
        }
        
        score.wrappedValue = s
        
        addEvent(EventItem(
            time: now(),
            type: "Point",
            description: "Advantage → \(isP1 ? match.player1 : match.player2)",
            color: .successGreen
        ))
        
        // Restart serve timer
        context.wrappedValue = .serve
        remaining.wrappedValue = TimerContext.serve.seconds
        startTimer()
    }
    
    // MARK: - SCORE ALL LOGIC (NEW)
    
    private func applyScoreAll(_ target: String) {
        var s = score.wrappedValue

        let curP1 = s.player1Points
        let curP2 = s.player2Points

        var isLegal = false

        // Can P1 reach target-target by winning ONE point?
        if let next = nextPointStrict(a: curP1, b: curP2),
           next.pA == target && next.pB == target {
            isLegal = true
        }

        // Can P2 reach target-target by winning ONE point?
        if let next = nextPointStrict(a: curP2, b: curP1),
           next.pA == target && next.pB == target {
            isLegal = true
        }

        //  Illegal "all" call
        guard isLegal else {
            addEvent(EventItem(
                time: now(),
                type: "Error",
                description: "Illegal score call \(target) all from \(curP1)-\(curP2)",
                color: .errorRed
            ))
            restartServeTimer()
            return
        }

        // Legal → apply
        s.player1Points = target
        s.player2Points = target
        score.wrappedValue = s

        let description = target == "40" ? "Deuce (40-40)" : "\(target) all"

        addEvent(EventItem(
            time: now(),
            type: "Score",
            description: description,
            color: .primaryBlue
        ))

        restartServeTimer()
    }

    
    // MARK: - TIEBREAK POINT LOGIC
    
    private func applyTiebreakPoint(_ isP1: Bool) {
        var s = score.wrappedValue
        
        let p1 = Int(s.player1Points) ?? 0
        let p2 = Int(s.player2Points) ?? 0
        
        let newP1 = isP1 ? p1 + 1 : p1
        let newP2 = isP1 ? p2 : p2 + 1
        
        s.player1Points = String(newP1)
        s.player2Points = String(newP2)
        
        // Check tiebreak win (first to 7, win by 2)
        let lead1 = newP1 - newP2
        let lead2 = newP2 - newP1
        
        if (newP1 >= 7 && lead1 >= 2) {
            s.player1Sets += 1
            resetSet(&s)
            score.wrappedValue = s
            
            addEvent(EventItem(
                time: now(),
                type: "Set",
                description: "Tiebreak won by \(match.player1) - Set score: \(s.player1Sets)-\(s.player2Sets)",
                color: .purple
            ))
            
            context.wrappedValue = .warmup
            remaining.wrappedValue = TimerContext.warmup.seconds
            startTimer()
            return
        }
        
        if (newP2 >= 7 && lead2 >= 2) {
            s.player2Sets += 1
            resetSet(&s)
            score.wrappedValue = s
            
            addEvent(EventItem(
                time: now(),
                type: "Set",
                description: "Tiebreak won by \(match.player2) - Set score: \(s.player1Sets)-\(s.player2Sets)",
                color: .purple
            ))
            
            context.wrappedValue = .warmup
            remaining.wrappedValue = TimerContext.warmup.seconds
            startTimer()
            return
        }
        
        // Continue tiebreak
        score.wrappedValue = s
        
        addEvent(EventItem(
            time: now(),
            type: "Point",
            description: "Tiebreak point → \(isP1 ? match.player1 : match.player2) (\(newP1)-\(newP2))",
            color: .successGreen
        ))
        
        context.wrappedValue = .serve
        remaining.wrappedValue = TimerContext.serve.seconds
        startTimer()
    }
    
    // MARK: - STRICT POINT TABLE (V5)
    
    private func nextPointStrict(a: String, b: String) -> (pA: String, pB: String, gameWon: Bool)? {
        
        // Normal progression: 0 → 15 → 30 → 40
        if a == "0" { return ("15", b, false) }
        if a == "15" { return ("30", b, false) }
        if a == "30" { return ("40", b, false) }
        
        // Deuce → Advantage
        if a == "40" && b == "40" { return ("Ad", "40", false) }
        
        // Advantage → Game Won
        if a == "Ad" { return (a, b, true) }
        
        // 40 vs <40 → Game Won
        if a == "40", ["0","15","30"].contains(b) {
            return (a, b, true)
        }
        
        // Opponent had advantage → Back to deuce
        if a == "40" && b == "Ad" {
            return ("40", "40", false)
        }
        
        return nil
    }
    
    // MARK: - GAME LOGIC (AUTO + EXPLICIT)
    private func applyGame(winner: Bool) {
        var s = score.wrappedValue

        if winner {
            s.player1Games += 1
        } else {
            s.player2Games += 1
        }

        s.player1Points = "0"
        s.player2Points = "0"

        // 🔴 NEW: toggle server for next game (outside tiebreak)
        if !s.isTiebreak {
            s.isPlayer1Serving.toggle()
        }

        score.wrappedValue = s

        let winnerName = winner ? match.player1 : match.player2
        addEvent(EventItem(
            time: now(),
            type: "Game",
            description: "Game → \(winnerName) (Games: \(s.player1Games)-\(s.player2Games))",
            color: .blue600
        ))

        // Check for set / tiebreak transitions
        autoCheckSet()

        let totalGames = s.player1Games + s.player2Games

        if totalGames == 1 {
            context.wrappedValue = .serve
            remaining.wrappedValue = TimerContext.serve.seconds
            startTimer()
            return
        }

        if totalGames % 2 == 1 {
            context.wrappedValue = .breakT
            remaining.wrappedValue = TimerContext.breakT.seconds
            startTimer()
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
                self.context.wrappedValue = .serve
                self.remaining.wrappedValue = TimerContext.serve.seconds
                self.startTimer()
            }
        }
    }

    
    private func applyGameFromVoice() {
        let s = score.wrappedValue
        
        let p1Points = s.player1Points
        let p2Points = s.player2Points
        
        // 1) Check if a game is even possible at this score
        guard isGamePossible(s) else {
            addEvent(EventItem(
                time: now(),
                type: "Error",
                description: "Illegal game call at score \(p1Points)-\(p2Points)",
                color: .errorRed
            ))
            return
        }
        
        // 2) Decide winner based ONLY on the scoreboard, not on the words
        let p1Wins =
            (p1Points == "Ad") ||
            (p1Points == "40" && ["0","15","30"].contains(p2Points))
            // if neither of these, then P2 must be the winner
        
        applyGame(winner: p1Wins)
    }

    
    // MARK: - AUTO SET LOGIC (V5)
    
    private func autoCheckSet() {
        var s = score.wrappedValue
        
        let g1 = s.player1Games
        let g2 = s.player2Games
        
        if g1 == 6 && g2 == 6 && !s.isTiebreak {
            s.isTiebreak = true
            s.player1Points = "0"
            s.player2Points = "0"
            score.wrappedValue = s
            
            addEvent(EventItem(
                time: now(),
                type: "Tiebreak",
                description: "Tiebreak started at 6-6",
                color: .purple
            ))
            
            context.wrappedValue = .serve
            remaining.wrappedValue = TimerContext.serve.seconds
            startTimer()
            return
        }
        
        if (g1 == 6 && g2 <= 4) || (g1 == 7 && (g2 == 5 || g2 == 6)) {
            s.player1Sets += 1
            resetSet(&s)
            score.wrappedValue = s
            addEvent(EventItem(
                time: now(),
                type: "Set",
                description: "Set → \(match.player1) - Sets: \(s.player1Sets)-\(s.player2Sets)",
                color: .purple
            ))
            context.wrappedValue = .warmup
            remaining.wrappedValue = TimerContext.warmup.seconds
            startTimer()
            return
        }
        
        if (g2 == 6 && g1 <= 4) || (g2 == 7 && (g1 == 5 || g1 == 6)) {
            s.player2Sets += 1
            resetSet(&s)
            score.wrappedValue = s
            addEvent(EventItem(
                time: now(),
                type: "Set",
                description: "Set → \(match.player2) - Sets: \(s.player1Sets)-\(s.player2Sets)",
                color: .purple
            ))
            context.wrappedValue = .warmup
            remaining.wrappedValue = TimerContext.warmup.seconds
            startTimer()
            return
        }
    }
    
    
    // MARK: - TIEBREAK SPOKEN SCORE HELPER

    // MARK: - TIEBREAK SPOKEN SCORE (STRICT +1)

    private func applyTiebreakSpokenScore(serverScore s: String,
                                          receiverScore r: String,
                                          isP1Server: Bool) {
        var sc = score.wrappedValue

        // current numeric tiebreak score
        let curP1 = Int(sc.player1Points) ?? 0
        let curP2 = Int(sc.player2Points) ?? 0

        // spoken numeric score (server, receiver)
        guard let spokenServer = Int(s), let spokenReceiver = Int(r) else {
            addEvent(EventItem(
                time: now(),
                type: "Error",
                description: "Illegal tiebreak spoken score (non-numeric) \(s)-\(r)",
                color: .errorRed
            ))
            restartServeTimer()
            return
        }

        // Map spoken server/receiver → P1/P2
        let spokenP1: Int
        let spokenP2: Int
        if isP1Server {
            spokenP1 = spokenServer
            spokenP2 = spokenReceiver
        } else {
            spokenP1 = spokenReceiver
            spokenP2 = spokenServer
        }

        // CASE 1 — No change
        if spokenP1 == curP1 && spokenP2 == curP2 {
            restartServeTimer()
            return
        }

        // Determine which player (if any) advanced by exactly +1
        var winnerIsP1: Bool?

        // P1 advanced by +1
        if spokenP1 == curP1 + 1 && spokenP2 == curP2 {
            winnerIsP1 = true
        }

        // P2 advanced by +1
        if spokenP2 == curP2 + 1 && spokenP1 == curP1 {
            winnerIsP1 = false
        }

        guard let isP1 = winnerIsP1 else {
            addEvent(EventItem(
                time: now(),
                type: "Error",
                description: "Illegal tiebreak spoken jump \(spokenP1)-\(spokenP2) from \(curP1)-\(curP2)",
                color: .errorRed
            ))
            restartServeTimer()
            return
        }

        // Delegate to the core tiebreak engine (handles +1, win-by-2, set, timers)
        applyTiebreakPoint(isP1)
        // applyTiebreakPoint already logs + restarts timers, so no restartServeTimer() here.
    }

    
    
    private func resetSet(_ s: inout MatchScore) {
        s.player1Games = 0
        s.player2Games = 0
        s.player1Points = "0"
        s.player2Points = "0"
        s.isTiebreak = false
    }
    
    // MARK: - SERVER CONTROL
    
    private func applyServerChange(_ ref: PlayerRef) {
        let isP1 = resolvePlayer(ref)
        score.wrappedValue.isPlayer1Serving = isP1
        
        addEvent(EventItem(
            time: now(),
            type: "Server",
            description: "Server → \(isP1 ? match.player1 : match.player2)",
            color: .primaryBlue
        ))
    }
    
    // MARK: - SANCTIONS
    
    private func applyWarning(_ ref: PlayerRef) {
        let isP1 = resolvePlayer(ref)
        
        var s = score.wrappedValue
        
        if isP1 {
            s.player1Warnings = min(3, s.player1Warnings + 1)
        } else {
            s.player2Warnings = min(3, s.player2Warnings + 1)
        }
        
        score.wrappedValue = s
        
        addEvent(EventItem(
            time: now(),
            type: "Warning",
            description: "Warning → \(isP1 ? match.player1 : match.player2)",
            color: .warningYellow
        ))
    }
    
    private func applyViolation(_ ref: PlayerRef, reason: String?) {
        let isP1 = resolvePlayer(ref)
        let name = isP1 ? match.player1 : match.player2
        var desc = "Violation → \(name)"
        if let r = reason, !r.isEmpty { desc += " (\(r))" }
        
        addEvent(EventItem(
            time: now(),
            type: "Violation",
            description: desc,
            color: .errorRed
        ))
    }
    
    // MARK: - HELPERS
    
    //helper- restart serve timer
    private func restartServeTimer() {
        context.wrappedValue = .serve
        remaining.wrappedValue = TimerContext.serve.seconds
        startTimer()
    }

    //is game possible helper
    private func isGamePossible(_ s: MatchScore) -> Bool {
        let p1 = s.player1Points
        let p2 = s.player2Points
        
        // Valid game-winning states:
        // - Advantage for either player
        if p1 == "Ad" && p2 == "40" { return true }
        if p2 == "Ad" && p1 == "40" { return true }
        
        // - 40 vs <40
        if p1 == "40" && ["0", "15", "30"].contains(p2) { return true }
        if p2 == "40" && ["0", "15", "30"].contains(p1) { return true }
        
        return false
    }

    private func resolvePlayer(_ ref: PlayerRef) -> Bool {
        switch ref {
        case .player1: return true
        case .player2: return false
        case .name(let n):
            let cleaned = n.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let p1 = match.player1.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let p2 = match.player2.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            
            if cleaned == p1 { return true }
            if cleaned == p2 { return false }
            return true
            
        case .role(let role):
            switch role {
            case .server: return isPlayer1Serving()
            case .receiver: return !isPlayer1Serving()
            }
        }
    }
    
    private func timerEvent(_ description: String) -> EventItem {
        EventItem(
            time: now(),
            type: "Timer",
            description: description,
            color: .blue600
        )
    }
    
    private func now() -> String {
        let df = DateFormatter()
        df.dateFormat = "HH:mm"
        return df.string(from: Date())
    }
}
