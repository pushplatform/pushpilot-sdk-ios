# PushPlatform iOS SDK

Native iOS SDK for PushPlatform push notification service.

## Features

- ✅ APNs token registration (alert, silent)
- ✅ PushKit VoIP token support
- ✅ Installation ID management (Keychain storage)
- ✅ User login/logout
- ✅ Foreground/background notification handling
- ✅ CallKit integration for VoIP calls
- ✅ Event deduplication
- ✅ Offline retry with exponential backoff
- ✅ Debug diagnostics (no token leaks)

## Requirements

- iOS 13.0+
- Swift 5.5+
- Xcode 14.0+

## Installation

### Swift Package Manager

Add the following to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/yourorg/push-platform-ios-sdk.git", from: "1.0.0")
]
```

Or in Xcode:
1. File → Add Packages...
2. Enter repository URL
3. Select version and add to target

## Quick Start

### 1. Configure SDK

```swift
import PushPlatformSDK

// AppDelegate.swift
func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    
    // Configure SDK
    PushPlatform.shared.configure(
        apiKey: "pk_test_your_api_key",
        environment: .development,
        debugMode: true
    )
    
    // Set delegate
    PushPlatform.shared.delegate = self
    
    // Register for push notifications
    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
        if granted {
            DispatchQueue.main.async {
                UIApplication.shared.registerForRemoteNotifications()
            }
        }
    }
    
    return true
}
```

### 2. Handle APNs Token

```swift
func application(_ application: UIApplication,
                 didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    // Pass token to SDK
    PushPlatform.shared.didRegisterAPNsToken(deviceToken)
}

func application(_ application: UIApplication,
                 didFailToRegisterForRemoteNotificationsWithError error: Error) {
    PushPlatform.shared.didFailToRegisterAPNs(error)
}
```

### 3. Implement Delegate

```swift
extension AppDelegate: PushPlatformDelegate {
    func didInitialize(installationID: UUID) {
        print("Installation ID: \(installationID)")
    }
    
    func didRegisterTokens() {
        print("Tokens registered successfully")
    }
    
    func didFailRegisterTokens(error: SDKError) {
        print("Token registration failed: \(error)")
    }
    
    func didReceiveNotification(_ notification: Notification, context: NotificationContext) {
        print("Notification received: \(notification.title ?? "")")
    }
    
    func didOpenNotification(_ notification: Notification, action: String?) {
        print("Notification opened")
    }
    
    func didReceiveIncomingCall(callID: String, callerName: String, metadata: [String: Any]) {
        print("Incoming call from: \(callerName)")
    }
    
    func didUpdateAPNsToken() {
        print("APNs token updated")
    }
    
    func didUpdateVoIPToken() {
        print("VoIP token updated")
    }
}
```

### 4. User Login/Logout

```swift
// Login
PushPlatform.shared.login(userID: "user_123") { result in
    switch result {
    case .success:
        print("User logged in")
    case .failure(let error):
        print("Login failed: \(error)")
    }
}

// Logout
PushPlatform.shared.logout { result in
    switch result {
    case .success:
        print("User logged out")
    case .failure(let error):
        print("Logout failed: \(error)")
    }
}
```

## Documentation

- [Quick Start Guide](docs/QUICK_START.md) *(coming soon)*
- [API Reference](docs/API_REFERENCE.md) *(coming soon)*
- [Troubleshooting](docs/TROUBLESHOOTING.md) *(coming soon)*

## Architecture

See [ADR-0012: iOS SDK Architecture](../../docs/adr/ADR-0012-ios-sdk-architecture.md) for detailed architectural decisions.

## Security

- Installation ID stored securely in Keychain
- APNs/VoIP tokens never logged in plaintext
- API keys masked in debug logs
- No sensitive data in UserDefaults

## License

Proprietary - Internal use only

## Support

For issues and questions, contact the platform team.
