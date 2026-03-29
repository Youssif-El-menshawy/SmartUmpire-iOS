import Foundation
import SwiftUI

// MARK: - Routes
enum UmpireRoute: Hashable {
    case tournamentDetail(Tournament)
    case matchScoring(Match)
    case matchDetails(Match)
    case profile
    case settings
}

enum AdminRoute: Hashable {
    case settings
    case adminUmpireDetail(umpireID: String)
    case editUmpireCertifications(umpireID: String)
    case viewUmpireMatches(umpireID: String)
    case adminUmpireDetailMatchWithTournament(Match, Tournament)
}


enum UserRole: String, Codable {
    case umpire
    case admin
}

enum TournamentStatus: String, Codable {
    case live = "Live"
    case upcoming = "Upcoming"
    case completed = "Completed"
}

enum MatchStatus: String, Codable, CaseIterable {
    case live = "Live"
    case upcoming = "Upcoming"
    case completed = "Completed"
}


enum UmpireStatus: String, Codable, CaseIterable {
    case available = "available"
    case assigned = "assigned"
    case unavailable = "unavailable"
}

struct MatchSummary: Codable, Hashable {
    let finalScore: String
    let durationSeconds: Int
    let totalWarningsP1: Int
    let totalWarningsP2: Int
    let tiebreaksPlayed: Int
    let endedAt: Date
}


struct Tournament: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let dateRange: String
    let location: String
    let matchesCount: Int
    let status: TournamentStatus
}

struct Match: Identifiable, Codable, Hashable {
    let id: String
    var time: String
    var court: String
    var player1: String
    var player2: String
    var round: String
    var score: String?
    var status: MatchStatus
    var summary: MatchSummary?

    var assignedUmpire: String?
    var assignedUmpireEmail: String?
}


struct Umpire: Identifiable, Codable, Hashable {
    var id: String
    var name: String
    var email: String
    var phone: String?
    var location: String?
    var specialization: String
    var rating: Double
    var matchesCount: Int
    var tournaments: Int
    var yearsExperience: Int
    var status: UmpireStatus
    var performance: UmpirePerformance?
    var certifications: [UmpireCertification]?
    var avatarURL: String?
}

struct UmpirePerformance: Codable, Hashable {
    let averageRating: Double
    let completionRate: Double
    let onTime: Double
}

struct UmpireCertification: Codable, Identifiable, Hashable {
    var id: String
    var title: String
    var issuer: String
    var year: String
    var active: Bool
}

struct MatchScore: Codable {
    var player1Sets: Int = 0
    var player2Sets: Int = 0

    var player1Games: Int = 0
    var player2Games: Int = 0

    var player1Points: String = "0"
    var player2Points: String = "0"

    var player1Warnings: Int = 0
    var player2Warnings: Int = 0

    // TRUE = Player 1 serves, FALSE = Player 2 serves
    var isPlayer1Serving: Bool = true

    var isTiebreak: Bool = false
    
    var completedSets: [SetScore] = []   //  NEW


    // MARK: - Helpers added for TennisScoreEngine

    mutating func resetPoints() {
        player1Points = "0"
        player2Points = "0"
    }

    mutating func resetGames() {
        player1Games = 0
        player2Games = 0
    }

    mutating func switchServer() {
        isPlayer1Serving.toggle()
    }

    /// Returns 1 if Player1 is server, 2 if Player2 is server
    func currentServerIndex() -> Int {
        return isPlayer1Serving ? 1 : 2
    }
}

struct SetScore: Codable, Hashable {
    var player1Games: Int
    var player2Games: Int
}


extension MatchScore {
    var finalScoreString: String {
        completedSets
            .map { "\($0.player1Games)-\($0.player2Games)" }
            .joined(separator: " ")
    }
}

struct EventItem: Identifiable, Codable, Hashable {
    let id: String
    let time: String
    let type: String
    let description: String
    let source: String?
    let createdAt: Date
    let colorName: String   // stored form (Codable-safe)

    //  This is the initializer VoiceIntentDispatcher uses
    init(
        id: String = UUID().uuidString,
        time: String,
        type: String,
        description: String,
        color: Color,
        source: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.time = time
        self.type = type
        self.description = description
        self.source = source
        self.createdAt = createdAt
        self.colorName = EventItem.mapColor(color)
    }

    // MARK: - Runtime color
    var color: Color {
        switch colorName {
        case "primaryBlue": return .primaryBlue
        case "blue600": return .blue600
        case "successGreen": return .successGreen
        case "warningYellow": return .warningYellow
        case "errorRed": return .errorRed
        case "purple": return .purple
        default: return .textSecondary
        }
    }

    // MARK: - Color mapping (single source)
    private static func mapColor(_ color: Color) -> String {
        if color == .primaryBlue { return "primaryBlue" }
        if color == .blue600 { return "blue600" }
        if color == .successGreen { return "successGreen" }
        if color == .warningYellow { return "warningYellow" }
        if color == .errorRed { return "errorRed" }
        if color == .purple { return "purple" }
        return "neutral"
    }
}

extension EventItem {
    static func defaultColor(for type: String) -> Color {
        switch type.lowercased() {
        case "point": return .successGreen
        case "game": return .blue600
        case "set", "tiebreak": return .purple
        case "warning": return .warningYellow
        case "violation", "error": return .errorRed
        case "timer", "server", "score": return .primaryBlue
        default: return .textSecondary
        }
    }
}

extension MatchScore {
    static let empty = MatchScore(
        player1Sets: 0,
        player2Sets: 0,
        player1Games: 0,
        player2Games: 0,
        player1Points: "0",
        player2Points: "0",
        player1Warnings: 0,
        player2Warnings: 0,
        isPlayer1Serving: true
    )
}
