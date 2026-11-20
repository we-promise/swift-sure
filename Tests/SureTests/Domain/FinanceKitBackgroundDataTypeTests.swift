import Testing
@testable import Sure

@Suite("FinanceKit background delivery trigger")
struct FinanceKitBackgroundDataTypeTests {
  @Test("An empty recognized type set never becomes a full history request")
  func unknownOnlyDeliveryDoesNotSyncEverything() {
    #expect(!FinanceKitBackgroundDataType.shouldRunBackgroundSync(for: []))
  }

  @Test("A recognized change type requests a targeted sync")
  func recognizedDeliveryRuns() {
    #expect(FinanceKitBackgroundDataType.shouldRunBackgroundSync(for: [.transactions]))
  }
}
