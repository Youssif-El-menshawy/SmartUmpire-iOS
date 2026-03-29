import XCTest
@testable import SmartUmpire

final class AppStateQuickTests: XCTestCase {

    @MainActor
    func test_adminStats_countsAndAverage() {
        let state = AppState()

        //  umpires (in-memory only)
        state.umpires = [
            Umpire(
                id: "U1", name: "A", email: "a@test.com",
                phone: nil, location: nil, specialization: "Tennis",
                rating: 4.0, matchesCount: 0, tournaments: 0, yearsExperience: 0,
                status: .available, performance: nil, certifications: nil, avatarURL: nil
            ),
            Umpire(
                id: "U2", name: "B", email: "b@test.com",
                phone: nil, location: nil, specialization: "Tennis",
                rating: 3.0, matchesCount: 0, tournaments: 0, yearsExperience: 0,
                status: .available, performance: nil, certifications: nil, avatarURL: nil
            )
        ]

        //  tournaments
        state.tournaments = [
            Tournament(
                id: "T1", name: "Open", dateRange: "Jan", location: "Wroclaw",
                matchesCount: 0, status: .upcoming
            )
        ]

        //  matches grouped by tournament
        state.matchesByTournament = [
            "T1": [
                Match(id: "M1", time: "10:00", court: "1", player1: "P1", player2: "P2", round: "R1",
                      score: nil, status: .upcoming, assignedUmpire: nil, assignedUmpireEmail: nil),
                Match(id: "M2", time: "11:00", court: "2", player1: "P3", player2: "P4", round: "R1",
                      score: nil, status: .upcoming, assignedUmpire: nil, assignedUmpireEmail: nil)
            ]
        ]

        // Run the code under test
        let stats = state.adminStats

        // Verify expected results
        XCTAssertEqual(stats.umpires, 2)
        XCTAssertEqual(stats.tournaments, 1)
        XCTAssertEqual(stats.matches, 2)
        XCTAssertEqual(stats.avgRating, "3.5") // (4.0+3.0)/2
    }
}
