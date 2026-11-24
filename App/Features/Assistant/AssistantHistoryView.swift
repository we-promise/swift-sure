import SwiftUI

struct AssistantHistoryView: View {
  @Environment(\.dismiss) private var dismiss
  var store: AssistantStore
  var isConnected: Bool

  var body: some View {
    NavigationStack {
      List {
        Section {
          Button("New Conversation", systemImage: "square.and.pencil") {
            store.startNewConversation()
            dismiss()
          }
          .disabled(store.isResponding)
        }
        Section("On This Device") {
          ForEach(store.localConversations, id: \.conversation.id) { detail in
            conversationRow(detail.conversation, systemImage: "apple.intelligence",
              selected: detail.conversation.id == store.selectedLocalConversationID) {
              store.selectLocalConversation(detail)
              dismiss()
            }
          }
          if store.isLoadingLocalConversations {
            ProgressView("Loading on-device conversations…")
          } else if store.localHistoryLoadFailed {
            Text("Couldn’t load on-device conversations.").foregroundStyle(.secondary)
            Button("Try Again", systemImage: "arrow.clockwise") {
              Task { await store.refreshLocalConversations() }
            }
          } else if store.localConversations.isEmpty {
            Text("No on-device conversations yet").foregroundStyle(.secondary)
          }
        }
        Section("Sure Server") {
          ForEach(store.conversations) { conversation in
            conversationRow(conversation, systemImage: "bubble.left", selected: conversation.id == store.selectedConversationID) {
              dismiss()
              Task { await store.selectConversation(conversation) }
            }
          }
          if store.isLoadingConversations {
            ProgressView("Loading Sure conversations…")
          } else if let error = store.historyErrorMessage {
            Text(error).foregroundStyle(.secondary)
            Button("Try Again", systemImage: "arrow.clockwise") {
              Task { await store.refreshConversations() }
            }
          } else if !isConnected {
            Text("Connect to Sure to see server conversations").foregroundStyle(.secondary)
          } else if store.conversations.isEmpty {
            Text("No Sure conversations yet").foregroundStyle(.secondary)
          }
        }
      }
      #if os(iOS)
      .listStyle(.insetGrouped)
      .navigationBarTitleDisplayMode(.inline)
      #endif
      .navigationTitle("Conversations")
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Done") { dismiss() }
        }
      }
    }
    #if os(macOS)
    .frame(minWidth: 380, idealWidth: 460, minHeight: 340, idealHeight: 500)
    #endif
    .task { await store.refreshHistory() }
  }

  private func conversationRow(
    _ conversation: AssistantConversation,
    systemImage: String,
    selected: Bool,
    action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      HStack {
        Image(systemName: systemImage)
          .frame(minWidth: 24)
          .accessibilityHidden(true)
        VStack(alignment: .leading, spacing: 4) {
          Text(conversation.title.isEmpty ? String(localized: "Untitled conversation") : conversation.title)
            .foregroundStyle(.primary)
            .lineLimit(2)
          Text(conversation.updatedAt, format: .dateTime.year().month().day())
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        Spacer(minLength: 12)
        if selected {
          Image(systemName: "checkmark")
            .foregroundStyle(.tint)
            .accessibilityHidden(true)
        }
      }
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .disabled(store.isResponding || store.isLoadingConversation)
    .accessibilityIdentifier("assistant-history-\(conversation.id)")
    .accessibilityAddTraits(selected ? .isSelected : [])
  }
}
