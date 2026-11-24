import Foundation

@MainActor
final class ApplicationAssembly {
  let connection: ConnectionAssembly
  let finance: FinanceAssembly
  let notifications: NotificationManager
  let analytics: AnalyticsStore
  let diagnostics: DiagnosticsStore
  let telemetryBuildDetails: TelemetryBuildDetails
  let localAssistantHistory: LocalAssistantHistoryFile

  private let subscriptionMonitoring: Task<Void, Never>
  private var lastBackendAccess: Bool?

  init() {
    let analytics = AnalyticsAssembly.make()
    let diagnostics = DiagnosticsAssembly.make()
    let connection = ConnectionAssembly()
    let devices = DeviceAssembly(connection: connection)
    let finance = FinanceAssembly(
      connection: connection, analytics: analytics, diagnostics: diagnostics, syncInsights: devices.syncInsights
    )
    let localAssistantHistory = LocalAssistantHistoryFile(
      directory: URL.applicationSupportDirectory.appending(path: "am.sure.insights/assistant-history")
    )
    let lifecycle = connection.lifecycle
    lifecycle.resetAppData = { try ApplicationDataResetter().reset() }
    lifecycle.clearAssistantHistory = { try await localAssistantHistory.removeAll() }
    lifecycle.analytics = analytics
    lifecycle.diagnostics = diagnostics
    lifecycle.notificationLifecycle = devices.notifications
    lifecycle.financeData = finance.financeData
    lifecycle.financeKitSync = finance.financeKitSync
    lifecycle.spendingComparison = finance.spendingComparison
    lifecycle.appleCardConnection = finance.appleCardConnection
    lifecycle.financeKitPublisher = finance.financeKitPublisher
    lifecycle.transactionHistoryFactories = [finance.transactionHistoryStoreFactory, finance.localTransactionHistoryStoreFactory]
    lifecycle.restoreInitialState(isExplicitlySignedOut: connection.initialState.isExplicitlySignedOut)

    self.connection = connection
    self.finance = finance
    self.analytics = analytics
    self.diagnostics = diagnostics
    self.localAssistantHistory = localAssistantHistory
    notifications = devices.notifications
    telemetryBuildDetails = TelemetryBuildDetails(
      postHogProjectToken: PostHogConfiguration(bundle: .main)?.projectToken,
      sentryDSN: SentryDiagnosticsConfiguration(bundle: .main)?.dsn
    )
    devices.activate()
    let subscriptionAccess = connection.subscriptionAccess
    subscriptionMonitoring = Task { await subscriptionAccess.monitor() }
  }

  deinit {
    subscriptionMonitoring.cancel()
  }

  func makeFirstRun() -> FirstRunStore? {
    FirstRunAssembly(connection: connection, finance: finance).store
  }

  func backendAccessChanged(_ allowed: Bool) {
    // Every window observes the same entitlement. Apply each transition once.
    guard allowed != lastBackendAccess else { return }
    lastBackendAccess = allowed
    if allowed {
      Task {
        await finance.financeKitPublisher.resumeIfConfigured()
        await finance.financeData.refresh()
        await notifications.applicationDidFinishLaunching()
        await notifications.didConnect()
      }
    } else {
      if !SureDemoServer.matchesBaseURL(connection.connection.connectedServerURL) {
        finance.financeData.suspendSync()
      }
      if !connection.connection.isDemoServer {
        connection.connection.suspendAuthentication()
        connection.oauthService.cancelAuthentication()
        connection.mobileSSOService.cancelAuthentication()
      }
    }
  }
}
