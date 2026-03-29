//
//  VoiceIntentParser.swift
//  SmartUmpire
//

import Foundation

/// Converts normalized text into high-level VoiceIntent commands.
/// Pure rules-based system (fast & predictable).
final class VoiceIntentParser {

    // MARK: - MAIN ENTRY

    func parse(
        _ raw: String,
        match: Match,
        isPlayer1Serving: Bool
    ) -> [VoiceIntent] {

        let text = normalize(raw)
        let lowerRaw = raw.lowercased()

        // UNDO
        if let undo = detectUndo(raw: lowerRaw, text: text) {
            return [undo]
        }

        // SET SERVER (includes return logic)
        if let serverIntent = detectSetServer(raw: lowerRaw, match: match) {
            return [serverIntent]
        }

        // NEW: ADVANTAGE commands
        if let advIntent = detectAdvantage(raw: lowerRaw, match: match) {
            return [advIntent]
        }

        // NEW: "ALL" logic (15 all, 30 all, 40 all)
        if let allIntent = detectAllScore(raw: lowerRaw) {
            return [allIntent]
        }
        
        if containsDeuce(lowerRaw) {
            return [.scoreAll(score: "40")]
        }
        
        if let spoken = detectSpokenScore(text) {
            return [spoken]
        }
        
        

        // TIMER COMMANDS
        if let timerIntent = detectTimerCommand(text) {
            return [timerIntent]
        }

        // SCORING – INCREMENTAL ONLY (V5 strict)
        if let scoringIntent = detectScoringCommand(text, match: match, isPlayer1Serving: isPlayer1Serving) {
            return [scoringIntent]
        }

        // SANCTIONS
        if let sanctionIntent = detectSanction(text, match: match) {
            return [sanctionIntent]
        }

        return []
    }

    // MARK: - UNDO

    private func detectUndo(raw: String, text: String) -> VoiceIntent? {
        let t = raw
        if t.contains("undo") ||
            t.contains("correction") {
            return .undoLast
        }
        return nil
    }

    // MARK: - SET SERVER + RETURN LOGIC

    private func detectSetServer(raw: String, match: Match) -> VoiceIntent? {
        let t = raw

        let hasServe = t.contains("serve") || t.contains("serving")
        let hasReturn = t.contains("return") || t.contains("receiving") || t.contains("receive")

        let p1 = match.player1.lowercased()
        let p2 = match.player2.lowercased()

        // SERVE
        if hasServe {
            if t.contains("player one") || t.contains("player 1") {
                return .setServer(.player1)
            }
            if t.contains("player two") || t.contains("player 2") {
                return .setServer(.player2)
            }
            if t.contains(p1) { return .setServer(.player1) }
            if t.contains(p2) { return .setServer(.player2) }
        }

        // RETURN (flip server)
        if hasReturn {
            if t.contains("player one") || t.contains("player 1") {
                return .setServer(.player2)  // Flip: P1 returns = P2 serves
            }
            if t.contains("player two") || t.contains("player 2") {
                return .setServer(.player1)  // Flip: P2 returns = P1 serves
            }
            if t.contains(p1) { return .setServer(.player2) }
            if t.contains(p2) { return .setServer(.player1) }
        }

        return nil
    }

    // MARK: - ADVANTAGE DETECTION (NEW)

    private func detectAdvantage(raw: String, match: Match) -> VoiceIntent? {
        let t = raw
        
        // Must contain "advantage" or "ad"
        guard t.contains("advantage") || t.contains(" ad ") || t.starts(with: "ad ") else {
            return nil
        }
        
        let p1 = match.player1.lowercased()
        let p2 = match.player2.lowercased()
        
        // Check for player references
        if t.contains("player one") || t.contains("player 1") {
            return .advantage(player: .player1)
        }
        if t.contains("player two") || t.contains("player 2") {
            return .advantage(player: .player2)
        }
        
        // Check for names
        if t.contains(p1) {
            return .advantage(player: .player1)
        }
        if t.contains(p2) {
            return .advantage(player: .player2)
        }
        
        // Check for server/receiver
        if t.contains("server") {
            return .advantage(player: .role(.server))
        }

        if t.contains("receiver") {
            return .advantage(player: .role(.receiver))
        }
        
        return nil
    }

