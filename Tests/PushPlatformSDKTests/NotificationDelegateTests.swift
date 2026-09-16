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
}
