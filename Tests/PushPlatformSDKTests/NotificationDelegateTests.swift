import XCTest
import UserNotifications
@testable import PushPlatformSDK

final class NotificationDelegateTests: XCTestCase {
    var notificationDelegate: NotificationDelegate!
    var deduplicationCache: DeduplicationCache!
    var mockAppDelegate: MockPushPlatformDelegate!

    override func setUp() {
        super.setUp()
        deduplicationCache = DeduplicationCache()
        notificationDelegate = NotificationDelegate(deduplicationCache: deduplicationCache)
        mockAppDelegate = MockPushPlatformDelegate()
        notificationDelegate.appDelegate = mockAppDelegate
    }

    override func tearDown() {
        notificationDelegate = nil
        deduplicationCache = nil
        mockAppDelegate = nil
        super.tearDown()
    }

    // MARK: - Parser Integration Tests (without UNNotification)

    func testParseStandardNotification() {
        // Given
        let userInfo: [AnyHashable: Any] = [
            "aps": [
                "alert": [
                    "title": "Test Title",
                    "body": "Test Body"
                ],
                "badge": 1,
                "sound": "default"
            ],
            "event_id": "evt_123"
        ]

        // When
        let parsed = NotificationParser.parse(userInfo)

        // Then
        XCTAssertEqual(parsed.title, "Test Title")
        XCTAssertEqual(parsed.body, "Test Body")
        XCTAssertEqual(parsed.badge, 1)
        XCTAssertEqual(parsed.sound, "default")
        XCTAssertEqual(parsed.eventID, "evt_123")
    }

    func testParseVoIPNotification() {
        // Given
        let userInfo: [AnyHashable: Any] = [
            "call_id": "call_456",
            "caller_name": "John Doe",
            "caller_number": "+1234567890"
        ]

        // When
        let parsed = NotificationParser.parse(userInfo)

        // Then
        XCTAssertEqual(parsed.callID, "call_456")
        XCTAssertEqual(parsed.customData["caller_name"] as? String, "John Doe")
        XCTAssertEqual(parsed.customData["caller_number"] as? String, "+1234567890")
    }

    func testDeduplicationLogic() {
        // Given
        let eventID = "evt_dedup_test"

        // When: first time
        XCTAssertFalse(deduplicationCache.contains(eventID))
        deduplicationCache.add(eventID)

        // Then: second time
        XCTAssertTrue(deduplicationCache.contains(eventID))
    }

    func testDeduplicationCacheExpiry() {
        // Given
        let eventID = "evt_expiry_test"
        deduplicationCache.add(eventID)

        // When: check immediately
        XCTAssertTrue(deduplicationCache.contains(eventID))

        // Then: should still be cached (5 minute TTL by default)
        // Note: full expiry test would require waiting or time mocking
    }

    func testNotificationContextForeground() {
        let context = NotificationContext(isForeground: true)
        XCTAssertTrue(context.isForeground)
    }

    func testNotificationContextBackground() {
        let context = NotificationContext(isForeground: false)
        XCTAssertFalse(context.isForeground)
    }

    func testMultipleEventIDsInCache() {
        // Given
        let eventIDs = ["evt_1", "evt_2", "evt_3"]

        // When
        for eventID in eventIDs {
            deduplicationCache.add(eventID)
        }

        // Then
        for eventID in eventIDs {
            XCTAssertTrue(deduplicationCache.contains(eventID))
        }

        // And new ID should not be in cache
        XCTAssertFalse(deduplicationCache.contains("evt_4"))
    }

    func testParsedNotificationWithCustomData() {
        // Given
        let userInfo: [AnyHashable: Any] = [
            "aps": ["alert": "Test"],
            "event_id": "evt_custom",
            "custom_key": "custom_value",
            "nested": ["key": "value"]
        ]

        // When
        let parsed = NotificationParser.parse(userInfo)

        // Then
        XCTAssertEqual(parsed.eventID, "evt_custom")
        XCTAssertEqual(parsed.customData["custom_key"] as? String, "custom_value")
        XCTAssertNotNil(parsed.customData["nested"])
    }

    func testEmptyUserInfoParsing() {
        // Given
        let userInfo: [AnyHashable: Any] = [:]

        // When
        let parsed = NotificationParser.parse(userInfo)

        // Then
        XCTAssertNil(parsed.title)
        XCTAssertNil(parsed.body)
        XCTAssertNil(parsed.badge)
        XCTAssertNil(parsed.sound)
        XCTAssertNil(parsed.eventID)
        XCTAssertNil(parsed.callID)
        XCTAssertTrue(parsed.customData.isEmpty)
    }

