#if os(iOS)
import PostHog

@MainActor
final class PostHogAnalyticsClient: AnalyticsClient {
  private nonisolated static let screenNameProperty = "$screen_name"
  private let configuration: PostHogConfiguration
  private var sdk: PostHogSDK?

  init(configuration: PostHogConfiguration) {
    self.configuration = configuration
  }

  func start() {
    guard sdk == nil else { return }
    let config = Self.makeConfig(configuration)
    sdk = PostHogSDK.with(config)
    sdk?.optIn()
  }

  static func makeConfig(_ configuration: PostHogConfiguration) -> PostHogConfig {
    let config = PostHogConfig(projectToken: configuration.projectToken, host: configuration.host.absoluteString)
    // Explicit events only. Never inspect finance UI, network requests, or assistant text.
    config.captureApplicationLifecycleEvents = false
    config.captureScreenViews = false
    config.captureElementInteractions = false
    config.enableSwizzling = false
    config.sessionReplay = false
    config.surveys = false
    config.rageClickConfig.enabled = false
    config.preloadFeatureFlags = false
    config.sendFeatureFlagEvent = false
    config.setDefaultPersonProperties = false
    config.personProfiles = .never
    config.errorTrackingConfig.autoCapture = false
    config.debug = false
    config.maxQueueSize = 100
    config.setBeforeSend { event in
      let screenName = event.properties[Self.screenNameProperty] as? String
      guard Self.allowsCapture(of: event.event, screenName: screenName) else { return nil }
      return event
    }
    return config
  }

  func capture(_ event: UsageEvent) {
    let payload = Self.payload(for: event)
    sdk?.capture(payload.name, properties: payload.properties)
  }

  func resetIdentity() {
    sdk?.reset()
  }

  func stop() {
    sdk?.optOut()
    sdk?.close()
    sdk = nil
  }

  static func payload(for event: UsageEvent) -> (name: String, properties: [String: String]) {
    switch event {
    case .appOpened:
      (EventName.appOpened.rawValue, [:])
    case .screenViewed(let screen):
      (EventName.screen.rawValue, [screenNameProperty: screen.rawValue])
    }
  }

  nonisolated static func allowsCapture(of name: String, screenName: String?) -> Bool {
    switch EventName(rawValue: name) {
    case .appOpened: true
    case .screen: screenName.flatMap(UsageScreen.init(rawValue:)) != nil
    case nil: false
    }
  }

  private enum EventName: String {
    case appOpened = "app_opened"
    case screen = "$screen"
  }
}
#endif
