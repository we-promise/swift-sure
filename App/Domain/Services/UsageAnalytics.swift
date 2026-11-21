/// Closed event vocabulary: no financial data, identifiers, URLs, or free-form text.
@MainActor
protocol UsageAnalytics: AnyObject {
  func capture(_ event: UsageEvent)
  func resetIdentity()
}

enum UsageEvent: Equatable {
  case appOpened
  case screenViewed(UsageScreen)
  case financeKitSync(FinanceKitSyncStage)
}

enum UsageScreen: String, CaseIterable {
  case overview, assistant, accounts, budget
  case connectionSettings = "connection_settings"
  case signIn = "sign_in"
  case onboarding
}