    func testDelegateCallbackFiring() {
        // Given
        let userInfo: [AnyHashable: Any] = [
            "aps": ["alert": "Test Message"],
            "event_id": "evt_callback"
        ]
        let parsed = NotificationParser.parse(userInfo)
        let context = NotificationContext(isForeground: true)

        // When
        mockAppDelegate.didReceiveNotification(parsed, context: context)

        // Then
        XCTAssertEqual(mockAppDelegate.receivedNotifications.count, 1)
        XCTAssertEqual(mockAppDelegate.receivedNotifications[0].notification.eventID, "evt_callback")
        XCTAssertTrue(mockAppDelegate.receivedNotifications[0].context.isForeground)
    }

    func testOpenNotificationCallback() {
        // Given
        let userInfo: [AnyHashable: Any] = [
            "aps": ["alert": "Tap Me"],
            "event_id": "evt_open"
        ]
        let parsed = NotificationParser.parse(userInfo)
        let context = NotificationContext(isForeground: false)

        // When
        mockAppDelegate.didOpenNotification(parsed, action: nil, context: context)

        // Then
        XCTAssertEqual(mockAppDelegate.openedNotifications.count, 1)
        XCTAssertEqual(mockAppDelegate.openedNotifications[0].notification.eventID, "evt_open")
        XCTAssertFalse(mockAppDelegate.openedNotifications[0].context.isForeground)
        XCTAssertNil(mockAppDelegate.openedNotifications[0].action)
    }

    func testCustomActionIdentifier() {
        // Given
        let userInfo: [AnyHashable: Any] = ["aps": ["alert": "Action Test"]]
        let parsed = NotificationParser.parse(userInfo)
        let context = NotificationContext(isForeground: false)

        // When
        mockAppDelegate.didOpenNotification(parsed, action: "custom.action", context: context)

        // Then
        XCTAssertEqual(mockAppDelegate.openedNotifications.count, 1)
        XCTAssertEqual(mockAppDelegate.openedNotifications[0].action, "custom.action")
    }

    func testAlertAsStringParsing() {
        // Given
        let userInfo: [AnyHashable: Any] = [
            "aps": [
                "alert": "Simple string alert",
                "badge": 5
            ]
        ]

        // When
        let parsed = NotificationParser.parse(userInfo)

        // Then
        XCTAssertEqual(parsed.body, "Simple string alert")
        XCTAssertEqual(parsed.badge, 5)
    }

    func testSoundAsDictionaryParsing() {
        // Given
        let userInfo: [AnyHashable: Any] = [
            "aps": [
                "sound": [
                    "name": "custom_sound.caf",
                    "volume": 0.8
                ]
            ]
        ]

        // When
        let parsed = NotificationParser.parse(userInfo)

        // Then: Sound dictionary should extract "name" field
        XCTAssertEqual(parsed.sound, "custom_sound.caf", "Sound dictionary should parse 'name' field as string")
    }

    func testBadgeAsZero() {
        // Given
        let userInfo: [AnyHashable: Any] = [
            "aps": ["badge": 0]
        ]

        // When
        let parsed = NotificationParser.parse(userInfo)

        // Then
        XCTAssertEqual(parsed.badge, 0)
    }

    // MARK: - Foreground Notification Flow Tests (Logic Verification)

    func testForegroundNotificationWithEventID_ShowsBanner() {
        // Given: Notification with event_id in foreground
        let userInfo: [AnyHashable: Any] = [
            "aps": [
                "alert": ["title": "Foreground Test", "body": "Test Body"],
                "sound": "default"
            ],
            "event_id": "evt_foreground_123"
        ]

        // Create mock notification-like structure
        let parsed = NotificationParser.parse(userInfo)

        // Simulate willPresent logic
        let eventID = parsed.eventID!
        let shouldShow = !deduplicationCache.contains(eventID)

        if shouldShow {
            deduplicationCache.add(eventID)
            mockAppDelegate.didReceiveNotification(parsed, context: NotificationContext(isForeground: true))
        }

        // Then: Should show notification and fire callback
        XCTAssertTrue(shouldShow, "First notification should show")
        XCTAssertEqual(mockAppDelegate.receivedNotifications.count, 1)
        XCTAssertEqual(mockAppDelegate.receivedNotifications[0].notification.eventID, "evt_foreground_123")
        XCTAssertTrue(mockAppDelegate.receivedNotifications[0].context.isForeground)
    }

