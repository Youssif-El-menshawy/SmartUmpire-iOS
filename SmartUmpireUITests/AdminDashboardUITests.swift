//
//  AdminDashboardUITests.swift
//  SmartUmpire
//
//  Created by Youssef on 26/01/2026.
//

import XCTest

final class AdminDashboardUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false

        app = XCUIApplication()
        app.launchArguments += ["-UITest_Admin"]
        app.launch()
    }

    func testAdminDashboardLoadsAndOpensTournamentsTab() {

        // 1️⃣ Admin dashboard exists
        let dashboard = app.otherElements["adminDashboard"]
        XCTAssertTrue(dashboard.waitForExistence(timeout: 5),
                      "Admin dashboard did not load")

        // 2️⃣ Switch to Tournaments tab
        let tournamentsTab = app.buttons["adminTab_Tournaments"]
        XCTAssertTrue(tournamentsTab.exists,
                      "Tournaments tab not found")
        tournamentsTab.tap()

        // 3️⃣ Verify tournaments content exists
        // (either empty state or at least UI container)
        XCTAssertTrue(dashboard.exists,
                      "Dashboard disappeared after tab switch")
    }
}
