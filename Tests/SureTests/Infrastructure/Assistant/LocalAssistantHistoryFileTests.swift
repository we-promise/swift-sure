import Foundation
import Testing
@testable import Sure

@Suite("On-device Assistant history file")
struct LocalAssistantHistoryFileTests {
  @Test("History survives reopening, stays scoped, and erasure invalidates pending writes")
  func persistenceAndErasure() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let history = LocalAssistantHistoryFile(directory: directory)
    let conversation = AssistantConversation(
      id: try #require(UUID(uuidString: "00000000-0000-4000-8000-000000000001")),
      title: "Ask about spending",
      updatedAt: Date(timeIntervalSince1970: 1_700_000_000)
    )
    let detail = AssistantConversationDetail(conversation: conversation, messages: [
      AssistantMessage(id: conversation.id, role: .user, content: "Ask about spending", date: conversation.updatedAt)
    ])
    let lease = await history.lease()
    #expect(try await history.load(scope: nil).isEmpty)
    try await history.save(detail, scope: "connection-one", lease: lease)

    let reopened = LocalAssistantHistoryFile(directory: directory)
    let saved = try await reopened.load(scope: "connection-one")
    #expect(saved.map(\.conversation) == [conversation])
    #expect(saved.first?.messages.map(\.content) == ["Ask about spending"])
    #expect(try await reopened.load(scope: "connection-two").isEmpty)
    #expect(try await reopened.load(scope: nil).isEmpty)

    try await history.removeAll()
    await #expect(throws: CancellationError.self) {
      try await history.save(detail, scope: "connection-one", lease: lease)
    }
    #expect(try await reopened.load(scope: "connection-one").isEmpty)
  }
}
