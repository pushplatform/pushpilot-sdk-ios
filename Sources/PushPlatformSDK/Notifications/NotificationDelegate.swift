import Foundation
import UserNotifications
import UIKit

/// UNUserNotificationCenterDelegate implementation for foreground/background notifications
@available(iOS 10.0, *)
class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {

    private let deduplicationCache: DeduplicationCache
    private var pendingReceives: [(ParsedNotification, NotificationContext)] = []
    private var pendingOpens: [(ParsedNotification, String?, NotificationContext)] = []
    weak var appDelegate: PushPlatformDelegate? {
        didSet {
            guard let receiver = appDelegate else { return }
            let receives = pendingReceives
            pendingReceives.removeAll()
            receives.forEach { receiver.didReceiveNotification($0.0, context: $0.1) }
            let events = pendingOpens
            pendingOpens.removeAll()
            events.forEach { receiver.didOpenNotification($0.0, action: $0.1, context: $0.2) }
        }
    }

    func deliverOpen(_ notification: ParsedNotification, action: String?, context: NotificationContext) {
        if let receiver = appDelegate { receiver.didOpenNotification(notification, action: action, context: context) }
        else {
            if pendingOpens.count >= 100 { pendingOpens.removeFirst() }
            pendingOpens.append((notification, action, context))
        }
    }
    func deliverReceive(_ notification: ParsedNotification, context: NotificationContext) {
        if let receiver = appDelegate { receiver.didReceiveNotification(notification, context: context) }
        else {
            if pendingReceives.count >= 100 { pendingReceives.removeFirst() }
            pendingReceives.append((notification, context))
        }
    }

    func handleBackground(_ userInfo: [AnyHashable: Any]) {
        let notification = NotificationParser.parse(userInfo)
        onReceive?(notification)
        if let id = notification.eventID ?? notification.notificationID.map({ "notification:\($0)" }) {
            if deduplicationCache.contains(id) { return }
            deduplicationCache.add(id)
        }
        deliverReceive(notification, context: NotificationContext(isForeground: false))
    }

    /// Receives the server notification id of a tapped notification.
    var onOpen: ((String) -> Void)?
    /// Receives a notification that was delivered to this process.
    var onReceive: ((ParsedNotification) -> Void)?

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
        onReceive?(parsedNotification)

        Logger.debug("Foreground notification received")

        // Check deduplication
        if let eventID = parsedNotification.eventID ?? parsedNotification.notificationID.map({ "notification:\($0)" }) {
            if deduplicationCache.contains(eventID) {
                Logger.debug("Duplicate event_id: \(eventID), suppressing foreground notification")
                completionHandler([])  // Don't show
                return
            }

            // Add to deduplication cache
            deduplicationCache.add(eventID)
            Logger.debug("Added event_id to deduplication cache: \(eventID)")
        }

        // Notify app delegate. A wrapper may defer the banner until its handler returns.
        let context = NotificationContext(isForeground: true)
        let display = NotificationDisplayEvent(notification: parsedNotification)
        appDelegate?.notificationWillDisplay(display)
        deliverReceive(parsedNotification, context: context)
        let present: (Bool) -> Void = { prevented in
            if prevented {
                completionHandler([])
                return
            }
            if #available(iOS 14.0, *) {
                completionHandler([.banner, .sound, .badge])
            } else {
                completionHandler([.alert, .sound, .badge])
            }
        }
        if display.takeDeferred(present) {
            display.scheduleFallback(after: Configuration.shared.foregroundBannerFallback)
            return
        }
        present(display.isPrevented)
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
        onReceive?(parsedNotification)
        let actionIdentifier = response.actionIdentifier

        Logger.debug("Background notification tapped, action: \(actionIdentifier)")

        // Check deduplication for background tap
        if let eventID = parsedNotification.eventID ?? parsedNotification.notificationID.map({ "notification:\($0)" }) {
            if deduplicationCache.contains(eventID) {
                Logger.debug("Duplicate event_id on tap: \(eventID), but firing callback")
            } else {
                // Add to cache if not already present
                deduplicationCache.add(eventID)
                Logger.debug("Added event_id to deduplication cache: \(eventID)")
            }
        }

        if actionIdentifier != UNNotificationDismissActionIdentifier, let notificationID = parsedNotification.notificationID {
            onOpen?(notificationID)
        }

        // Notify app delegate
        let context = NotificationContext(isForeground: false)

        // Check if this is the default action (user tapped notification)
        if actionIdentifier == UNNotificationDefaultActionIdentifier {
            deliverOpen(parsedNotification, action: nil, context: context)
        } else if actionIdentifier == UNNotificationDismissActionIdentifier {
            // User dismissed notification without opening
            Logger.debug("Notification dismissed without opening")
        } else {
            // Custom action identifier
            deliverOpen(parsedNotification, action: actionIdentifier, context: context)
        }

        completionHandler()
    }
}
