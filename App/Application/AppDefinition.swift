import SwiftUI

@main
struct AppDefinition: App {
  private let root = ApplicationRoot()

  #if os(iOS)
  @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
  #endif

  var body: some Scene {
    WindowGroup {
      // Unit test hosts must not construct live services as a side effect of launch.
      if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil || NSClassFromString("XCTestCase") != nil {
        Color.clear
      } else {
        ApplicationView(assembly: root.assembly) { notifications, gate in
          #if os(iOS)
          appDelegate.notificationEventHandler = notifications
          appDelegate.canReceiveBackendNotifications = { gate.isAllowed }
          #endif
        }
      }
    }
  }
}

@MainActor
private final class ApplicationRoot {
  // Resolve on the first window launch and reuse the same connection in later windows.
  lazy var assembly = ApplicationAssembly()
}
