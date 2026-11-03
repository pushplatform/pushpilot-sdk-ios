import Foundation

/// Parser for APNs notification payloads
struct NotificationParser {

    /// Parse APNs notification userInfo dictionary
    /// - Parameter userInfo: Notification userInfo from UNNotification
    /// - Returns: Parsed Notification model
    static func parse(_ userInfo: [AnyHashable: Any]) -> ParsedNotification {
        // Parse standard aps fields
        let aps = userInfo["aps"] as? [String: Any] ?? [:]

        // Extract alert (string or dictionary)
        var title: String?
        var body: String?

        if let alertString = aps["alert"] as? String {
            body = alertString
        } else if let alertDict = aps["alert"] as? [String: Any] {
            title = alertDict["title"] as? String
            body = alertDict["body"] as? String
        }

        // Extract badge
        let badge = aps["badge"] as? Int

        // Extract sound (string or dictionary)
        var sound: String?
        if let soundString = aps["sound"] as? String {
            sound = soundString
        } else if let soundDict = aps["sound"] as? [String: Any],
                  let soundName = soundDict["name"] as? String {
            sound = soundName
        }

        // Extract custom data fields
        let eventID = userInfo["event_id"] as? String
        let callID = userInfo["call_id"] as? String
        let notificationID = userInfo[notificationIDKey] as? String
        let badgeRevision = integer(userInfo[badgeRevisionKey])

        // Collect all custom data (non-aps fields). The server's notification id is not app data.
        var customData: [String: Any] = [:]
        for (key, value) in userInfo {
            if let keyString = key as? String, keyString != "aps", keyString != notificationIDKey, keyString != badgeRevisionKey {
                customData[keyString] = value
            }
        }

        return ParsedNotification(
            title: title,
            body: body,
            badge: badge,
            sound: sound,
            eventID: eventID,
            callID: callID,
            customData: customData,
            notificationID: notificationID,
            badgeRevision: badgeRevision
        )
    }

    static let notificationIDKey = "notification_id"
    static let badgeRevisionKey = "badge_revision"

    private static func integer(_ value: Any?) -> Int? {
        switch value {
        case let number as Int: return number
        case let number as NSNumber: return number.intValue
        default: return nil
        }
    }
}

/// Parsed notification model
public struct ParsedNotification {
    /// Notification title (from aps.alert.title)
    public let title: String?

    /// Notification body (from aps.alert.body or aps.alert string)
    public let body: String?

    /// Badge number (from aps.badge)
    public let badge: Int?

    /// Sound name (from aps.sound)
    public let sound: String?

    /// Event ID for deduplication (custom field)
    public let eventID: String?

    /// Call ID for VoIP calls (custom field)
    public let callID: String?

    /// All custom data fields (excluding aps and notification_id)
    public let customData: [String: Any]

    /// Server notification id. GET /notifications/{id} reports this notification.
    public let notificationID: String?

    /// Server badge revision. A clear reports the latest value it has seen.
    public let badgeRevision: Int?

    init(title: String?, body: String?, badge: Int?, sound: String?, eventID: String?, callID: String?, customData: [String: Any], notificationID: String? = nil, badgeRevision: Int? = nil) {
        self.title = title
        self.body = body
        self.badge = badge
        self.sound = sound
        self.eventID = eventID
        self.callID = callID
        self.customData = customData
        self.notificationID = notificationID
        self.badgeRevision = badgeRevision
    }
}

// MARK: - Notification Context

/// Context information about notification delivery
public struct NotificationContext {
    /// Whether the notification was received in foreground
    public let isForeground: Bool

    /// Timestamp when notification was received
    public let timestamp: Date

    public init(isForeground: Bool, timestamp: Date = Date()) {
        self.isForeground = isForeground
        self.timestamp = timestamp
    }
}
