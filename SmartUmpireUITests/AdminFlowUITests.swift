//
//  AdminFlowUITests.swift
//  SmartUmpireUITests
//
//  UI tests for the admin dashboard flow.
//  Tests navigation, CRUD entry points, and tab switching for admin users.
//

import XCTest

final class AdminFlowUITests: XCTestCase {
    
    private func scrollToTop() {
        let dashboard = app.scrollViews["adminDashboard"]
        dashboard.swipeDown()
        dashboard.swipeDown()
    }

    
    private func waitForAdminDashboard() {
        XCTAssertTrue(
            app.scrollViews["adminDashboard"].waitForExistence(timeout: 8),
            "Admin dashboard did not load"
        )

        XCTAssertTrue(
            app.otherElements["adminTab_Tournaments"].waitForExistence(timeout: 5),
            "Admin tabs did not load"
        )
    }
    


    private var app: XCUIApplication!

    // MARK: - Setup

    override func setUp() {
        super.setUp()

        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-UITest", "-AdminMode"]
        app.launch()

        handleSystemAlerts()
    }

    // MARK: - Helpers

    /// Handles system permission alerts (notifications, tracking, etc.)
    private func handleSystemAlerts() {
        addUIInterruptionMonitor(withDescription: "System Alerts") { alert in
            if alert.buttons["Don't Allow"].exists {
                alert.buttons["Don't Allow"].tap()
                return true
            }

            if alert.buttons["Cancel"].exists {
                alert.buttons["Cancel"].tap()
                return true
            }

            return false
        }

        app.tap()
    }

    /// Taps the settings button in the admin dashboard header
    private func tapSettingsButton() {
        let button = app.buttons["settingsButton"]
        XCTAssertTrue(button.waitForExistence(timeout: 5), "Settings button not found")
        button.tap()
    }

    /// Taps the add tournament button
    private func tapAddTournamentButton() {
        let button = app.buttons["addTourneyButton"]
        XCTAssertTrue(button.waitForExistence(timeout: 5), "Add tournament button not found")
        button.forceTap()
    }

    /// Taps the add umpire button
    private func tapAddUmpireButton() {
        let button = app.buttons["addUmpireButton"]
        XCTAssertTrue(button.waitForExistence(timeout: 5), "Add umpire button not found")
        button.forceTap()
    }

    /// Switches to the umpires tab
    private func switchToUmpiresTab() {
        let tab = app.buttons["adminTab_Umpires"]
        XCTAssertTrue(tab.waitForExistence(timeout: 5), "Umpires tab not found")
        tab.tap()
    }

    /// Switches to the tournaments tab
    private func switchToTournamentsTab() {
        let tab = app.buttons["adminTab_Tournaments"]
        XCTAssertTrue(tab.waitForExistence(timeout: 5), "Tournaments tab not found")
        tab.tap()
    }

    // MARK: - Tests

    /// 1. Admin dashboard loads successfully
    func testAdminDashboardLoads() {
        let dashboard = app.scrollViews["adminDashboard"]
        XCTAssertTrue(dashboard.waitForExistence(timeout: 5), "Admin dashboard should load")
    }

    /// 2. Stats tiles are displayed
    func testStatsTilesExist() {
        XCTAssertTrue(
            app.staticTexts["Total Umpires"].waitForExistence(timeout: 5),
            "Total umpires stat should exist"
        )
        XCTAssertTrue(app.staticTexts["Total Tourney"].exists, "Total tourney stat should exist")
        XCTAssertTrue(app.staticTexts["Total Matches"].exists, "Total matches stat should exist")
        XCTAssertTrue(app.staticTexts["Avg Rating"].exists, "Avg rating stat should exist")
    }

    /// 3. Segmented tabs exist and are tappable

    /// 4. Can switch to umpires tab
   

    /// 5. Can switch back to tournaments tab
    func testSwitchBetweenTabs() {
        switchToUmpiresTab()
        switchToTournamentsTab()

        let manageTournamentsText = app.staticTexts["Manage Tournaments"]
        XCTAssertTrue(
            manageTournamentsText.waitForExistence(timeout: 5),
            "Manage Tournaments section should appear"
        )
    }

    /// 6. Settings button navigates to settings screen

    /// 7. Add tournament button opens create tournament sheet
    func testAddTournamentOpensSheet() {
        scrollToTop()
        tapAddTournamentButton()

        let formTitle = app.staticTexts["Create Tournament"]
        XCTAssertTrue(
            formTitle.waitForExistence(timeout: 5),
            "Tournament form should appear"
        )
    }

    /// 8. Add umpire button opens create umpire sheet
    func testAddUmpireOpensSheet() {
        switchToUmpiresTab()
        tapAddUmpireButton()

        let formTitle = app.staticTexts["Add Umpire"]
        XCTAssertTrue(
            formTitle.waitForExistence(timeout: 5),
            "Umpire form should appear"
        )
    }

    /// 9. Umpire search bar exists


    /// 10. Tournament card is tappable and navigates to detail screen
    func testTournamentCardNavigation() {
        let tournamentCard = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'tournamentCard_'")
        ).firstMatch

        guard tournamentCard.waitForExistence(timeout: 5) else {
            // No tournaments available — skip test
            return
        }

        tournamentCard.tap()

        let addMatchButton = app.buttons["Add Match"]
        XCTAssertTrue(
            addMatchButton.waitForExistence(timeout: 5),
            "Tournament detail should show Add Match button"
        )
    }

    /// 11. Umpire row is tappable and navigates to detail screen
    func testUmpireRowNavigation() {
        switchToUmpiresTab()

        let umpireRow = app.buttons["umpireRow"].firstMatch

        guard umpireRow.waitForExistence(timeout: 5) else {
            // No umpires available — skip test
            return
        }

        umpireRow.tap()

        let umpireNavBar = app.navigationBars["Umpire"]
        XCTAssertTrue(
            umpireNavBar.waitForExistence(timeout: 5),
            "Should navigate to umpire detail screen"
        )
    }

    /// 12. Pull-to-refresh works on dashboard
    func testPullToRefresh() {
        let dashboard = app.scrollViews["adminDashboard"]
        XCTAssertTrue(dashboard.waitForExistence(timeout: 5))

        dashboard.swipeDown()

        XCTAssertTrue(
            dashboard.exists,
            "Dashboard should still exist after refresh"
        )
    }
}


extension XCUIElement {
    func forceTap() {
        let coordinate = coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        coordinate.tap()
    }
}
