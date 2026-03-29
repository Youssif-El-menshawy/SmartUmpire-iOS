import SwiftUI
import FirebaseFirestore

extension AppState {
    func matches(for tournament: Tournament) -> [Match] {
        matchesByTournament[tournament.id] ?? []
    }
    
    var adminStats: (umpires: Int, tournaments: Int, matches: Int, avgRating: String) {
        let ump = umpires.count
        let tourn = tournaments.count
        let m = matchesByTournament.values.reduce(0) { $0 + $1.count }
        let avg = (umpires.map { $0.rating }.reduce(0,+) / Double(max(1, ump)))
        return (ump, tourn, m, String(format: "%.1f", avg))
    }
}
