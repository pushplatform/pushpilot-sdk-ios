import XCTest
@testable import PushPlatformSDK

final class UniversalTransportTests: XCTestCase {
    override func setUp() {
        super.setUp()
        Configuration.shared.configure(apiKey: "", serverURL: "https://test.example", environment: .production, debugMode: false)
    }
    override func tearDown() { Configuration.shared.reset(); super.tearDown() }

    func testBothEarlyTokensFlushThroughIndependentDelegates() {
        let client = RecordingTokenClient()
        let installation = MockInstallationManager()
        installation.installationID = nil
        let registry = TokenRegistry(apiClient: client, installationManager: installation, storage: InMemoryStorage())
        let alert = MockTokenRegistryDelegate(), voip = MockTokenRegistryDelegate()
        var results: [String] = []
        alert.onRegisterToken = { results.append($0) }
        voip.onRegisterToken = { results.append($0) }
        registry.setDelegate(alert, for: "apns")
        registry.setDelegate(voip, for: "apns_voip")
        registry.registerToken(Data([1]), provider: "apns", environment: "")
        registry.registerToken(Data([2]), provider: "apns_voip", environment: "")
        registry.registerToken(Data([3]), provider: "apns_voip", environment: "")
        XCTAssertTrue(client.calls.isEmpty)
        installation.installationID = UUID()
        registry.flushPendingRegistrations()
        XCTAssertEqual(Set(client.calls.map { $0.provider }), Set(["apns", "apns_voip"]))
        XCTAssertEqual(client.calls.first { $0.provider == "apns_voip" }?.token, "03")
        XCTAssertEqual(Set(results), Set(["apns", "apns_voip"]))
        registry.flushPendingRegistrations()
        XCTAssertEqual(client.calls.count, 2)
    }

    func testStaleTokenCallbackCannotReplaceLatestSubscription() {
        let client = RecordingTokenClient()
        client.deferResponses = true
        let installation = MockInstallationManager()
        installation.installationID = UUID()
        let storage = InMemoryStorage()
        let registry = TokenRegistry(apiClient: client, installationManager: installation, storage: storage)
        registry.registerToken(Data([1]), provider: "apns", environment: "")
        registry.registerToken(Data([2]), provider: "apns", environment: "")
        XCTAssertEqual(client.calls.count, 1, "token rotation must not race an older backend write")
        client.responses[0](.success("stale"))
        XCTAssertEqual(client.calls.count, 2)
        client.responses[1](.success("latest"))
        XCTAssertEqual(storage.getSubscriptionID(), "latest")
    }

    func testVoIPPayloadIsForwardedToNativeOwnerWithoutSchemaAssumptions() {
        let installation = MockInstallationManager()
        installation.installationID = UUID()
        let registry = TokenRegistry(apiClient: RecordingTokenClient(), installationManager: installation)
        var received: [AnyHashable: Any] = [:]
        var completed = 0
        let manager = PushKitManager(tokenRegistry: registry) { payload, completion in
            received = payload
            completion()
        }
        manager.handleIncomingPush(["custom_schema": "customer-defined", "number": 42]) { completed += 1 }
        XCTAssertEqual(received["custom_schema"] as? String, "customer-defined")
        XCTAssertEqual(received["number"] as? Int, 42)
        XCTAssertEqual(completed, 1)
    }

    func testColdStartOpenWaitsForDelegateAndIsReplayedOnce() {
        let handler = NotificationDelegate(deduplicationCache: DeduplicationCache())
        let parsed = NotificationParser.parse(["notification_id": "message", "room": "123"])
        handler.deliverOpen(parsed, action: nil, context: NotificationContext(isForeground: false))
        let receiver = MockPushPlatformDelegate()
        handler.appDelegate = receiver
        handler.appDelegate = receiver
        XCTAssertEqual(receiver.openedNotifications.count, 1)
    }
    func testSilentDeliveryIsBufferedAndDeduplicatedBeforeTheApplicationDelegateExists() {
        let handler = NotificationDelegate(deduplicationCache: DeduplicationCache())
        let data: [AnyHashable: Any] = ["notification_id": "silent", "arbitrary_key": ["count": 7], "aps": ["content-available": 1]]
        handler.handleBackground(data)
        handler.handleBackground(data)
        let receiver = MockPushPlatformDelegate()
        handler.appDelegate = receiver
        handler.appDelegate = receiver
        XCTAssertEqual(receiver.receivedNotifications.count, 1)
        XCTAssertFalse(receiver.receivedNotifications[0].context.isForeground)
        XCTAssertEqual((receiver.receivedNotifications[0].notification.customData["arbitrary_key"] as? [String: Int])?["count"], 7)
    }

    func testNewestAccountChangeRunsAfterTheOldWriteAndSupersedesQueuedChanges() {
        let client = RecordingAccountClient()
        let installation = MockInstallationManager()
        installation.installationID = UUID()
        let manager = UserManager(apiClient: client, installationManager: installation)
        var finished = 0
        manager.login(userID: "old") { result in if case .success = result { XCTFail("superseded login") }; finished += 1 }
        manager.login(userID: "intermediate") { result in if case .success = result { XCTFail("superseded login") }; finished += 1 }
        manager.logout { result in if case .failure = result { XCTFail("logout must succeed") }; finished += 1 }
        XCTAssertEqual(client.accounts, ["old"])
        XCTAssertEqual(finished, 1)
        client.responses[0](.success(()))
        XCTAssertEqual(client.accounts, ["old", "<logout>"])
        client.responses[1](.success(()))
        XCTAssertEqual(finished, 3)
    }

}

private final class RecordingTokenClient: APIClient {
    var calls: [Subscription] = []
    var responses: [(Result<String?, SDKError>) -> Void] = []
    var deferResponses = false
    override func createSubscription(installationID: UUID, subscription: Subscription, completion: @escaping (Result<String?, SDKError>) -> Void) {
        calls.append(subscription)
        responses.append(completion)
        if !deferResponses { completion(.success(subscription.provider + "-subscription")) }
    }
}

private final class RecordingAccountClient: APIClient {
    var accounts: [String] = []
    var responses: [(Result<Void, SDKError>) -> Void] = []
    override func loginUser(installationID: UUID, externalUserID: String, metadata: [String: Any]? = nil, completion: @escaping (Result<Void, SDKError>) -> Void) {
        accounts.append(externalUserID); responses.append(completion)
    }
    override func logoutUser(installationID: UUID, completion: @escaping (Result<Void, SDKError>) -> Void) {
        accounts.append("<logout>"); responses.append(completion)
    }
}
