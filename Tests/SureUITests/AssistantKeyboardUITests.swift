import XCTest

final class AssistantKeyboardUITests: XCTestCase {
  @MainActor
  func testSwipingDownInMultiTurnConversationDismissesKeyboardAndRestoresNavigation() {
    continueAfterFailure = false
    let app = XCUIApplication()
    app.launchEnvironment["SURE_SCENARIO"] = "assistant-history"
    app.launch()

    let suggestion = app.buttons["💸 Where did my money go?"]
    XCTAssertTrue(suggestion.waitForExistence(timeout: 10))
    suggestion.tap()
    let answer = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "On-device fixture response"))
    XCTAssertTrue(answer.firstMatch.waitForExistence(timeout: 5))

    let composer = app.descendants(matching: .any)["assistant-composer"].firstMatch
    XCTAssertTrue(composer.waitForExistence(timeout: 5))
    composer.tap()
    composer.typeText("Compare that to last month")
    app.buttons["Send"].tap()
    XCTAssertTrue(answer.element(boundBy: 1).waitForExistence(timeout: 5))

    composer.tap()
    composer.typeText("An unsent follow-up")
    let keyboard = app.keyboards.firstMatch
    XCTAssertTrue(keyboard.waitForExistence(timeout: 5))

    let transcript = app.scrollViews["assistant-transcript"]
    XCTAssertTrue(transcript.isHittable)
    transcript.swipeDown()

    XCTAssertTrue(keyboard.waitForNonExistence(timeout: 5))
    XCTAssertTrue(app.tabBars.buttons["Assistant"].isHittable)
    XCTAssertTrue(app.buttons["Conversations"].isHittable)
    XCTAssertEqual(composer.value as? String, "An unsent follow-up")
  }
}
