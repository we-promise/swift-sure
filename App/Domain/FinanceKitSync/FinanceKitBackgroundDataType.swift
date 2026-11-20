enum FinanceKitBackgroundDataType: String, Codable, CaseIterable, Hashable, Sendable {
  case accounts
  case accountBalances = "account_balances"
  case transactions

  /// An empty set means a full history collection to the sync runner. A
  /// background callback with no recognized change types must not request that.
  static func shouldRunBackgroundSync(for changedTypes: Set<Self>) -> Bool {
    !changedTypes.isEmpty
  }
}
