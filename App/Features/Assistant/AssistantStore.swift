import Foundation
import Observation

@MainActor
@Observable
final class AssistantStore {
  var messages: [AssistantMessage]
  private(set) var conversations: [AssistantConversation] = []
  private(set) var localConversations: [AssistantConversationDetail] = []
  var draft = ""
  var isResponding = false
  var isLoadingConversations = false
  var isLoadingLocalConversations = false
  var isLoadingConversation = false
  var errorMessage: String?
  var conversationErrorMessage: String?
  var historyErrorMessage: String?
  var localHistoryLoadFailed = false
  private var chatID: UUID?
  private(set) var selectedConversationID: UUID?
  private(set) var selectedLocalConversationID: UUID?
  private var activeDestination: AssistantDestination?
  private var conversationLoadGeneration = 0
  private var selectionGeneration = 0
  private let connection: any ConnectionStateProviding
  private let sessionGeneration: Int
  private let remoteAssistant: any RemoteAssistantClient
  private let localAssistant: any LocalAssistantResponding
  private let localHistory: any LocalAssistantHistory
  private let historyScope: () -> String?
  private let makeID: () -> UUID
  private let now: () -> Date

  init(
    connection: any ConnectionStateProviding,
    remoteAssistant: any RemoteAssistantClient,
    localAssistant: any LocalAssistantResponding,
    localHistory: any LocalAssistantHistory,
    historyScope: @escaping () -> String?,
    makeID: @escaping () -> UUID,
    now: @escaping () -> Date
  ) {
    self.connection = connection
    sessionGeneration = connection.sessionGeneration
    self.remoteAssistant = remoteAssistant
    self.localAssistant = localAssistant
    self.localHistory = localHistory
    self.historyScope = historyScope
    self.makeID = makeID
    self.now = now
    messages = [
      AssistantMessage(
        id: makeID(),
        role: .assistant,
        content: Self.introduction,
        date: now()
      )
    ]
  }

  // The view gets a new store when the shared connection changes. The old
  // store must stop accepting work before SwiftUI has replaced it in every window.
  private var isCurrentSession: Bool { sessionGeneration == connection.sessionGeneration }

  func refreshHistory() async {
    async let local: Void = refreshLocalConversations()
    async let remote: Void = refreshConversations()
    _ = await (local, remote)
  }

  func refreshLocalConversations() async {
    guard isCurrentSession, !isLoadingLocalConversations, !isResponding else { return }
    let scope = historyScope()
    isLoadingLocalConversations = true
    localHistoryLoadFailed = false
    defer { isLoadingLocalConversations = false }
    do {
      var details = try await localHistory.load(scope: scope)
      if scope != nil {
        let scopedIDs = Set(details.map(\.conversation.id))
        let standalone = try await localHistory.load(scope: nil)
        details.append(contentsOf: standalone.filter { !scopedIDs.contains($0.conversation.id) })
      }
      guard !Task.isCancelled, !isResponding, isCurrentSession else { return }
      localConversations = details.sorted { $0.conversation.updatedAt > $1.conversation.updatedAt }
    } catch {
      guard !Self.isCancellation(error), isCurrentSession else { return }
      localHistoryLoadFailed = true
    }
  }

  func refreshConversations() async {
    guard isCurrentSession else { return }
    conversationLoadGeneration += 1
    let requestGeneration = conversationLoadGeneration
    guard connection.isConfigured else {
      conversations = []
      historyErrorMessage = nil
      isLoadingConversations = false
      return
    }

    isLoadingConversations = true
    historyErrorMessage = nil
    defer {
      if requestGeneration == conversationLoadGeneration {
        isLoadingConversations = false
      }
    }
    do {
      let fetched = try await remoteAssistant.fetchConversations()
      guard !Task.isCancelled, requestGeneration == conversationLoadGeneration, isCurrentSession else { return }
      conversations = fetched.sorted { $0.updatedAt > $1.updatedAt }
    } catch {
      guard !Self.isCancellation(error), requestGeneration == conversationLoadGeneration, isCurrentSession else { return }
      historyErrorMessage = error.localizedDescription
    }
  }

  func selectConversation(_ conversation: AssistantConversation) async {
    guard isCurrentSession, connection.isConfigured, !isResponding else { return }
    selectionGeneration += 1
    let requestGeneration = selectionGeneration
    isLoadingConversation = true
    conversationErrorMessage = nil
    errorMessage = nil

    do {
      let detail = try await remoteAssistant.fetchConversation(id: conversation.id)
      guard requestGeneration == selectionGeneration, isCurrentSession else { return }
      activeDestination = .sureServer
      chatID = detail.conversation.id
      selectedConversationID = detail.conversation.id
      selectedLocalConversationID = nil
      draft = ""
      if detail.messages.isEmpty {
        resetMessages()
      } else {
        messages = detail.messages
      }
      replaceConversation(detail.conversation)
    } catch {
      guard requestGeneration == selectionGeneration, isCurrentSession else { return }
      conversationErrorMessage = error.localizedDescription
    }
    if requestGeneration == selectionGeneration {
      isLoadingConversation = false
    }
  }

