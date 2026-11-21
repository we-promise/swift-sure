import Foundation

struct FinanceKitSyncTracking: Sendable {
  var capture: (@MainActor @Sendable (FinanceKitSyncStage) -> Void)?

  func record(
    isolation: isolated (any Actor)? = #isolation,
    _ sync: () async throws -> FinanceKitSyncOutcome
  ) async rethrows -> FinanceKitSyncOutcome {
    guard let capture, !Task.isCancelled else { return try await sync() }
    await capture(.started)
    do {
      let outcome = try await sync()
      if !Task.isCancelled {
        switch outcome {
        case .uploaded, .noChanges: await capture(.succeeded)
        case .repairRequired: await capture(.failed)
        case .busy, .notConfigured: break
        }
      }
      return outcome
    } catch {
      switch error {
      case FinanceKitSyncError.importPending, FinanceKitProcessLockError.busy, is CancellationError:
        break
      default:
        if !Task.isCancelled, (error as? URLError)?.code != .cancelled {
          await capture(.failed)
        }
      }
      throw error
    }
  }
}
