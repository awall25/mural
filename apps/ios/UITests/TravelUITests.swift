import XCTest

final class TravelUITests: XCTestCase {
    @MainActor private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--travel-ui-tests"]
        app.launch()
        return app
    }
    @MainActor func testOfflineLaunchAndScenarioSelection() {
        let app = launch()
        XCTAssertTrue(app.staticTexts["A table & a meal"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.tabBars.buttons["Practice"].exists)
        app.tabBars.buttons["Situations"].tap()
        let hotel = app.buttons["scenario-hotel"]
        XCTAssertTrue(hotel.waitForExistence(timeout: 3))
        hotel.tap()
        XCTAssertTrue(app.staticTexts["At the hotel"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Buenas tardes, ¿a nombre de quién está la reserva?"].exists)
    }
    @MainActor func testPhrasebookSearchWithoutCredentials() {
        let app = launch()
        app.tabBars.buttons["Phrasebook"].tap()
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 3))
        search.tap(); search.typeText("bill")
        XCTAssertTrue(app.staticTexts["La cuenta, por favor."].waitForExistence(timeout: 3))
        XCTAssertFalse(app.staticTexts["Un café con leche, por favor."].exists)
    }
    @MainActor func testSendRequiresConsentAndDoesNotStartVoiceSession() {
        let app = launch()
        let reply = app.textViews["travel-reply"]
        app.swipeUp()
        if reply.exists { reply.tap(); reply.typeText("Una mesa para dos, por favor.") }
        else {
            let field = app.textFields["travel-reply"]
            XCTAssertTrue(field.waitForExistence(timeout: 3)); field.tap(); field.typeText("Una mesa para dos, por favor.")
        }
        app.buttons["travel-send"].tap()
        XCTAssertTrue(app.staticTexts["Economical practice"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.secureTextFields["travel-api-key"].exists)
    }
    @MainActor func testProgressEmptyState() {
        let app = launch()
        app.tabBars.buttons["Progress"].tap()
        XCTAssertTrue(app.staticTexts["Your first conversation awaits"].waitForExistence(timeout: 3))
    }
}