  func selectLocalConversation(_ detail: AssistantConversationDetail) {
    guard isCurrentSession, !isResponding else { return }
    startNewConversation()
    activeDestination = .localModel
    selectedLocalConversationID = detail.conversation.id
    messages.append(contentsOf: detail.messages)
  }

  func startNewConversation() {
    guard isCurrentSession, !isResponding else { return }
    selectionGeneration += 1
    activeDestination = nil
    chatID = nil
    selectedConversationID = nil
    selectedLocalConversationID = nil
    draft = ""
    errorMessage = nil
    conversationErrorMessage = nil
    isLoadingConversation = false
    resetMessages()
  }

  func send(to destination: AssistantDestination) async {
    let prompt = draft.trimmingCharacters(in: .whitespacesAndNewlines)
    guard isCurrentSession, !prompt.isEmpty, !isResponding, !isLoadingConversation else { return }
    if let activeDestination, activeDestination != destination {
      // Each destination owns its own transcript, so a local history file
      // never saves a Sure server conversation or feeds it back to the model.
      startNewConversation()
    }
    activeDestination = destination
    let scope = historyScope()
    let conversation = messages
    draft = ""
    messages.append(makeMessage(role: .user, content: prompt))
    isResponding = true
    errorMessage = nil
    let localLease = destination == .localModel ? await localHistory.lease() : nil
    defer { isResponding = false }

    do {
      guard isCurrentSession else { throw CancellationError() }
      let response: String
      switch destination {
      case .localModel:
        response = try await localAssistant.respond(to: prompt, conversation: conversation)
      case .sureServer:
        conversationLoadGeneration += 1
        isLoadingConversations = false
        response = try await sendToSure(prompt)
      }
      guard isCurrentSession else { throw CancellationError() }
      messages.append(makeMessage(role: .assistant, content: response))
    } catch {
      if !Self.isCancellation(error), isCurrentSession {
        errorMessage = error.localizedDescription
      }
    }
    if let localLease, !Task.isCancelled, isCurrentSession {
      await saveLocalConversation(scope: scope, lease: localLease)
    }
  }

  private func saveLocalConversation(scope: String?, lease: Int) async {
    // Skip the static greeting so it doesn't become part of the saved transcript.
    let transcript = Array(messages.dropFirst())
    guard let first = transcript.first, let last = transcript.last else { return }
    let summary = AssistantConversation(
      id: selectedLocalConversationID ?? first.id,
      title: conversationTitle(for: first.content),
      updatedAt: last.date
    )
    let detail = AssistantConversationDetail(conversation: summary, messages: transcript)
    selectedLocalConversationID = summary.id
    localConversations.removeAll { $0.conversation.id == summary.id }
    localConversations.insert(detail, at: 0)
    do {
      try await localHistory.save(detail, scope: scope, lease: lease)
    } catch {
      if !Self.isCancellation(error), isCurrentSession {
        errorMessage = String(localized: "Couldn’t save this conversation on this device.")
      }
    }
  }

  private func sendToSure(_ prompt: String) async throws -> String {
    guard isCurrentSession, connection.isConfigured else {
      throw SureAPIError.unauthorized
    }

    let identifier: UUID
    if let chatID {
      identifier = chatID
    } else {
      let title = conversationTitle(for: prompt)
      identifier = try await remoteAssistant.createChat(title: title)
      guard isCurrentSession, connection.isConfigured else {
        throw CancellationError()
      }
      selectedConversationID = identifier
      replaceConversation(
        AssistantConversation(id: identifier, title: title, updatedAt: now())
      )
    }
    chatID = identifier
    let response = try await remoteAssistant.sendMessage(prompt, chatID: identifier)
    guard isCurrentSession, connection.isConfigured else {
      chatID = nil
      throw CancellationError()
    }
    if let index = conversations.firstIndex(where: { $0.id == identifier }) {
      var conversation = conversations.remove(at: index)
      conversation.updatedAt = now()
      conversations.insert(conversation, at: 0)
    }
    return response
  }

  private func resetMessages() {
    messages = initialMessages()
  }

  private func initialMessages() -> [AssistantMessage] {
    [makeMessage(role: .assistant, content: Self.introduction)]
  }

  private func replaceConversation(_ conversation: AssistantConversation) {
    if let index = conversations.firstIndex(where: { $0.id == conversation.id }) {
      conversations[index] = conversation
    } else {
      conversations.append(conversation)
    }
    conversations.sort { $0.updatedAt > $1.updatedAt }
  }

  private func conversationTitle(for prompt: String) -> String {
    AssistantConversation.abridgedTitle(prompt, limit: 80)
  }

  private func makeMessage(role: AssistantRole, content: String) -> AssistantMessage {
    AssistantMessage(id: makeID(), role: role, content: content, date: now())
  }

  private static func isCancellation(_ error: Error) -> Bool {
    if error is CancellationError || Task.isCancelled { return true }
    return (error as? URLError)?.code == .cancelled
  }

  private static let introduction = "Here you will be able to ask me anything about your money. I can explain spending, compare accounts, find recurring costs, and help you plan."
}
