import CryptoKit
import Foundation

actor LocalAssistantHistoryFile: LocalAssistantHistory {
  private let directory: URL
  private var generation = 0

  init(directory: URL) {
    self.directory = directory
  }

  func load(scope: String?) throws -> [AssistantConversationDetail] {
    do {
      let data = try Data(contentsOf: file(for: scope))
      return try JSONDecoder().decode([AssistantConversationDetail].self, from: data)
    } catch CocoaError.fileReadNoSuchFile {
      return []
    }
  }

  func lease() -> Int { generation }

  func save(_ detail: AssistantConversationDetail, scope: String?, lease: Int) throws {
    guard lease == generation else { throw CancellationError() }
    var details = try load(scope: scope)
    details.removeAll { $0.conversation.id == detail.conversation.id }
    details.insert(detail, at: 0)
    try ProtectedLocalFileWriter().write(JSONEncoder().encode(details), to: file(for: scope))
  }

  func removeAll() throws {
    // A reply that started before logout must not recreate erased history.
    generation &+= 1
    if FileManager.default.fileExists(atPath: directory.path) {
      try FileManager.default.removeItem(at: directory)
    }
  }

  private func file(for scope: String?) -> URL {
    let name = scope.map { SHA256.hash(data: Data($0.utf8)).map { String(format: "%02x", $0) }.joined() }
    return directory.appendingPathComponent(name ?? "on-device").appendingPathExtension("json")
  }
}
