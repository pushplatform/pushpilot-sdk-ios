import UIKit
import UserNotifications
import PushPlatformSDK

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        // Configure SDK
        PushPlatform.shared.configure(
            apiKey: "pk_test_example_key_12345678",
            apiBaseURL: "https://api.pushplatform.example",
            environment: .development,
            debugMode: true
        )

        // Set delegate
        PushPlatform.shared.delegate = self

        // Request notification permissions
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("✅ Notification permission granted")
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            } else {
                print("❌ Notification permission denied: \(error?.localizedDescription ?? "unknown")")
            }
        }

        // Set notification center delegate
        UNUserNotificationCenter.current().delegate = self

        return true
    }

    // MARK: - APNs Registration

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        print("📱 APNs token received")
        PushPlatform.shared.didRegisterAPNsToken(deviceToken)
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("❌ APNs registration failed: \(error.localizedDescription)")
        PushPlatform.shared.didFailToRegisterAPNs(error)
    }

    // MARK: - UISceneSession Lifecycle (iOS 13+)

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }
}

// MARK: - PushPlatformDelegate

extension AppDelegate: PushPlatformDelegate {

    func didInitialize(installationID: UUID) {
        print("✅ SDK initialized with installation ID: \(installationID)")
        NotificationCenter.default.post(name: .sdkDidInitialize, object: installationID)
    }

    func didRegisterTokens() {
        print("✅ Tokens registered successfully")
        NotificationCenter.default.post(name: .tokensDidRegister, object: nil)
    }

    func didFailRegisterTokens(error: SDKError) {
        print("❌ Token registration failed: \(error)")
        NotificationCenter.default.post(name: .tokensDidFail, object: error)
    }

    func didReceiveNotification(_ notification: PushPlatformSDK.Notification, context: NotificationContext) {
        print("📬 Notification received (foreground=\(context.isForeground))")
        print("   Title: \(notification.title ?? "nil")")
        print("   Body: \(notification.body ?? "nil")")
        print("   Event ID: \(notification.eventID ?? "nil")")
        NotificationCenter.default.post(name: .didReceiveNotification, object: notification)
    }

    func didOpenNotification(_ notification: PushPlatformSDK.Notification, action: String?, context: NotificationContext) {
        print("🔔 Notification opened")
        print("   Action: \(action ?? "default tap")")
        print("   Title: \(notification.title ?? "nil")")
        NotificationCenter.default.post(name: .didOpenNotification, object: ["notification": notification, "action": action as Any])
    }

    func didReceiveIncomingCall(callID: String, callerName: String, metadata: [String: Any]) {
        print("📞 Incoming call from \(callerName)")
        print("   Call ID: \(callID)")
        NotificationCenter.default.post(name: .didReceiveIncomingCall, object: ["callID": callID, "callerName": callerName, "metadata": metadata])
    }

    func didUpdateAPNsToken() {
        print("🔄 APNs token updated")
        NotificationCenter.default.post(name: .didUpdateAPNsToken, object: nil)
    }

    func didUpdateVoIPToken() {
        print("🔄 VoIP token updated")
        NotificationCenter.default.post(name: .didUpdateVoIPToken, object: nil)
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension AppDelegate: UNUserNotificationCenterDelegate {

    // Foreground notification
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        print("📨 Foreground notification will present")

        // Delegate to SDK for parsing, deduplication, and presentation
        PushPlatform.shared.handleForegroundNotification(notification, completionHandler: completionHandler)
    }

    // Background tap
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        print("📲 Notification tapped in background")

        // Delegate to SDK for parsing, deduplication, and callback
        PushPlatform.shared.handleNotificationResponse(response, completionHandler: completionHandler)
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let sdkDidInitialize = Notification.Name("sdkDidInitialize")
    static let tokensDidRegister = Notification.Name("tokensDidRegister")
    static let tokensDidFail = Notification.Name("tokensDidFail")
    static let didReceiveNotification = Notification.Name("didReceiveNotification")
    static let didOpenNotification = Notification.Name("didOpenNotification")
    static let didReceiveIncomingCall = Notification.Name("didReceiveIncomingCall")
    static let didUpdateAPNsToken = Notification.Name("didUpdateAPNsToken")
    static let didUpdateVoIPToken = Notification.Name("didUpdateVoIPToken")
}
