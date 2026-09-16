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

        // Collect all custom data (non-aps fields)
        var customData: [String: Any] = [:]
        for (key, value) in userInfo {
            if let keyString = key as? String, keyString != "aps" {
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
            customData: customData
        )
    }
}

/// Parsed notification model
public struct ParsedNotification {
    /// Notification title (from aps.alert.title)
    let title: String?

    /// Notification body (from aps.alert.body or aps.alert string)
    let body: String?

    /// Badge number (from aps.badge)
    let badge: Int?

    /// Sound name (from aps.sound)
    let sound: String?

    /// Event ID for deduplication (custom field)
    let eventID: String?

    /// Call ID for VoIP calls (custom field)
    let callID: String?

    /// All custom data fields (excluding aps)
    let customData: [String: Any]
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