    // MARK: - "ALL" SCORE DETECTION (NEW)

    private func detectAllScore(raw: String) -> VoiceIntent? {
        let t = raw
        
        // Must contain "all"
        guard t.contains(" all") else {
            return nil
        }
        
        // Check for specific scores
        if t.contains("fifteen all") || t.contains("15 all") || t.contains("50 all") {
            return .scoreAll(score: "15")
        }
        
        if t.contains("thirty all") || t.contains("30 all") {
            return .scoreAll(score: "30")
        }

        return nil
    }
    
    
    
    // MARK: - DEUCE DETECTION (separate from "all")

    private func containsDeuce(_ raw: String) -> Bool {
        let t = raw.lowercased()
        return t.contains("deuce") ||
               t.contains("juice") ||
               t.contains("jews") ||
               t.contains("dews") ||
               t.contains("duce")
    }


    // MARK: - TIMER DETECTION

    private func detectTimerCommand(_ text: String) -> VoiceIntent? {

        if text.contains("start timer") || text == "start" {
            return .timerStart
        }

        if text.contains("pause timer") || text == "pause" || text.contains("stop timer") {
            return .timerPause
        }

        if text.contains("reset timer") || text.contains("restart timer") {
            return .timerReset
        }

        // Timer contexts
        if text.contains("medical timeout") || text.contains("medical") {
            return .timerContext(.medical)
        }

        if text.contains("warm up") || text.contains("warmup") {
            return .timerContext(.warmup)
        }

        if text.contains("break") {
            return .timerContext(.breakT)
        }
        // new set timer
       // if text.contains("set") {
         //   return .timerContext(.setBreakT)
        //}

        return nil
    }

    // MARK: - SCORING DETECTION (V5 strict)

    private func detectScoringCommand(
        _ text: String,
        match: Match,
        isPlayer1Serving: Bool
    ) -> VoiceIntent? {

        // POINT
        if text.starts(with: "point ") || text.contains("point to") {
            if let p = detectPlayerRef(text: text, match: match, isPlayer1Serving: isPlayer1Serving) {
                return .point(player: p)
            }
        }

        // GAME (explicit command only)
        if text == "game" || text.starts(with: "game ") {
            return .game(player: .role(.server))
        }

        return nil
    }

    // MARK: - PLAYER RESOLUTION
    

    private func detectSpokenScore(_ text: String) -> VoiceIntent? {
        let parts = text.split(separator: " ")
        guard parts.count == 2 else { return nil }

        let p1 = String(parts[0])
        let p2 = String(parts[1])

        let tennis = ["0", "15", "30", "40", "ad"]

        func isScoreToken(_ s: String) -> Bool {
            return tennis.contains(s) || s.allSatisfy({ $0.isNumber })
        }

        guard isScoreToken(p1), isScoreToken(p2) else { return nil }

        return .scoreSpoken(server: p1, receiver: p2)
    }
   

    private func detectPlayerRef(
        text: String,
        match: Match,
        isPlayer1Serving: Bool
    ) -> PlayerRef? {

        let t = text

        if t.contains("player one") || t.contains("player 1") { return .player1 }
        if t.contains("player two") || t.contains("player 2") { return .player2 }

        let hasServe =
            t.contains("serve") ||
            t.contains("serving") ||
            t.contains("server")

        let hasReturn =
            t.contains("return") ||
            t.contains("receive") ||
            t.contains("receives") ||
            t.contains("receiving") ||
            t.contains("receiver") ||
            t.contains("returning")

        let p1 = match.player1.lowercased()
        let p2 = match.player2.lowercased()

        if t.contains(p1) { return .player1 }
        if t.contains(p2) { return .player2 }

        return nil
    }

    // MARK: - SANCTIONS

