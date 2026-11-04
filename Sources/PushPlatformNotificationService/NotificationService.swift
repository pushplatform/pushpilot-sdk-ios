import UserNotifications
import PushPlatformExtension

/// Sample for the application Notification Service Extension target.
/// The extension bundle id is the application bundle id plus `.PushPlatformNotificationService`.
/// Both targets need the App Group `group.<application bundle id>.pushplatform`.
/// Link only `PushPlatformSDK/Extension` (SPM: PushPlatformExtension). Do not link the full App SDK.
/// The pod performs the receipt request and does not change the banner.
class NotificationService: UNNotificationServiceExtension {
    var contentHandler: ((UNNotificationContent) -> Void)?
    var receivedRequest: UNNotificationRequest!
    var bestAttemptContent: UNMutableNotificationContent?

    override func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        self.receivedRequest = request
        self.contentHandler = contentHandler
        bestAttemptContent = request.content.mutableCopy() as? UNMutableNotificationContent
        if let bestAttemptContent {
            PushPlatformExtension.didReceive(receivedRequest, with: bestAttemptContent, withContentHandler: contentHandler)
        } else {
            contentHandler(request.content)
        }
    }

    override func serviceExtensionTimeWillExpire() {
        if let contentHandler, let bestAttemptContent,
           PushPlatformExtension.serviceExtensionTimeWillExpireRequest(receivedRequest, with: bestAttemptContent) {
            contentHandler(bestAttemptContent)
        }
    }
}
