//
//  TennisScoreEngine.swift
//  SmartUmpire
//
//  Encapsulates professional tennis scoring logic:
//  - normal game point progression (0 → 15 → 30 → 40 → game)
//  - deuce / advantage
//  - game wins
//  - basic tiebreak support using MatchScore.isTiebreak
//

import Foundation


enum MatchCompletion {
    case ongoing
    case finished(winnerIsPlayer1: Bool)
}

/// Pure tennis scoring engine:
/// - does NOT know about players' names
/// - does NOT know about Match / PlayerRef
/// - only works with MatchScore and "which side" (player 1 or 2)
final class TennisScoreEngine {

    // MARK: - Public API

    /// Adds one point for the specified player.
    ///
    /// - Parameters:
    ///   - toPlayer1: true = player 1, false = player 2
    ///   - current: the current match score
    /// - Returns: updated match score after applying the point
    func addPoint(toPlayer1: Bool, current: MatchScore) -> (score: MatchScore, completion: MatchCompletion) {
        var score = current

        if score.isTiebreak {
            score = applyTiebreakPoint(toPlayer1: toPlayer1, score: score)
        } else {
            score = toPlayer1 ? applyPointToPlayer1(score: score) : applyPointToPlayer2(score: score)
        }

        let completion = checkMatchCompletion(score: score)
        return (score: score, completion: completion)
    }


    /// Forces a game win for the specified player.
    /// Does not enforce any rules, just increments games and resets points.
    func forceGameWinner(isPlayer1: Bool, current: MatchScore) -> MatchScore {
        var score = current

        if isPlayer1 {
            score.player1Games += 1
        } else {
            score.player2Games += 1
        }

        // Automatic tiebreak entry: When games reach 6-6, start tiebreak
        if !score.isTiebreak && score.player1Games == 6 && score.player2Games == 6 {
            score.isTiebreak = true
            score.resetPoints()
            return score
        }
        
        if score.isTiebreak {
            if score.player1Games == 7 && score.player2Games == 6 {
                // Save set
                score.completedSets.append(
                    SetScore(player1Games: 7, player2Games: 6)
                )
                score.player1Sets += 1
                score.resetGames()
                score.isTiebreak = false
                score.resetPoints()
                score.switchServer()
                return score
            }

            if score.player2Games == 7 && score.player1Games == 6 {
                score.completedSets.append(
                    SetScore(player1Games: 6, player2Games: 7)
                )
                score.player2Sets += 1
                score.resetGames()
                score.isTiebreak = false
                score.resetPoints()
                score.switchServer()
                return score
            }
        }

        //  CHECK SET COMPLETION (THIS WAS LOST)
        if score.player1Games >= 6 || score.player2Games >= 6 {
            let diff = abs(score.player1Games - score.player2Games)

            if diff >= 2 {
                // SAVE THE SET SCORE FIRST
                score.completedSets.append(
                    SetScore(
                        player1Games: score.player1Games,
                        player2Games: score.player2Games
                    )
                )

                if score.player1Games > score.player2Games {
                    score.player1Sets += 1
                } else {
                    score.player2Sets += 1
                }

                score.resetGames()
                score.isTiebreak = false
            }
        }

        score.resetPoints()
        score.switchServer()

        return score
    }



    /// Forces a set win for the specified player.
    /// Does not enforce any rules, just increments sets and resets games/points
    /// and leaves tiebreak mode.
    func forceSetWinner(isPlayer1: Bool, current: MatchScore) -> MatchScore {
        var s = current

        if isPlayer1 {
            s.player1Sets += 1
        } else {
            s.player2Sets += 1
        }

        // New set: reset games and points and exit tiebreak if any.
        s.resetGames()
        s.resetPoints()
        s.isTiebreak = false

        return s
    }

    // MARK: - Internal Point Logic (Normal Games)

    /// Applies a point to player 1, handling:
    /// - 0 → 15 → 30 → 40
    /// - deuce / advantage
    /// - game win + game increment
    private func applyPointToPlayer1(score s: MatchScore) -> MatchScore {
        var s = s
        let a = s.player1Points
        let b = s.player2Points

        // --- Advantage logic ---

        // Player 1 already has advantage → wins the game.
        if a == "Ad" {
            return incrementGame(forPlayer1: true, score: s)
        }

        // From deuce (40–40) → advantage player 1
        if a == "40", b == "40" {
            s.player1Points = "Ad"
            s.player2Points = "40"
            return s
        }

        // Opponent had advantage → back to deuce (40–40)
        if b == "Ad" {
            s.player1Points = "40"
            s.player2Points = "40"
            return s
        }

        // --- Normal point progression ---

        switch a {
        case "0":
            s.player1Points = "15"
        case "15":
            s.player1Points = "30"
        case "30":
            s.player1Points = "40"

        case "40":
            // If opponent below 40, player 1 wins the game
            if ["0", "15", "30"].contains(b) {
                return incrementGame(forPlayer1: true, score: s)
            }
            // If opponent is 40 or Ad, we already handled those cases above.

        default:
            break
        }

        return s
    }

