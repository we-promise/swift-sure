import SwiftUI

struct ApplicationView: View {
  @Environment(\.scenePhase) private var scenePhase
  @State private var firstRun: FirstRunStore?
  private let assembly: ApplicationAssembly

  init(
    assembly: ApplicationAssembly,
    configureNotifications: (NotificationManager, BackendAccessGate) -> Void
  ) {
    self.assembly = assembly
    _firstRun = State(initialValue: assembly.makeFirstRun())
    configureNotifications(assembly.notifications, assembly.connection.accessGate)
  }

  var body: some View {
    let services = assembly.connection
    let connection = services.connection
    let finance = assembly.finance

    ContentView(
      subscriptionAccess: services.subscriptionAccess,
      connection: connection,
      analytics: assembly.analytics,
      telemetryBuildDetails: assembly.telemetryBuildDetails,
      diagnostics: assembly.diagnostics,
      financeData: finance.financeData,
      spendingComparison: finance.spendingComparison,
      appleCardConnection: finance.appleCardConnection,
      firstRun: firstRun,
      financeKitSync: finance.financeKitSync,
      notificationManager: assembly.notifications,
      remoteAssistant: finance.remoteAssistant,
      localAssistantHistory: assembly.localAssistantHistory,
      transactionHistoryStoreFactory: finance.transactionHistoryStoreFactory,
      localTransactionHistoryStoreFactory: finance.localTransactionHistoryStoreFactory,
      makeAssistantMessageID: { UUID() },
      now: { .now }
    )
    .task(id: scenePhase) {
      guard scenePhase == .active else { return }
      await finance.appleCardConnection.refresh()
    }
    .onChange(of: scenePhase) { _, phase in
      if phase == .active {
        Task {
          await services.subscriptionAccess.refresh()
          #if os(iOS) && FINANCEKIT_ENABLED
          if services.subscriptionAccess.hasAccess { await finance.financeKitSync.syncOnForeground() }
          #endif
        }
      }
    }
    .onChange(of: connection.status) { _, status in
      if status == .notConnected && connection.isSignedOut {
        firstRun = assembly.makeFirstRun()
      }
    }
    .onChange(of: services.subscriptionAccess.hasAccess, initial: true) { _, allowed in
      assembly.backendAccessChanged(allowed)
    }
    .onOpenURL { url in
      guard services.subscriptionAccess.hasAccess || connection.isDemoServer else { return }
      services.mobileSSOService.handleOpenURL(url)
    }
  }
}
