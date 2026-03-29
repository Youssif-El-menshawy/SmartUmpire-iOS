import XCTest
import SwiftUI
@testable import SmartUmpire

final class UmpireVoiceIntegrationTests: XCTestCase {

    final class Box<T> {
        var value: T
        init(_ value: T) { self.value = value }
    }

    private func makeMatch() -> Match {
        Match(
            id: "test-match",
            time: "12:00",
            court: "Center Court",
            player1: "Player One",
            player2: "Player Two",
            round: "Final",
            score: nil,
            status: .live,
            summary: nil,
            assignedUmpire: nil,
            assignedUmpireEmail: nil
        )
    }

    func testVoiceSpokenScoreAndPointFlow() {
        let match = makeMatch()
        let parser = VoiceIntentParser()
        let engine = TennisScoreEngine()

        let scoreBox = Box(MatchScore.empty)
        var events: [EventItem] = []

        func addEvent(_ desc: String, color: Color) {
            events.append(
                EventItem(
                    time: "12:00",
                    type: "test",
                    description: desc,
                    color: color
                )
            )
        }

        // 1️⃣ Parse spoken score
        let intents = parser.parse("fifteen love", match: match, isPlayer1Serving: true)
        XCTAssertEqual(intents.count, 1)

        guard case let .scoreSpoken(server, receiver) = intents.first else {
            XCTFail("Expected scoreSpoken intent")
            return
        }

        XCTAssertEqual(server, "15")
        XCTAssertEqual(receiver, "0")

        // Apply point via engine
        let result = engine.addPoint(toPlayer1: true, current: scoreBox.value)
        scoreBox.value = result.score
        addEvent("Point added", color: Color.successGreen)

        XCTAssertEqual(scoreBox.value.player1Points, "15")
        XCTAssertEqual(scoreBox.value.player2Points, "0")
        XCTAssertFalse(events.isEmpty)
    }
}
