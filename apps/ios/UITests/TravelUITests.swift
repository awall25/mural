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
    @MainActor private func launchTaskFixtures() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--travel-ui-tests", "--travel-task-fixtures"]
        app.launch()
        XCTAssertTrue(app.staticTexts["TASK 1 OF 4"].waitForExistence(timeout: 10))
        return app
    }
    @MainActor private func check(_ reply: String, in app: XCUIApplication) {
        let field = app.descendants(matching: .any).matching(identifier: "travel-reply").firstMatch
        for _ in 0..<5 where !field.isHittable { app.swipeUp() }
        XCTAssertTrue(field.isHittable)
        let clear = app.buttons["travel-clear"]
        if clear.exists { clear.tap() }
        field.tap()
        field.typeText(reply)
        if app.toolbars.buttons["Done"].exists { app.toolbars.buttons["Done"].tap() }
        let send = app.buttons["travel-send"]
        for _ in 0..<3 where !send.isHittable { app.swipeUp() }
        send.tap()
    }
    @MainActor func testUnrelatedAndIncompleteRepliesRequireRetry() {
        let app = launchTaskFixtures()
        check("Me gustan los dinosaurios", in: app)
        XCTAssertTrue(app.staticTexts["Let's stay with this task"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["0 of 4 tasks passed"].exists)
        XCTAssertFalse(app.buttons["task-next"].exists)
        check("Una mesa para dos", in: app)
        XCTAssertTrue(app.staticTexts["Try this task again"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["0 of 4 tasks passed"].exists)
        check("No tenemos reserva. Una mesa para dos en la terraza, por favor.", in: app)
        let next = app.buttons["task-next"]
        XCTAssertTrue(next.waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["1 of 4 tasks passed"].exists)
        next.tap()
        XCTAssertTrue(app.staticTexts["TASK 2 OF 4"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["task-next"].exists)
    }
    @MainActor func testHelpKeepsTaskAndRevealsExample() {
        let app = launchTaskFixtures()
        check("ayuda", in: app)
        XCTAssertTrue(app.staticTexts["Let's try it with a hint"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["One way to say it"].exists)
        XCTAssertTrue(app.staticTexts["0 of 4 tasks passed"].exists)
        XCTAssertFalse(app.buttons["task-next"].exists)
    }
    @MainActor func testOnlyPassingAllTasksCompletesScenario() {
        let app = launchTaskFixtures()
        let replies = ["No tenemos reserva. Una mesa para dos fuera.", "¿Cuánto hay que esperar?", "Podemos esperar. Dos aguas, por favor.", "La cuenta, por favor. ¿Podemos pagar con tarjeta?"]
        for (index, reply) in replies.enumerated() {
            check(reply, in: app)
            if index < replies.count - 1 {
                let next = app.buttons["task-next"]
                XCTAssertTrue(next.waitForExistence(timeout: 4)); next.tap()
                XCTAssertTrue(app.staticTexts["TASK \(index + 2) OF 4"].waitForExistence(timeout: 3))
            }
        }
        XCTAssertTrue(app.staticTexts["Scenario completed"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["4 of 4 tasks passed"].exists)
        XCTAssertFalse(app.buttons["travel-send"].exists)
        app.tabBars.buttons["Progress"].tap()
        XCTAssertTrue(app.staticTexts["1 of 8 situations completed"].waitForExistence(timeout: 3))
    }

    @MainActor func testEarlierConversationsSurviveStructuredUpdate() {
        let app = XCUIApplication()
        app.launchArguments = ["--travel-ui-tests", "--travel-legacy-history"]
        app.launch()
        app.tabBars.buttons["Progress"].tap()
        XCTAssertTrue(app.staticTexts["0 of 8 situations completed"].waitForExistence(timeout: 4))
        let conversation = app.staticTexts["A table & a meal"]
        XCTAssertTrue(conversation.exists); conversation.tap()
        XCTAssertTrue(app.staticTexts["Earlier free conversation"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["You: Una mesa, por favor."].exists)
    }

}
