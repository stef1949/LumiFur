//
//  LumiFurWatchOS_Watch_AppUITests.swift
//  LumiFurWatchOS Watch AppUITests
//
//  Created by Stephan Ritchie on 2/14/25.
//

import XCTest

final class LumiFurWatchOS_Watch_AppUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testDashboardLaunches() throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.staticTexts["LumiFur"].waitForExistence(timeout: 10))
        XCTAssertTrue(
            app.staticTexts["Connecting to iPhone"].exists ||
            app.staticTexts["iPhone Connected"].exists ||
            app.staticTexts["iPhone Unavailable"].exists
        )
    }

    @MainActor
    func testLaunchPerformance() throws {
        if #available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 7.0, *) {
            // This measures how long it takes to launch your application.
            measure(metrics: [XCTApplicationLaunchMetric()]) {
                XCUIApplication().launch()
            }
        }
    }
}
