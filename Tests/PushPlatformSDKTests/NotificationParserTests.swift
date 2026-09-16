import XCTest
@testable import PushPlatformSDK

final class NotificationParserTests: XCTestCase {

    // MARK: - Standard aps Fields

    func testParseStandardApsFields() {
        let userInfo: [AnyHashable: Any] = [
            "aps": [
                "alert": [
                    "title": "New Message",
                    "body": "You have a new message from John"
                ],
                "badge": 5,
                "sound": "default"
            ]
        ]

        let notification = NotificationParser.parse(userInfo)

        XCTAssertEqual(notification.title, "New Message")
        XCTAssertEqual(notification.body, "You have a new message from John")
        XCTAssertEqual(notification.badge, 5)
        XCTAssertEqual(notification.sound, "default")
        XCTAssertNil(notification.eventID)
        XCTAssertNil(notification.callID)
    }

    func testParseAlertAsString() {
        let userInfo: [AnyHashable: Any] = [
            "aps": [
                "alert": "Simple notification message",
                "badge": 1
            ]
        ]

        let notification = NotificationParser.parse(userInfo)

        XCTAssertNil(notification.title)
        XCTAssertEqual(notification.body, "Simple notification message")
        XCTAssertEqual(notification.badge, 1)
    }

    func testParseSoundAsDictionary() {
        let userInfo: [AnyHashable: Any] = [
            "aps": [
                "alert": "Sound test",
                "sound": [
                    "name": "custom_sound.wav",
                    "volume": 0.8
                ]
            ]
        ]

        let notification = NotificationParser.parse(userInfo)

        XCTAssertEqual(notification.sound, "custom_sound.wav")
    }

    func testParseMissingApsFields() {
        let userInfo: [AnyHashable: Any] = [
            "aps": [:]
        ]

        let notification = NotificationParser.parse(userInfo)

        XCTAssertNil(notification.title)
        XCTAssertNil(notification.body)
        XCTAssertNil(notification.badge)
        XCTAssertNil(notification.sound)
    }

    func testParseEmptyUserInfo() {
        let userInfo: [AnyHashable: Any] = [:]

        let notification = NotificationParser.parse(userInfo)

        XCTAssertNil(notification.title)
        XCTAssertNil(notification.body)
        XCTAssertNil(notification.badge)
        XCTAssertNil(notification.sound)
        XCTAssertTrue(notification.customData.isEmpty)
    }

    // MARK: - Custom Data Fields

    func testParseCustomDataWithEventID() {
        let userInfo: [AnyHashable: Any] = [
            "aps": [
                "alert": "Test notification"
            ],
            "event_id": "evt_123456",
            "custom_field": "custom_value",
            "user_id": "user_42"
        ]

        let notification = NotificationParser.parse(userInfo)

        XCTAssertEqual(notification.eventID, "evt_123456")
        XCTAssertEqual(notification.customData["event_id"] as? String, "evt_123456")
        XCTAssertEqual(notification.customData["custom_field"] as? String, "custom_value")
        XCTAssertEqual(notification.customData["user_id"] as? String, "user_42")
        XCTAssertEqual(notification.customData.count, 3)
    }

    func testParseCustomDataWithCallID() {
        let userInfo: [AnyHashable: Any] = [
            "aps": [
                "alert": "Incoming call"
            ],
            "call_id": "550e8400-e29b-41d4-a716-446655440000",
            "caller_name": "John Doe",
            "call_type": "voice"
        ]

        let notification = NotificationParser.parse(userInfo)

        XCTAssertEqual(notification.callID, "550e8400-e29b-41d4-a716-446655440000")
        XCTAssertEqual(notification.customData["call_id"] as? String, "550e8400-e29b-41d4-a716-446655440000")
        XCTAssertEqual(notification.customData["caller_name"] as? String, "John Doe")
        XCTAssertEqual(notification.customData["call_type"] as? String, "voice")
    }

    func testParseCustomDataExcludesAps() {
        let userInfo: [AnyHashable: Any] = [
            "aps": [
                "alert": "Test",
                "badge": 1
            ],
            "custom_field_1": "value1",
            "custom_field_2": 42
        ]

        let notification = NotificationParser.parse(userInfo)

        XCTAssertEqual(notification.customData.count, 2)
        XCTAssertNil(notification.customData["aps"])
        XCTAssertEqual(notification.customData["custom_field_1"] as? String, "value1")
        XCTAssertEqual(notification.customData["custom_field_2"] as? Int, 42)
    }

    func testParseNestedCustomData() {
        let userInfo: [AnyHashable: Any] = [
            "aps": [
                "alert": "Test"
            ],
            "event_id": "evt_789",
            "metadata": [
                "campaign_id": "campaign_123",
                "user_segment": "premium"
            ]
        ]

        let notification = NotificationParser.parse(userInfo)

        XCTAssertEqual(notification.eventID, "evt_789")
        let metadata = notification.customData["metadata"] as? [String: String]
        XCTAssertEqual(metadata?["campaign_id"], "campaign_123")
        XCTAssertEqual(metadata?["user_segment"], "premium")
    }

    // MARK: - Edge Cases

    func testParseNonStringHashableKeys() {
        let userInfo: [AnyHashable: Any] = [
            "aps": [
                "alert": "Test"
            ],
            "string_key": "value1",
            123: "numeric_key_ignored"  // Non-string keys ignored
        ]

        let notification = NotificationParser.parse(userInfo)

        XCTAssertEqual(notification.customData["string_key"] as? String, "value1")
        XCTAssertNil(notification.customData["123"])
    }

    func testParseTitleOnlyAlert() {
        let userInfo: [AnyHashable: Any] = [
            "aps": [
                "alert": [
                    "title": "Title Only"
                ]
            ]
        ]

        let notification = NotificationParser.parse(userInfo)

        XCTAssertEqual(notification.title, "Title Only")
        XCTAssertNil(notification.body)
    }

    func testParseBodyOnlyAlert() {
        let userInfo: [AnyHashable: Any] = [
            "aps": [
                "alert": [
                    "body": "Body Only"
                ]
            ]
        ]

        let notification = NotificationParser.parse(userInfo)

        XCTAssertNil(notification.title)
        XCTAssertEqual(notification.body, "Body Only")
    }

    func testParseZeroBadge() {
        let userInfo: [AnyHashable: Any] = [
            "aps": [
                "badge": 0
            ]
        ]

        let notification = NotificationParser.parse(userInfo)

        XCTAssertEqual(notification.badge, 0)
    }

    // MARK: - NotificationContext

    func testNotificationContextForeground() {
        let context = NotificationContext(isForeground: true)

        XCTAssertTrue(context.isForeground)
        XCTAssertNotNil(context.timestamp)
    }

    func testNotificationContextBackground() {
        let timestamp = Date()
        let context = NotificationContext(isForeground: false, timestamp: timestamp)

        XCTAssertFalse(context.isForeground)
        XCTAssertEqual(context.timestamp, timestamp)
    }
}
