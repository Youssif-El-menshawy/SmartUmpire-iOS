//
//  SettingsUITests.swift
//  SmartUmpireUITests
//
//  ui tests for the settings screen.
//  tests notification toggles, security options, password change flow, and logout.
//

import XCTest

final class SettingsUITests: XCTestCase {

    private var app: XCUIApplication!

    // MARK: - Setup

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-UITest"]
        app.launch()

        handleSystemAlerts()
        navigateToSettings()
    }

    // MARK: - Helpers

    /// handles system permission alerts (notifications, Face ID, etc.)
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
            if alert.buttons["OK"].exists {
                alert.buttons["OK"].tap()
                return true
            }
            return false
        }
        app.tap()
    }

    /// navigates to the settings screen from the dashboard
    private func navigateToSettings() {
        let settingsButton = app.buttons["settingsButton"]
        if settingsButton.waitForExistence(timeout: 5) {
            settingsButton.tap()
        }
    }

    // MARK: - Tests

    // 1. settings view loads successfully
    func testSettingsViewLoads() {
        let settingsTitle = app.staticTexts["Settings"]
        XCTAssertTrue(settingsTitle.waitForExistence(timeout: 5), "settings title should be visible")
    }

    // 2. notifications section exists
    func testNotificationsSectionExists() {
        let notificationsHeader = app.staticTexts["Notifications"]
        XCTAssertTrue(notificationsHeader.waitForExistence(timeout: 5), "notifications section should exist")
    }

    // 3. privacy & security section exists
    func testSecuritySectionExists() {
        let securityHeader = app.staticTexts["Privacy & Security"]
        XCTAssertTrue(securityHeader.waitForExistence(timeout: 5), "privacy & security section should exist")
    }

    // 5. change password button opens sheet
    func testChangePasswordOpensSheet() {
        let changePasswordButton = app.buttons["Change Password"]
        XCTAssertTrue(changePasswordButton.waitForExistence(timeout: 5), "change password button should exist")
        changePasswordButton.tap()

        let sheetTitle = app.staticTexts["Change Password"]
        XCTAssertTrue(sheetTitle.waitForExistence(timeout: 5), "change password sheet should appear")
    }

    // 6. password sheet has required fields
    func testPasswordSheetFields() {
        let changePasswordButton = app.buttons["Change Password"]
        XCTAssertTrue(changePasswordButton.waitForExistence(timeout: 5))
        changePasswordButton.tap()

        XCTAssertTrue(app.staticTexts["Current Password"].waitForExistence(timeout: 5), "current password field should exist")
        XCTAssertTrue(app.staticTexts["New Password"].exists, "new password field should exist")
        XCTAssertTrue(app.staticTexts["Confirm New Password"].exists, "confirm new password field should exist")
    }

    // 7. password sheet can be dismissed
    func testPasswordSheetDismissal() {
        let changePasswordButton = app.buttons["Change Password"]
        XCTAssertTrue(changePasswordButton.waitForExistence(timeout: 5))
        changePasswordButton.tap()

        let cancelButton = app.buttons["Cancel"]
        XCTAssertTrue(cancelButton.waitForExistence(timeout: 5))
        cancelButton.tap()

        let securityHeader = app.staticTexts["Privacy & Security"]
        XCTAssertTrue(securityHeader.waitForExistence(timeout: 5), "should return to settings view")
    }



    // 9. logout button exists

    // 10. settings view is scrollable and footer is reachable
    func testSettingsScrollable() {
        app.swipeUp()

        let copyright = app.staticTexts["© 2025 SmartUmpire. All rights reserved."]
        XCTAssertTrue(copyright.waitForExistence(timeout: 5), "should be able to scroll to copyright footer")
    }
}
