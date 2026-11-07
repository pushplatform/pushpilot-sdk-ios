import Foundation
import UserNotifications

/// Confirms delivery from a Notification Service Extension without starting PushKit or the app SDK.
public enum PushPlatformExtension {
    private static let lock = NSLock()
    private static var requests: [ObjectIdentifier: Receipt] = [:]

    private final class Receipt {
        let lock = NSLock()
        var task: URLSessionDataTask?
        var finished = false
        let handler: (UNNotificationContent) -> Void
        init(handler: @escaping (UNNotificationContent) -> Void) { self.handler = handler }
        func finish(_ content: UNNotificationContent) {
            lock.lock()
            guard !finished else { lock.unlock(); return }
            finished = true
            task = nil
            lock.unlock()
            handler(content)
        }
        func expire() -> Bool {
            lock.lock()
            let shouldDeliver = !finished
            finished = true
            let pending = task
            task = nil
            lock.unlock()
            pending?.cancel()
            return shouldDeliver
        }
    }

    /// Confirms delivery without starting the app. Each request owns its completion.
    public static func didReceive(
        _ request: UNNotificationRequest,
        with content: UNMutableNotificationContent,
        withContentHandler contentHandler: ((UNNotificationContent) -> Void)?,
        using session: URLSession = .shared
    ) {
        guard let contentHandler else { return }
        let key = ObjectIdentifier(request)
        let receipt = Receipt(handler: contentHandler)
        lock.lock()
        requests[key] = receipt
        lock.unlock()
        let complete: (UNNotificationContent) -> Void = { result in
            receipt.finish(result)
            lock.lock()
            if requests[key] === receipt { requests.removeValue(forKey: key) }
            lock.unlock()
        }
        guard let urlRequest = receiptRequest(userInfo: request.content.userInfo, extensionBundleID: Bundle.main.bundleIdentifier ?? "") else {
            complete(request.content)
            return
        }
        let task = session.dataTask(with: urlRequest) { _, _, _ in complete(content) }
        receipt.lock.lock()
        let cancelled = receipt.finished
        if !cancelled { receipt.task = task }
        receipt.lock.unlock()
        if cancelled { task.cancel() } else { task.resume() }
    }

    /// The host delivers its best attempt when true. A late network callback is ignored.
    @discardableResult
    public static func serviceExtensionTimeWillExpireRequest(
        _ request: UNNotificationRequest,
        with content: UNMutableNotificationContent?
    ) -> Bool {
        lock.lock()
        let receipt = requests.removeValue(forKey: ObjectIdentifier(request))
        lock.unlock()
        return receipt?.expire() ?? false
    }

    static func mainBundleID(extensionBundleID: String, applicationBundleID: String? = nil) -> String {
        if let applicationBundleID, !applicationBundleID.isEmpty { return applicationBundleID }
        for suffix in [".PushPlatformNotificationServiceExtension", ".PushPlatformNotificationService"] {
            if extensionBundleID.hasSuffix(suffix) { return String(extensionBundleID.dropLast(suffix.count)) }
        }
        return extensionBundleID
    }

    private static var containingApplicationBundleID: String? {
        // Extension targets may use any name. Their containing .app is authoritative.
        guard Bundle.main.bundleURL.pathExtension == "appex" else { return nil }
        let parent = Bundle.main.bundleURL.deletingLastPathComponent().deletingLastPathComponent()
        guard parent.pathExtension == "app" else { return nil }
        return Bundle(url: parent)?.bundleIdentifier
    }

    static func receiptRequest(userInfo: [AnyHashable: Any], extensionBundleID: String) -> URLRequest? {
        let notificationID = userInfo["notification_id"] as? String
        let explicitApplicationID = Bundle.main.object(forInfoDictionaryKey: "PushPlatformApplicationBundleID") as? String
        let bundleID = mainBundleID(extensionBundleID: extensionBundleID, applicationBundleID: explicitApplicationID ?? containingApplicationBundleID)
        let group = Bundle.main.object(forInfoDictionaryKey: "PushPlatformAppGroup") as? String ?? AppGroupStore.identifier(bundleID: bundleID)
        let defaults = UserDefaults(suiteName: group)
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

}