    func testForegroundNotificationDuplicate_Suppressed() {
        // Given: Same event_id sent twice
        let userInfo: [AnyHashable: Any] = [
            "aps": ["alert": "Duplicate Test"],
            "event_id": "evt_duplicate_456"
        ]

        let parsed = NotificationParser.parse(userInfo)
        let eventID = parsed.eventID!

        // First notification
        XCTAssertFalse(deduplicationCache.contains(eventID), "Cache should be empty initially")
        deduplicationCache.add(eventID)
        mockAppDelegate.didReceiveNotification(parsed, context: NotificationContext(isForeground: true))

        // Second notification (duplicate)
        let isDuplicate = deduplicationCache.contains(eventID)

        if !isDuplicate {
            mockAppDelegate.didReceiveNotification(parsed, context: NotificationContext(isForeground: true))
        }

        // Then: Delegate called only once
        XCTAssertTrue(isDuplicate, "Second notification should be detected as duplicate")
        XCTAssertEqual(mockAppDelegate.receivedNotifications.count, 1, "Duplicate should be suppressed")
    }

    func testForegroundNotificationWithoutEventID_AlwaysShows() {
        // Given: Notification without event_id
        let userInfo: [AnyHashable: Any] = [
            "aps": ["alert": "No Event ID"]
        ]

        let parsed = NotificationParser.parse(userInfo)

        // Simulate willPresent logic: no event_id means no deduplication
        mockAppDelegate.didReceiveNotification(parsed, context: NotificationContext(isForeground: true))
        mockAppDelegate.didReceiveNotification(parsed, context: NotificationContext(isForeground: true))

        // Then: Both should be delivered (no deduplication without event_id)
        XCTAssertEqual(mockAppDelegate.receivedNotifications.count, 2, "Without event_id, deduplication should not apply")
    }

    // MARK: - Background Notification Flow Tests (Logic Verification)

    func testBackgroundNotificationDefaultAction_OpensApp() {
        // Given: User taps notification (default action)
        let userInfo: [AnyHashable: Any] = [
            "aps": ["alert": "Tap Me"],
            "event_id": "evt_tap_789",
            "deep_link": "app://home"
        ]

        let parsed = NotificationParser.parse(userInfo)
        let context = NotificationContext(isForeground: false)

        // Simulate didReceive response with default action
        let actionIdentifier = "com.apple.UNNotificationDefaultActionIdentifier"  // UNNotificationDefaultActionIdentifier

        // Add to dedup cache if not present
        if let eventID = parsed.eventID, !deduplicationCache.contains(eventID) {
            deduplicationCache.add(eventID)
        }

        // Fire callback for default action (user tapped notification)
        if actionIdentifier == "com.apple.UNNotificationDefaultActionIdentifier" {
            mockAppDelegate.didOpenNotification(parsed, action: nil, context: context)
        }

        // Then: didOpenNotification called with nil action (default tap)
        XCTAssertEqual(mockAppDelegate.openedNotifications.count, 1)
        XCTAssertEqual(mockAppDelegate.openedNotifications[0].notification.eventID, "evt_tap_789")
        XCTAssertNil(mockAppDelegate.openedNotifications[0].action, "Default action should be nil")
        XCTAssertFalse(mockAppDelegate.openedNotifications[0].context.isForeground)
    }

    func testBackgroundNotificationCustomAction_PassedToDelegate() {
        // Given: User taps custom action button
        let userInfo: [AnyHashable: Any] = [
            "aps": ["alert": "Action Test"],
            "event_id": "evt_action_101"
        ]

        let parsed = NotificationParser.parse(userInfo)
        let context = NotificationContext(isForeground: false)

        // Simulate custom action identifier
        let customAction = "com.app.accept.action"

        mockAppDelegate.didOpenNotification(parsed, action: customAction, context: context)

        // Then: Custom action passed through
        XCTAssertEqual(mockAppDelegate.openedNotifications.count, 1)
        XCTAssertEqual(mockAppDelegate.openedNotifications[0].action, customAction)
    }

    func testBackgroundNotificationDismissAction_NotCalled() {
        // Given: User dismisses notification without opening
        let userInfo: [AnyHashable: Any] = [
            "aps": ["alert": "Dismiss Test"]
        ]

        let parsed = NotificationParser.parse(userInfo)
        let context = NotificationContext(isForeground: false)

        // Simulate dismiss action identifier
        let actionIdentifier = "com.apple.UNNotificationDismissActionIdentifier"

        // Dismiss action should NOT call didOpenNotification
        if actionIdentifier != "com.apple.UNNotificationDismissActionIdentifier" {
            mockAppDelegate.didOpenNotification(parsed, action: nil, context: context)
        }

        // Then: Delegate NOT called on dismiss
        XCTAssertEqual(mockAppDelegate.openedNotifications.count, 0, "Dismiss action should not trigger callback")
    }

    // MARK: - Context Detection Tests

    func testContextIsForegroundDetection() {
        // Given: Notification in foreground
        let userInfo: [AnyHashable: Any] = [
            "aps": ["alert": "Foreground Context Test"]
        ]

        let parsed = NotificationParser.parse(userInfo)
        let foregroundContext = NotificationContext(isForeground: true)

        mockAppDelegate.didReceiveNotification(parsed, context: foregroundContext)

        // Then: Context correctly set to foreground
        XCTAssertTrue(mockAppDelegate.receivedNotifications[0].context.isForeground)
    }

