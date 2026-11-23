protocol LocalAssistantHistory: Sendable {
  func load(scope: String?) async throws -> [AssistantConversationDetail]
  func lease() async -> Int
  func save(_ detail: AssistantConversationDetail, scope: String?, lease: Int) async throws
}
