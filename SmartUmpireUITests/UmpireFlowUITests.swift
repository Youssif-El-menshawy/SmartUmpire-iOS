//
//  UmpireFlowUITests.swift
//  SmartUmpireUITests
//
//  Created by Youssef on 26/01/2026.
//

import XCTest

final class UmpireFlowUITests: XCTestCase {

    private var app: XCUIApplication!

    // MARK: - Setup

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-UITest"]
        app.launch()

        handleSystemAlerts()
    }

    // MARK: - Helpers

    /// Handles system permission alerts (Microphone, etc.)
    private func handleSystemAlerts() {
        addUIInterruptionMonitor(withDescription: "System Alerts") { alert in
            if alert.buttons["Don’t Allow"].exists {
                alert.buttons["Don’t Allow"].tap()
                return true
            }
            if alert.buttons["Cancel"].exists {
                alert.buttons["Cancel"].tap()
                return true
            }
            return false
        }

        // required to trigger the interruption monitor
        app.tap()
    }

    /// tap the first visible "View Matches" button
    private func tapFirstViewMatches() {
        let button = app.buttons["viewMatchesButton"].firstMatch
        XCTAssertTrue(button.waitForExistence(timeout: 5), "View Matches button not found")
        button.tap()
    }

    /// Taps the Start / Continue Match button
    private func tapStartMatch() {
        let button = app.buttons["startMatchButton"]
        XCTAssertTrue(button.waitForExistence(timeout: 5), "Start Match button not found")
        button.tap()
    }

    // MARK: - Tests

    // App launches to dashboard
    func testDashboardLoads() {
        let dashboard = app.scrollViews["umpireDashboard"]
        XCTAssertTrue(dashboard.waitForExistence(timeout: 5))
    }

    // Tournament card exists
    func testTournamentCardExists() {
        XCTAssertTrue(app.buttons["viewMatchesButton"].firstMatch.waitForExistence(timeout: 5))
    }

    //  Open tournament detail
    func testOpenTournamentDetail() {
        tapFirstViewMatches()

        let detail = app.scrollViews["tournamentDetail"]
        XCTAssertTrue(detail.waitForExistence(timeout: 5))
    }

    // Match row exists
    func testMatchRowExists() {
        tapFirstViewMatches()

        XCTAssertTrue(app.buttons["startMatchButton"].waitForExistence(timeout: 5))
    }

    // Open match scoring view
    func testOpenMatchScoringView() {
        tapFirstViewMatches()
        tapStartMatch()

        let scoringView = app.scrollViews["matchScoringView"]
        XCTAssertTrue(app.buttons["manualOverrideButton"].waitForExistence(timeout: 10))

    }

    // Manual override button exists
    func testManualOverrideButtonExists() {
        tapFirstViewMatches()
        tapStartMatch()

        let overrideButton = app.buttons["manualOverrideButton"]
        XCTAssertTrue(overrideButton.waitForExistence(timeout: 5))
    }

    //  Manual override sheet opens
    func testOpenManualOverrideSheet() {
        tapFirstViewMatches()
        tapStartMatch()

        let overrideButton = app.buttons["manualOverrideButton"]
        XCTAssertTrue(overrideButton.waitForExistence(timeout: 5))
        overrideButton.tap()

        //  Robust assertion: navigation title of the sheet
        let navBar = app.navigationBars["Manual Override"]
        XCTAssertTrue(navBar.waitForExistence(timeout: 5))
    }
}
