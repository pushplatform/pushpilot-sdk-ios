import XCTest
import UserNotifications
@testable import PushPlatformSDK

final class NotificationDelegateTests: XCTestCase {

    var notificationDelegate: NotificationDelegate!
    var deduplicationCache: DeduplicationCache!
    var mockAppDelegate: MockPushPlatformDelegate!
    var mockCenter: UNUserNotificationCenter!

    override func setUp() {
        super.setUp()
        deduplicationCache = DeduplicationCache()
        notificationDelegate = NotificationDelegate(deduplicationCache: deduplicationCache)
        mockAppDelegate = MockPushPlatformDelegate()
        notificationDelegate.appDelegate = mockAppDelegate
        mockCenter = UNUserNotificationCenter.current()
    }

    override func tearDown() {
        notificationDelegate = nil
        deduplicationCache = nil
        mockAppDelegate = nil
        mockCenter = nil
        super.tearDown()
    }

    // MARK: - Foreground Notifications

    func testForegroundNotificationWithEventID() {
        let userInfo: [AnyHashable: Any] = [
            "aps": [
                "alert": [
                    "title": "Test",
                    "body": "Foreground test"
                ]
            ],
            "event_id": "evt_fg_001"
        ]

        let notification = createMockNotification(userInfo: userInfo)
        let expectation = self.expectation(description: "foreground presentation")

        notificationDelegate.userNotificationCenter(mockCenter, willPresent: notification) { options in
            // Should show banner
            if #available(iOS 14.0, *) {
                XCTAssertTrue(options.contains(.banner))
            } else {
                XCTAssertTrue(options.contains(.alert))
            }
            XCTAssertTrue(options.contains(.sound))
            XCTAssertTrue(options.contains(.badge))
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1.0)

