import XCTest

final class AssistantHistoryUITests: XCTestCase {
  @MainActor
  func testSavedConversationsAppearBelowNewConversationAndReopen() throws {
    continueAfterFailure = false
    let app = XCUIApplication()
    app.launchEnvironment["SURE_SCENARIO"] = "assistant-history"
    app.launch()

    let question = app.buttons["💸 Where did my money go?"]
    XCTAssertTrue(question.waitForExistence(timeout: 10))
    question.tap()

    let localAnswer = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "On-device fixture response")).firstMatch
    XCTAssertTrue(localAnswer.waitForExistence(timeout: 5))
    let conversations = app.buttons["Conversations"]
    conversations.tap()

    let newConversation = app.buttons["New Conversation"]
    XCTAssertTrue(newConversation.waitForExistence(timeout: 5))
    let rows = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "assistant-history-"))
    let local = rows.matching(NSPredicate(format: "label CONTAINS %@", "Where did my money go?")).firstMatch
    let server = rows.matching(NSPredicate(format: "label CONTAINS %@", "Budget planning")).firstMatch
    XCTAssertTrue(local.waitForExistence(timeout: 5))
    XCTAssertTrue(server.waitForExistence(timeout: 5))
    XCTAssertLessThan(newConversation.frame.midY, local.frame.midY)
    XCTAssertLessThan(newConversation.frame.midY, server.frame.midY)
    try app.performAccessibilityAudit(for: .sufficientElementDescription)

    newConversation.tap()
    XCTAssertTrue(localAnswer.waitForNonExistence(timeout: 5))
    conversations.tap()
    XCTAssertTrue(local.waitForExistence(timeout: 5))
    local.tap()
    XCTAssertTrue(localAnswer.waitForExistence(timeout: 5))

    conversations.tap()
    XCTAssertTrue(server.waitForExistence(timeout: 5))
    server.tap()
    let serverAnswer = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Saved Sure budget response")).firstMatch
    XCTAssertTrue(serverAnswer.waitForExistence(timeout: 5))
  }
}
