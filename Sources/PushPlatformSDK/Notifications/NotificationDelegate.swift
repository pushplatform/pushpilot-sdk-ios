import Foundation
import UserNotifications

/// UNUserNotificationCenterDelegate implementation for foreground/background notifications
@available(iOS 10.0, *)
class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {

    private let deduplicationCache: DeduplicationCache
    weak var appDelegate: PushPlatformDelegate?

    init(deduplicationCache: DeduplicationCache) {
        self.deduplicationCache = deduplicationCache
        super.init()
    }

    // MARK: - Foreground Notifications

    /// Called when a notification arrives while the app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let userInfo = notification.request.content.userInfo
        let parsedNotification = NotificationParser.parse(userInfo)

        Logger.debug("Foreground notification received")

        // Check deduplication
        if let eventID = parsedNotification.eventID {
            if deduplicationCache.contains(eventID) {
                Logger.debug("Duplicate event_id: \(eventID), suppressing foreground notification")
                completionHandler([])  // Don't show
                return
            }

            // Add to deduplication cache
            deduplicationCache.add(eventID)
            Logger.debug("Added event_id to deduplication cache: \(eventID)")
        }

        // Notify app delegate
        let context = NotificationContext(isForeground: true)
        appDelegate?.didReceiveNotification(parsedNotification, context: context)

        // Show banner + sound + badge
        if #available(iOS 14.0, *) {
            completionHandler([.banner, .sound, .badge])
        } else {
            completionHandler([.alert, .sound, .badge])
        }
    }

    // MARK: - Background/Terminated Notifications

    /// Called when user taps notification (app in background or terminated)
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        let parsedNotification = NotificationParser.parse(userInfo)
        let actionIdentifier = response.actionIdentifier

        Logger.debug("Background notification tapped, action: \(actionIdentifier)")

        // Check deduplication for background tap
        if let eventID = parsedNotification.eventID {
            if deduplicationCache.contains(eventID) {
                Logger.debug("Duplicate event_id on tap: \(eventID), but firing callback")
            } else {
                // Add to cache if not already present
                deduplicationCache.add(eventID)
                Logger.debug("Added event_id to deduplication cache: \(eventID)")
            }
        }

        // Notify app delegate
        let context = NotificationContext(isForeground: false)

        // Check if this is the default action (user tapped notification)
        if actionIdentifier == UNNotificationDefaultActionIdentifier {
            appDelegate?.didOpenNotification(parsedNotification, action: nil, context: context)
        } else if actionIdentifier == UNNotificationDismissActionIdentifier {
            // User dismissed notification without opening
            Logger.debug("Notification dismissed without opening")
        } else {
            // Custom action identifier
            appDelegate?.didOpenNotification(parsedNotification, action: actionIdentifier, context: context)
        }

        completionHandler()
    }
}