        // Verify callback fired
        XCTAssertEqual(mockAppDelegate.receivedNotifications.count, 1)
        let received = mockAppDelegate.receivedNotifications[0]
        XCTAssertEqual(received.notification.eventID, "evt_fg_001")
        XCTAssertTrue(received.context.isForeground)
    }

    func testForegroundNotificationDuplicate() {
        let userInfo: [AnyHashable: Any] = [
            "aps": ["alert": "Test"],
            "event_id": "evt_duplicate"
        ]

        // Add to cache first
        deduplicationCache.add("evt_duplicate")

        // Wait for cache add
        let cacheExpectation = self.expectation(description: "cache add")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            cacheExpectation.fulfill()
        }
        waitForExpectations(timeout: 1.0)

        let notification = createMockNotification(userInfo: userInfo)
        let expectation = self.expectation(description: "foreground duplicate")

        notificationDelegate.userNotificationCenter(mockCenter, willPresent: notification) { options in
            // Should NOT show (empty options)
            XCTAssertTrue(options.isEmpty, "Duplicate should suppress notification")
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1.0)

        // Verify callback NOT fired
        XCTAssertEqual(mockAppDelegate.receivedNotifications.count, 0, "Duplicate should not fire callback")
    }

    func testForegroundNotificationWithoutEventID() {
        let userInfo: [AnyHashable: Any] = [
            "aps": [
                "alert": "No event ID"
            ]
        ]

        let notification = createMockNotification(userInfo: userInfo)
        let expectation = self.expectation(description: "foreground no event_id")

        notificationDelegate.userNotificationCenter(mockCenter, willPresent: notification) { options in
            // Should show banner (no deduplication without event_id)
            XCTAssertFalse(options.isEmpty)
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1.0)

        // Verify callback fired
        XCTAssertEqual(mockAppDelegate.receivedNotifications.count, 1)
    }

    // MARK: - Background Notifications (Tap)

    func testBackgroundNotificationDefaultAction() {
        let userInfo: [AnyHashable: Any] = [
            "aps": ["alert": "Background test"],
            "event_id": "evt_bg_001"
        ]

        let notification = createMockNotification(userInfo: userInfo)
        let response = createMockResponse(
            notification: notification,
            actionIdentifier: UNNotificationDefaultActionIdentifier
        )

        let expectation = self.expectation(description: "background tap")

        notificationDelegate.userNotificationCenter(mockCenter, didReceive: response) {
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1.0)

        // Verify didOpenNotification callback
        XCTAssertEqual(mockAppDelegate.openedNotifications.count, 1)
        let opened = mockAppDelegate.openedNotifications[0]
        XCTAssertEqual(opened.notification.eventID, "evt_bg_001")
        XCTAssertFalse(opened.context.isForeground)
        XCTAssertNil(opened.action, "Default action should be nil")
    }

    func testBackgroundNotificationCustomAction() {
        let userInfo: [AnyHashable: Any] = [
            "aps": ["alert": "Custom action test"],
            "event_id": "evt_custom"
        ]

        let notification = createMockNotification(userInfo: userInfo)
        let response = createMockResponse(
            notification: notification,
            actionIdentifier: "ACCEPT_ACTION"
        )

        let expectation = self.expectation(description: "custom action")

        notificationDelegate.userNotificationCenter(mockCenter, didReceive: response) {
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1.0)

        // Verify custom action passed
        XCTAssertEqual(mockAppDelegate.openedNotifications.count, 1)
        let opened = mockAppDelegate.openedNotifications[0]
        XCTAssertEqual(opened.action, "ACCEPT_ACTION")
    }

    func testBackgroundNotificationDismissAction() {
        let userInfo: [AnyHashable: Any] = [
            "aps": ["alert": "Dismiss test"]
        ]

        let notification = createMockNotification(userInfo: userInfo)
        let response = createMockResponse(
            notification: notification,
            actionIdentifier: UNNotificationDismissActionIdentifier
        )

        let expectation = self.expectation(description: "dismiss action")

        notificationDelegate.userNotificationCenter(mockCenter, didReceive: response) {
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1.0)

        // Verify NO callback fired (dismissed)
        XCTAssertEqual(mockAppDelegate.openedNotifications.count, 0, "Dismiss should not fire callback")
    }

    // MARK: - Context Detection

    func testContextIsForegroundTrue() {
        let userInfo: [AnyHashable: Any] = ["aps": ["alert": "Context test"]]
        let notification = createMockNotification(userInfo: userInfo)
        let expectation = self.expectation(description: "context foreground")

        notificationDelegate.userNotificationCenter(mockCenter, willPresent: notification) { _ in
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1.0)

        XCTAssertTrue(mockAppDelegate.receivedNotifications[0].context.isForeground)
    }

    func testContextIsForegroundFalse() {
        let userInfo: [AnyHashable: Any] = ["aps": ["alert": "Context test"]]
        let notification = createMockNotification(userInfo: userInfo)
        let response = createMockResponse(
            notification: notification,
            actionIdentifier: UNNotificationDefaultActionIdentifier
        )
        let expectation = self.expectation(description: "context background")

        notificationDelegate.userNotificationCenter(mockCenter, didReceive: response) {
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1.0)

        XCTAssertFalse(mockAppDelegate.openedNotifications[0].context.isForeground)
    }

    // MARK: - Multiple Notifications

    func testMultipleForegroundNotifications() {
        let userInfo1: [AnyHashable: Any] = [
            "aps": ["alert": "First"],
            "event_id": "evt_1"
        ]
        let userInfo2: [AnyHashable: Any] = [
            "aps": ["alert": "Second"],
            "event_id": "evt_2"
        ]

        let notification1 = createMockNotification(userInfo: userInfo1)
        let notification2 = createMockNotification(userInfo: userInfo2)

        let expectation1 = self.expectation(description: "first notification")
        notificationDelegate.userNotificationCenter(mockCenter, willPresent: notification1) { _ in
            expectation1.fulfill()
        }

        let expectation2 = self.expectation(description: "second notification")
        notificationDelegate.userNotificationCenter(mockCenter, willPresent: notification2) { _ in
            expectation2.fulfill()
        }

        waitForExpectations(timeout: 1.0)

        // Both should be received
        XCTAssertEqual(mockAppDelegate.receivedNotifications.count, 2)
        XCTAssertEqual(mockAppDelegate.receivedNotifications[0].notification.eventID, "evt_1")
        XCTAssertEqual(mockAppDelegate.receivedNotifications[1].notification.eventID, "evt_2")
    }

    // MARK: - Helper Methods

    private func createMockNotification(userInfo: [AnyHashable: Any]) -> UNNotification {
        let content = UNMutableNotificationContent()
        content.userInfo = userInfo
        content.title = (userInfo["aps"] as? [String: Any])?["alert"] as? String ?? ""

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        // Note: Cannot directly create UNNotification, so we use a mock wrapper
        return MockUNNotification(request: request)
    }

    private func createMockResponse(
        notification: UNNotification,
        actionIdentifier: String
    ) -> UNNotificationResponse {
        return MockUNNotificationResponse(
            notification: notification,
            actionIdentifier: actionIdentifier
        )
    }
}

// MARK: - Mock Classes

class MockPushPlatformDelegate: PushPlatformDelegate {
    var receivedNotifications: [(notification: ParsedNotification, context: NotificationContext)] = []
    var openedNotifications: [(notification: ParsedNotification, action: String?, context: NotificationContext)] = []

    func didInitialize(installationID: UUID) {}
    func didRegisterTokens() {}
    func didFailRegisterTokens(error: SDKError) {}

    func didReceiveNotification(_ notification: ParsedNotification, context: NotificationContext) {
        receivedNotifications.append((notification, context))
    }

    func didOpenNotification(_ notification: ParsedNotification, action: String?, context: NotificationContext) {
        openedNotifications.append((notification, action, context))
    }

    func didReceiveIncomingCall(callID: String, callerName: String, metadata: [String: Any]) {}
    func didUpdateAPNsToken() {}
    func didUpdateVoIPToken() {}
}

class MockUNNotification: UNNotification {
    private let mockRequest: UNNotificationRequest

    init(request: UNNotificationRequest) {
        self.mockRequest = request
        super.init()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }

    override var request: UNNotificationRequest {
        return mockRequest
    }
}

class MockUNNotificationResponse: UNNotificationResponse {
    private let mockNotification: UNNotification
    private let mockActionIdentifier: String

    init(notification: UNNotification, actionIdentifier: String) {
        self.mockNotification = notification
        self.mockActionIdentifier = actionIdentifier
        super.init()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }

    override var notification: UNNotification {
        return mockNotification
    }

    override var actionIdentifier: String {
        return mockActionIdentifier
    }
}
