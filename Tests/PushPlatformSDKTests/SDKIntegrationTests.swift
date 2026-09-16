import XCTest
@testable import PushPlatformSDK

/// Integration tests for Example App SDK integration
final class SDKIntegrationTests: XCTestCase {

    var mockDelegate: MockPushPlatformDelegate!

    override func setUp() {
        super.setUp()
        mockDelegate = MockPushPlatformDelegate()
        PushPlatform.shared.delegate = mockDelegate
    }

    override func tearDown() {
        PushPlatform.shared.delegate = nil
        mockDelegate = nil
        super.tearDown()
    }

    // MARK: - SDK Configuration Tests

    func testSDKConfiguration() {
        let expectation = self.expectation(description: "SDK configured")

        mockDelegate.onDidInitialize = { installationID in
            XCTAssertNotNil(installationID)
            expectation.fulfill()
        }

        PushPlatform.shared.configure(
            apiKey: "pk_test_integration_12345678",
            apiBaseURL: "https://api.test.example",
            environment: .development,
            debugMode: true
        )

        waitForExpectations(timeout: 2.0)
    }

    func testGetInstallationID() {
        PushPlatform.shared.configure(
            apiKey: "pk_test_get_id",
            apiBaseURL: "https://api.test.example",
            environment: .development,
            debugMode: false
        )

        let installationID = PushPlatform.shared.getInstallationID()
        XCTAssertNotNil(installationID)
    }

    // MARK: - User Management Tests

    func testLoginNotConfigured() {
        // Don't configure SDK
        let expectation = self.expectation(description: "Login fails when not configured")

        PushPlatform.shared.login(userID: "user_123") { result in
            switch result {
            case .success:
                XCTFail("Should fail when not configured")
            case .failure(let error):
                if case .notConfigured = error {
                    expectation.fulfill()
                } else {
                    XCTFail("Wrong error type: \(error)")
                }
            }
        }

        waitForExpectations(timeout: 1.0)
    }

    func testLogoutNotConfigured() {
        // Don't configure SDK
        let expectation = self.expectation(description: "Logout fails when not configured")

        PushPlatform.shared.logout { result in
            switch result {
            case .success:
                XCTFail("Should fail when not configured")
            case .failure(let error):
                if case .notConfigured = error {
                    expectation.fulfill()
                } else {
                    XCTFail("Wrong error type: \(error)")
                }
            }
        }

        waitForExpectations(timeout: 1.0)
    }

    // MARK: - Notification Parsing Tests

    func testNotificationParsingFromUserInfo() {
        let userInfo: [AnyHashable: Any] = [
            "aps": [
                "alert": [
                    "title": "Integration Test",
                    "body": "Test notification body"
                ],
                "badge": 5,
                "sound": "default"
            ],
            "event_id": "evt_integration_001",
            "custom_key": "custom_value"
        ]

        let parsed = NotificationParser.parse(userInfo)

        XCTAssertEqual(parsed.title, "Integration Test")
        XCTAssertEqual(parsed.body, "Test notification body")
        XCTAssertEqual(parsed.eventID, "evt_integration_001")
        XCTAssertEqual(parsed.badge, 5)
        XCTAssertEqual(parsed.sound, "default")
        XCTAssertEqual(parsed.customData["custom_key"] as? String, "custom_value")
    }

    func testNotificationParsingWithCallID() {
        let userInfo: [AnyHashable: Any] = [
            "aps": [
                "alert": [
                    "title": "Incoming Call",
                    "body": "John is calling"
                ]
            ],
            "call_id": "call_12345",
            "event_id": "evt_call_001"
        ]

        let parsed = NotificationParser.parse(userInfo)

        XCTAssertEqual(parsed.title, "Incoming Call")
        XCTAssertEqual(parsed.callID, "call_12345")
        XCTAssertEqual(parsed.eventID, "evt_call_001")
    }

    func testNotificationParsingEmptyPayload() {
        let userInfo: [AnyHashable: Any] = [:]

        let parsed = NotificationParser.parse(userInfo)

        XCTAssertNil(parsed.title)
        XCTAssertNil(parsed.body)
        XCTAssertNil(parsed.eventID)
        XCTAssertNil(parsed.badge)
        XCTAssertTrue(parsed.customData.isEmpty)
    }

    // MARK: - Deduplication Tests

    func testDeduplicationCache() {
        let cache = DeduplicationCache()
        let eventID = "evt_dedup_test"

        XCTAssertFalse(cache.contains(eventID))

        cache.add(eventID)
        XCTAssertTrue(cache.contains(eventID))

        // Adding again should still be present
        cache.add(eventID)
        XCTAssertTrue(cache.contains(eventID))
    }

    func testDeduplicationCacheWithMultipleEvents() {
        let cache = DeduplicationCache()

        cache.add("evt_001")
        cache.add("evt_002")
        cache.add("evt_003")

        XCTAssertTrue(cache.contains("evt_001"))
        XCTAssertTrue(cache.contains("evt_002"))
        XCTAssertTrue(cache.contains("evt_003"))
        XCTAssertFalse(cache.contains("evt_004"))
    }

    // MARK: - Notification Context Tests

    func testNotificationContextForeground() {
        let context = NotificationContext(isForeground: true)
        XCTAssertTrue(context.isForeground)
    }

    func testNotificationContextBackground() {
        let context = NotificationContext(isForeground: false)
        XCTAssertFalse(context.isForeground)
    }
}

