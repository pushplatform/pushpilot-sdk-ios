import UserNotifications

/// Add this file to a Notification Service Extension target. The extension bundle id
/// must be the application bundle id plus `.PushPlatformNotificationService`, and both
/// targets need the App Group `group.<application bundle id>.pushplatform`.
/// The extension reports receipt and does not change the banner.
class NotificationService: UNNotificationServiceExtension {
    override func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        guard let content = request.content.mutableCopy() as? UNMutableNotificationContent else {
            contentHandler(request.content)
            return
        }
        let userInfo = request.content.userInfo
        let notificationID = userInfo["notification_id"] as? String
        let bundleID = (Bundle.main.bundleIdentifier ?? "").replacingOccurrences(of: ".PushPlatformNotificationService", with: "")
        let defaults = UserDefaults(suiteName: "group.\(bundleID).pushplatform")
        let serverURL = defaults?.string(forKey: "server_url")
        let applicationID = defaults?.string(forKey: "application_id")
        let subscriptionID = defaults?.string(forKey: "subscription_id")
        guard let notificationID, !notificationID.isEmpty,
              let serverURL, let applicationID, let subscriptionID, !subscriptionID.isEmpty,
              let encoded = notificationID.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let url = URL(string: "\(serverURL)/notifications/\(encoded)") else {
            contentHandler(content)
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: [
            "app_id": applicationID,
            "subscription_id": subscriptionID,
            "received": true,
        ])
        let task = URLSession.shared.dataTask(with: request) { _, _, _ in
            contentHandler(content)
        }
        task.resume()
    }
}