    /// Applies a point to player 2, handling:
    /// - 0 → 15 → 30 → 40
    /// - deuce / advantage
    /// - game win + game increment
    private func applyPointToPlayer2(score s: MatchScore) -> MatchScore {
        var s = s
        let a = s.player2Points
        let b = s.player1Points

        // --- Advantage logic ---

        // Player 2 already has advantage → wins the game.
        if a == "Ad" {
            return incrementGame(forPlayer1: false, score: s)
        }

        // From deuce (40–40) → advantage player 2
        if a == "40", b == "40" {
            s.player2Points = "Ad"
            s.player1Points = "40"
            return s
        }

        // Opponent had advantage → back to deuce (40–40)
        if b == "Ad" {
            s.player1Points = "40"
            s.player2Points = "40"
            return s
        }

        // --- Normal point progression ---

        switch a {
        case "0":
            s.player2Points = "15"
        case "15":
            s.player2Points = "30"
        case "30":
            s.player2Points = "40"

        case "40":
            // If opponent below 40, player 2 wins the game
            if ["0", "15", "30"].contains(b) {
                return incrementGame(forPlayer1: false, score: s)
            }

        default:
            break
        }

        return s
    }

    // MARK: - Tiebreak Logic

    /// Applies a tiebreak point to either player:
    /// - numeric points (0,1,2,3,...)
    /// - win-by-2 from 7+
    /// - automatic set win for the player who wins the tiebreak
    private func applyTiebreakPoint(toPlayer1: Bool, score s: MatchScore) -> MatchScore {
        var s = s

        // Current numeric points
        let p1 = Int(s.player1Points) ?? 0
        let p2 = Int(s.player2Points) ?? 0

        // Apply new point
        let newP1 = toPlayer1 ? p1 + 1 : p1
        let newP2 = toPlayer1 ? p2 : p2 + 1

        s.player1Points = String(newP1)
        s.player2Points = String(newP2)

        // --- Check win condition: First to 7+, must win by 2 ---
        let lead1 = newP1 - newP2
        let lead2 = newP2 - newP1

        let p1WinsSet = newP1 >= 7 && lead1 >= 2
        let p2WinsSet = newP2 >= 7 && lead2 >= 2

        if p1WinsSet {
            // Player 1 won the tiebreak → wins the set 7–6
            s.player1Sets += 1
            s.player1Games = 0
            s.player2Games = 0
            s.resetPoints()
            s.isTiebreak = false
            return s
        }

        if p2WinsSet {
            // Player 2 won the tiebreak → wins the set 7–6
            s.player2Sets += 1
            s.player1Games = 0
            s.player2Games = 0
            s.resetPoints()
            s.isTiebreak = false
            return s
        }

        return s
    }


    // MARK: - Helpers

    /// Increments games for the winner and resets points to 0–0.
    /// Also automatically enters tiebreak mode when games reach 6–6.
    private func incrementGame(forPlayer1: Bool, score: MatchScore) -> MatchScore {
        var s = score

        if forPlayer1 {
            s.player1Games += 1
        } else {
            s.player2Games += 1
        }

        // New game: reset points
        s.resetPoints()

        // Optional: auto-switch server each game
        // If you want that behavior, uncomment:
        // s.switchServer()

        // Automatic tiebreak enter:
        // When games reach 6–6 in the current set, we start a tiebreak.
        if !s.isTiebreak && s.player1Games == 6 && s.player2Games == 6 {
            s.isTiebreak = true
            s.resetPoints()
        }
        // auto rotate server each game
        s.switchServer()

        return s
    }

    func checkMatchCompletion(score: MatchScore) -> MatchCompletion {
    // Best of 3: first to 2 sets
    if score.player1Sets >= 2 { return .finished(winnerIsPlayer1: true) }
    if score.player2Sets >= 2 { return .finished(winnerIsPlayer1: false) }
    return .ongoing
}

}
