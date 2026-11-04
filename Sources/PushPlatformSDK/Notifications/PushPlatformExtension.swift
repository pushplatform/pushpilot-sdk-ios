import Foundation
import UserNotifications

/// Confirms delivery from a Notification Service Extension without starting PushKit or the app SDK.
public enum PushPlatformExtension {
    private static let lock = NSLock()
    private static var task: URLSessionDataTask?
    private static var delivered = false

    /// Sends `received` when the App Group has a server URL, application id and subscription id.
    /// The banner content is left unchanged. Calls `contentHandler` at most once.
    public static func didReceive(
        _ request: UNNotificationRequest,
        with content: UNMutableNotificationContent,
        withContentHandler contentHandler: ((UNNotificationContent) -> Void)?
    ) {
        lock.lock()
        task?.cancel()
        task = nil
        delivered = false
        lock.unlock()

        guard let contentHandler else { return }
        let fallback = request.content
        guard let urlRequest = receiptRequest(userInfo: request.content.userInfo, extensionBundleID: Bundle.main.bundleIdentifier ?? "") else {
            finish(contentHandler, fallback)
            return
        }
        let dataTask = URLSession.shared.dataTask(with: urlRequest) { _, _, _ in
            finish(contentHandler, content)
        }
        lock.lock()
        if delivered {
            lock.unlock()
            dataTask.cancel()
            return
        }
        task = dataTask
        lock.unlock()
        dataTask.resume()
    }

    /// Stops the receipt request so a late response cannot call the content handler again.
    /// Returns true when the extension still has to deliver `content`.
    @discardableResult
    public static func serviceExtensionTimeWillExpireRequest(
        _ request: UNNotificationRequest,
        with content: UNMutableNotificationContent?
    ) -> Bool {
        lock.lock()
        task?.cancel()
        task = nil
        let shouldDeliver = !delivered
        delivered = true
        lock.unlock()
        return shouldDeliver
    }

    static func mainBundleID(extensionBundleID: String) -> String {
        let suffix = ".PushPlatformNotificationService"
        guard extensionBundleID.hasSuffix(suffix) else { return extensionBundleID }
        return String(extensionBundleID.dropLast(suffix.count))
    }

    static func receiptRequest(userInfo: [AnyHashable: Any], extensionBundleID: String) -> URLRequest? {
        let notificationID = userInfo["notification_id"] as? String
        let bundleID = mainBundleID(extensionBundleID: extensionBundleID)
        let defaults = UserDefaults(suiteName: AppGroupStore.identifier(bundleID: bundleID))
        let serverURL = defaults?.string(forKey: "server_url")
        let applicationID = defaults?.string(forKey: "application_id")
        let subscriptionID = defaults?.string(forKey: "subscription_id")
        guard let notificationID, !notificationID.isEmpty,
              let serverURL, !serverURL.isEmpty,
              let applicationID, !applicationID.isEmpty,
              let subscriptionID, !subscriptionID.isEmpty,
              let encoded = notificationID.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let url = URL(string: "\(serverURL)/notifications/\(encoded)") else {
            return nil
        }
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "PUT"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try? JSONSerialization.data(withJSONObject: [
            "app_id": applicationID,
            "subscription_id": subscriptionID,
            "received": true,
        ])
        return urlRequest
    }

    private static func finish(_ contentHandler: (UNNotificationContent) -> Void, _ content: UNNotificationContent) {
        lock.lock()
        if delivered {
            lock.unlock()
            return
        }
        delivered = true
        task = nil
        lock.unlock()
        contentHandler(content)
    }
}
