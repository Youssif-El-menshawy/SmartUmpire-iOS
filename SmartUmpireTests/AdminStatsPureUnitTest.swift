import XCTest

final class AdminStatsPureUnitTest: XCTestCase {

    // Minimal models for the unit test
    struct Umpire {
        let rating: Double
    }

    struct Tournament { }

    // Function under test: same logic as your AppState.adminStats
    private func computeAdminStats(
        umpires: [Umpire],
        tournaments: [Tournament],
        matchesByTournament: [String: Int]
    ) -> (umpires: Int, tournaments: Int, matches: Int, avgRating: String) {

        let ump = umpires.count
        let tourn = tournaments.count
        let matches = matchesByTournament.values.reduce(0, +)

        let avg = umpires.map { $0.rating }.reduce(0, +) / Double(max(1, ump))
        return (ump, tourn, matches, String(format: "%.1f", avg))
    }

    // Case 1: Normal data
    func test_adminStats_case1_normalData() {
        let stats = computeAdminStats(
            umpires: [Umpire(rating: 4.0), Umpire(rating: 3.0)],
            tournaments: [Tournament()],
            matchesByTournament: ["T1": 2]
        )

        XCTAssertEqual(stats.umpires, 2)
        XCTAssertEqual(stats.tournaments, 1)
        XCTAssertEqual(stats.matches, 2)
        XCTAssertEqual(stats.avgRating, "3.5")
    }

    // Case 2: Edge case - no umpires
    func test_adminStats_case2_noUmpires() {
        let stats = computeAdminStats(
            umpires: [],
            tournaments: [Tournament()],
            matchesByTournament: ["T1": 1]
        )

        XCTAssertEqual(stats.umpires, 0)
        XCTAssertEqual(stats.tournaments, 1)
        XCTAssertEqual(stats.matches, 1)
        XCTAssertEqual(stats.avgRating, "0.0")
    }

    // Case 3: Multiple tournaments + matches
    func test_adminStats_case3_multipleTournamentsAndMatches() {
        let stats = computeAdminStats(
            umpires: [Umpire(rating: 5.0), Umpire(rating: 4.0), Umpire(rating: 3.0)],
            tournaments: [Tournament(), Tournament()],
            matchesByTournament: ["T1": 3, "T2": 2]
        )

        XCTAssertEqual(stats.umpires, 3)
        XCTAssertEqual(stats.tournaments, 2)
        XCTAssertEqual(stats.matches, 5)
        XCTAssertEqual(stats.avgRating, "4.0") // (5+4+3)/3 = 4.0
    }
}