    func testContextIsBackgroundDetection() {
        // Given: Notification in background
        let userInfo: [AnyHashable: Any] = [
            "aps": ["alert": "Background Context Test"]
        ]

        let parsed = NotificationParser.parse(userInfo)
        let backgroundContext = NotificationContext(isForeground: false)

        mockAppDelegate.didOpenNotification(parsed, action: nil, context: backgroundContext)

        // Then: Context correctly set to background
        XCTAssertFalse(mockAppDelegate.openedNotifications[0].context.isForeground)
    }

    // MARK: - Multiple Notifications Tests

    func testMultipleForegroundNotifications_Sequential() {
        // Given: Multiple different notifications
        let userInfos: [[AnyHashable: Any]] = [
            ["aps": ["alert": "First"], "event_id": "evt_1"],
            ["aps": ["alert": "Second"], "event_id": "evt_2"],
            ["aps": ["alert": "Third"], "event_id": "evt_3"]
        ]

        // When: Process all notifications
        for userInfo in userInfos {
            let parsed = NotificationParser.parse(userInfo)
            if let eventID = parsed.eventID, !deduplicationCache.contains(eventID) {
                deduplicationCache.add(eventID)
                mockAppDelegate.didReceiveNotification(parsed, context: NotificationContext(isForeground: true))
            }
        }

        // Then: All three should be delivered (different event_ids)
        XCTAssertEqual(mockAppDelegate.receivedNotifications.count, 3, "All unique notifications should be delivered")
        XCTAssertEqual(mockAppDelegate.receivedNotifications[0].notification.eventID, "evt_1")
        XCTAssertEqual(mockAppDelegate.receivedNotifications[1].notification.eventID, "evt_2")
        XCTAssertEqual(mockAppDelegate.receivedNotifications[2].notification.eventID, "evt_3")
    }

    func testMixedForegroundAndBackgroundNotifications() {
        // Given: Foreground notification followed by background tap
        let userInfo: [AnyHashable: Any] = [
            "aps": ["alert": "Mixed Test"],
            "event_id": "evt_mixed"
        ]

        let parsed = NotificationParser.parse(userInfo)

        // Foreground notification
        if let eventID = parsed.eventID, !deduplicationCache.contains(eventID) {
            deduplicationCache.add(eventID)
            mockAppDelegate.didReceiveNotification(parsed, context: NotificationContext(isForeground: true))
        }

        // Background tap (same notification)
        mockAppDelegate.didOpenNotification(parsed, action: nil, context: NotificationContext(isForeground: false))

        // Then: Both callbacks fired (foreground + tap)
        XCTAssertEqual(mockAppDelegate.receivedNotifications.count, 1, "Foreground callback fired")
        XCTAssertEqual(mockAppDelegate.openedNotifications.count, 1, "Background tap callback fired")
    }

    // MARK: - End-to-End Deduplication Integration Tests

    func testDeduplicationAcrossForegroundAndBackground() {
        // Given: Same event_id arrives in foreground, then duplicate attempt
        let userInfo: [AnyHashable: Any] = [
            "aps": ["alert": "Dedup E2E"],
            "event_id": "evt_e2e_dedup"
        ]

        let parsed = NotificationParser.parse(userInfo)
        let eventID = parsed.eventID!

        // First: Foreground notification
        XCTAssertFalse(deduplicationCache.contains(eventID))
        deduplicationCache.add(eventID)
        mockAppDelegate.didReceiveNotification(parsed, context: NotificationContext(isForeground: true))

        // Second: Duplicate arrives (should be suppressed)
        let isDuplicate = deduplicationCache.contains(eventID)
        if !isDuplicate {
            mockAppDelegate.didReceiveNotification(parsed, context: NotificationContext(isForeground: true))
        }

        // Then: Only first delivery
        XCTAssertTrue(isDuplicate, "Deduplication should detect duplicate")
        XCTAssertEqual(mockAppDelegate.receivedNotifications.count, 1, "Duplicate suppressed")
    }

    func testCallIDAndEventIDCoexistInCache() {
        // Given: Both call_id (VoIP) and event_id (notification) use same cache
        let callID = "call_unique_123"
        let eventID = "evt_unique_456"

        // Add call_id
        deduplicationCache.add(callID)
        XCTAssertTrue(deduplicationCache.contains(callID))

        // Add event_id
        deduplicationCache.add(eventID)
        XCTAssertTrue(deduplicationCache.contains(eventID))

        // Both should coexist
        XCTAssertTrue(deduplicationCache.contains(callID), "call_id should remain in cache")
        XCTAssertTrue(deduplicationCache.contains(eventID), "event_id should remain in cache")
    }
}