    private func detectSanction(_ text: String, match: Match) -> VoiceIntent? {

        if text.contains("warning") {
            if let p = detectPlayerRef(text: text, match: match, isPlayer1Serving: false) {
                return .warning(player: p)
            }
        }

        if text.contains("violation") {
            if let p = detectPlayerRef(text: text, match: match, isPlayer1Serving: false) {
                let raw = text
                let p1 = match.player1.lowercased()
                let p2 = match.player2.lowercased()
                var reason = raw
                reason = reason.replacingOccurrences(of: "violation", with: "")
                reason = reason.replacingOccurrences(of: p1, with: "")
                reason = reason.replacingOccurrences(of: p2, with: "")
                reason = reason.trimmingCharacters(in: .whitespaces)
                return .violation(player: p, reason: reason.isEmpty ? nil : reason)
            }
        }

        return nil
    }

    // MARK: - TEXT NORMALIZATION

    private func normalize(_ text: String) -> String {
        var t = text.lowercased()

        // NEW: Fix number spacing issue (4015 → 40 15)
        t = fixNumberSpacing(t)
        
        t = t.replacingOccurrences(of: "-", with: " ")
               t = t.replacingOccurrences(of: "_", with: " ")

               // Tennis score words → numbers
               t = t.replacingOccurrences(of: "love", with: "0")
                t = t.replacingOccurrences(of: "lot", with: "0")
        
        //for alls
        t = t.replacingOccurrences(of: "on", with: "all")
         t = t.replacingOccurrences(of: "hour", with: "all")
        t = t.replacingOccurrences(of: "oh", with: "all")

               t = t.replacingOccurrences(of: "fifteen", with: "15")
                t = t.replacingOccurrences(of: "fifty", with: "15")
               t = t.replacingOccurrences(of: "thirty", with: "30")
               t = t.replacingOccurrences(of: "forty", with: "40")

                t = t.replacingOccurrences(of: "-", with: " ")
                t = t.replacingOccurrences(of: "_", with: " ")

                // numeric words → numbers
                t = t.replacingOccurrences(of: "zero", with: "0")
                t = t.replacingOccurrences(of: "one", with: "1")
                t = t.replacingOccurrences(of: "two", with: "2")
                t = t.replacingOccurrences(of: "three", with: "3")
                t = t.replacingOccurrences(of: "four", with: "4")
                t = t.replacingOccurrences(of: "five", with: "5")
                t = t.replacingOccurrences(of: "six", with: "6")
                t = t.replacingOccurrences(of: "seven", with: "7")
                t = t.replacingOccurrences(of: "eight", with: "8")
                t = t.replacingOccurrences(of: "nine", with: "9")
                t = t.replacingOccurrences(of: "ten", with: "10")
                t = t.replacingOccurrences(of: "eleven", with: "11")
                t = t.replacingOccurrences(of: "twelve", with: "12")
                t = t.replacingOccurrences(of: "thirteen", with: "13")
                t = t.replacingOccurrences(of: "fourteen", with: "14")
                t = t.replacingOccurrences(of: "fifteen", with: "15")
                t = t.replacingOccurrences(of: "sixteen", with: "16")
                t = t.replacingOccurrences(of: "seventeen", with: "17")
                t = t.replacingOccurrences(of: "eighteen", with: "18")
                t = t.replacingOccurrences(of: "nineteen", with: "19")
                t = t.replacingOccurrences(of: "twenty", with: "20")
                t = t.replacingOccurrences(of: "twenty-one", with: "21")



        t = t.filter { "abcdefghijklmnopqrstuvwxyz0123456789 ".contains($0) }

        while t.contains("  ") {
            t = t.replacingOccurrences(of: "  ", with: " ")
        }

        return t.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - NUMBER SPACING FIX (NEW)

    /// Fixes "4015" → "40 15", "3015" → "30 15", etc.
    private func fixNumberSpacing(_ text: String) -> String {
        var result = text
        
        // Common tennis score combinations that get stuck together
        let patterns = [
            ("4015", "40 15"),
            ("4030", "40 30"),
            ("3015", "30 15"),
            ("1530", "15 30"),
            ("1540", "15 40"),
            ("3040", "30 40"),
            
        ]
        
        for (wrong, correct) in patterns {
            result = result.replacingOccurrences(of: wrong, with: correct)
        }
        
        return result
    }
}
