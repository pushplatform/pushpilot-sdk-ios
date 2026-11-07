import Foundation
import ObjectiveC
import UIKit
import UserNotifications

/// Installs the SDK as the notification delegate and receives the APNs token
/// without application code in the host AppDelegate.
enum RemoteNotificationIntegration {
    private static var didInstall = false
    static var registerIMP: IMP?
    static var failIMP: IMP?
    static var backgroundIMP: IMP?

    static func install() {
        if Bundle.main.bundleURL.path.contains("/Agents") { return }
        NotificationCenterProxy.shared.install()
        guard !didInstall, let delegate = UIApplication.shared.delegate else { return }
        didInstall = true
        let cls = type(of: delegate) as AnyClass
        hook(
            cls,
            #selector(UIApplicationDelegate.application(_:didRegisterForRemoteNotificationsWithDeviceToken:)),
            #selector(RemoteNotificationHook.application(_:didRegisterForRemoteNotificationsWithDeviceToken:)),
            store: { registerIMP = $0 }
        )
        hook(
            cls,
            #selector(UIApplicationDelegate.application(_:didFailToRegisterForRemoteNotificationsWithError:)),
            #selector(RemoteNotificationHook.application(_:didFailToRegisterForRemoteNotificationsWithError:)),
            store: { failIMP = $0 }
        )
        hook(
            cls,
            #selector(UIApplicationDelegate.application(_:didReceiveRemoteNotification:fetchCompletionHandler:)),
            #selector(RemoteNotificationHook.application(_:didReceiveRemoteNotification:fetchCompletionHandler:)),
            store: { backgroundIMP = $0 }
        )
        UIApplication.shared.registerForRemoteNotifications()
    }

    private static func hook(_ cls: AnyClass, _ selector: Selector, _ replacement: Selector, store: (IMP?) -> Void) {
        guard let method = class_getInstanceMethod(RemoteNotificationHook.self, replacement) else { return }
        let implementation = method_getImplementation(method)
        let types = method_getTypeEncoding(method)
        if let existing = class_getInstanceMethod(cls, selector) {
            store(method_getImplementation(existing))
            class_replaceMethod(cls, selector, implementation, types)
            return
        }
        store(nil)
        class_addMethod(cls, selector, implementation, types)
    }
}

private final class RemoteNotificationHook: NSObject {
    @objc func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        PushPlatform.shared.didRegisterAPNsToken(deviceToken)
        guard let imp = RemoteNotificationIntegration.registerIMP else { return }
        unsafeBitCast(imp, to: (@convention(c) (AnyObject, Selector, UIApplication, Data) -> Void).self)(
            self,
            #selector(UIApplicationDelegate.application(_:didRegisterForRemoteNotificationsWithDeviceToken:)),
            application,
            deviceToken
        )
    }

    @objc func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        let handled = PushPlatform.shared.handleBackgroundNotification(userInfo)
        guard let imp = RemoteNotificationIntegration.backgroundIMP else {
            completionHandler(handled ? .newData : .noData)
            return
        }
        typealias Callback = @convention(block) (UIBackgroundFetchResult) -> Void
        unsafeBitCast(imp, to: (@convention(c) (AnyObject, Selector, UIApplication, NSDictionary, Callback) -> Void).self)(
            self,
            #selector(UIApplicationDelegate.application(_:didReceiveRemoteNotification:fetchCompletionHandler:)),
            application, userInfo as NSDictionary, completionHandler
        )
    }

    @objc func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        PushPlatform.shared.didFailToRegisterAPNs(error)
        guard let imp = RemoteNotificationIntegration.failIMP else { return }
        unsafeBitCast(imp, to: (@convention(c) (AnyObject, Selector, UIApplication, Error) -> Void).self)(
            self,
            #selector(UIApplicationDelegate.application(_:didFailToRegisterForRemoteNotificationsWithError:)),
            application,
            error
        )
    }
}

final class NotificationCenterProxy: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationCenterProxy()

    private weak var hostDelegate: UNUserNotificationCenterDelegate?

    func install() {
        let center = UNUserNotificationCenter.current()
        guard center.delegate !== self else { return }
        hostDelegate = center.delegate
        center.delegate = self
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        if notification.request.content.userInfo[NotificationParser.notificationIDKey] is String {
            PushPlatform.shared.handleForegroundNotification(notification, completionHandler: completionHandler)
        } else if let hostDelegate, hostDelegate.responds(to: #selector(UNUserNotificationCenterDelegate.userNotificationCenter(_:willPresent:withCompletionHandler:))) {
            hostDelegate.userNotificationCenter?(center, willPresent: notification, withCompletionHandler: completionHandler)
        } else { completionHandler([.alert, .sound, .badge]) }
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        if response.notification.request.content.userInfo[NotificationParser.notificationIDKey] is String {
            PushPlatform.shared.handleNotificationResponse(response, completionHandler: completionHandler)
        } else if let hostDelegate, hostDelegate.responds(to: #selector(UNUserNotificationCenterDelegate.userNotificationCenter(_:didReceive:withCompletionHandler:))) {
            hostDelegate.userNotificationCenter?(center, didReceive: response, withCompletionHandler: completionHandler)
        } else { completionHandler() }
    }
}
