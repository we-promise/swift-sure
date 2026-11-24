struct AssistantConversationDetail: Codable, Sendable {
  var conversation: AssistantConversation
  var messages: [AssistantMessage]
}
