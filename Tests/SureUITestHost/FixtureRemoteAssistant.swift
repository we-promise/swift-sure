import Foundation

struct FixtureRemoteAssistant: RemoteAssistantClient {
  private let conversation = AssistantConversation(
    id: UUID(uuidString: "00000000-0000-4000-8000-000000000701")!,
    title: "Budget planning",
    updatedAt: Date(timeIntervalSince1970: 1_700_000_000)
  )

  func fetchConversations() async throws -> [AssistantConversation] { [conversation] }

  func fetchConversation(id: UUID) async throws -> AssistantConversationDetail {
    guard id == conversation.id else { throw CocoaError(.fileReadNoSuchFile) }
    return AssistantConversationDetail(conversation: conversation, messages: [
      AssistantMessage(id: id, role: .assistant, content: "Saved Sure budget response", date: conversation.updatedAt)
    ])
  }

  func createChat(title: String) async throws -> UUID { conversation.id }
  func sendMessage(_ content: String, chatID: UUID) async throws -> String { "Sure fixture response" }
}

struct FixtureLocalAssistant: LocalAssistantResponding {
  func respond(to prompt: String, conversation: [AssistantMessage]) async throws -> String { "On-device fixture response" }
}

actor FixtureAssistantHistory: LocalAssistantHistory {
  private var conversations: [UUID: AssistantConversationDetail] = [:]

  func load(scope: String?) -> [AssistantConversationDetail] { Array(conversations.values) }
  func lease() -> Int { 0 }
  func save(_ detail: AssistantConversationDetail, scope: String?, lease: Int) { conversations[detail.conversation.id] = detail }
}
