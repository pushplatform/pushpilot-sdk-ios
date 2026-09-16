# PushPlatform iOS SDK

Native iOS SDK for push notifications and VoIP calls integration.

[![Platform](https://img.shields.io/badge/platform-iOS%2013%2B-blue.svg)](https://developer.apple.com/ios/)
[![Swift](https://img.shields.io/badge/Swift-5.7+-orange.svg)](https://swift.org)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

## Features

- 📱 **APNs Push Notifications**: Alert, badge, sound, and silent push
- 📞 **VoIP Push & CallKit**: Incoming call notifications with native UI
- 👤 **User Management**: Associate installations with external user IDs
- 🔄 **Automatic Token Management**: Handle token updates and rotation
- 🚫 **Deduplication**: Prevent duplicate notifications by event_id
- 🔌 **Offline Support**: Automatic retry with exponential backoff
- 🐛 **Debug Mode**: Detailed logging without exposing tokens
- 📦 **Swift Package Manager**: Easy integration

## Requirements

- iOS 13.0+
- Xcode 14.0+
- Swift 5.7+

## Installation

### Swift Package Manager

Add the following to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/your-org/push-platform-sdk-ios.git", from: "1.0.0")
]
```

Or in Xcode:
1. File → Add Packages
2. Enter repository URL
3. Select version and add to target

## Quick Start

### 1. Configure SDK

```swift
import PushPlatformSDK

// In AppDelegate didFinishLaunchingWithOptions
PushPlatform.shared.configure(
    apiKey: "pk_live_your_api_key",
    apiBaseURL: "https://api.pushplatform.example",
    environment: .production,
    debugMode: false
)

PushPlatform.shared.delegate = self
```

### 2. Request Permissions

```swift
import UserNotifications

UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
    if granted {
        DispatchQueue.main.async {
            UIApplication.shared.registerForRemoteNotifications()
        }
    }
}
```

### 3. Handle APNs Token

```swift
func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    PushPlatform.shared.didRegisterAPNsToken(deviceToken)
}
```

### 4. Implement Delegate

```swift
extension AppDelegate: PushPlatformDelegate {
    func didInitialize(installationID: UUID) {
        print("SDK initialized: \(installationID)")
    }
    
    func didRegisterTokens() {
        print("Tokens registered successfully")
    }
    
    func didReceiveNotification(_ notification: Notification, context: NotificationContext) {
        print("Notification: \(notification.title ?? "")")
    }
    
    func didOpenNotification(_ notification: Notification, action: String?, context: NotificationContext) {
        print("Notification opened")
    }
    
    func didReceiveIncomingCall(callID: String, callerName: String, metadata: [String: Any]) {
        print("Incoming call from \(callerName)")
    }
    
    func didUpdateAPNsToken() {
        print("APNs token updated")
    }
    
    func didUpdateVoIPToken() {
        print("VoIP token updated")
    }
    
    func didFailRegisterTokens(error: SDKError) {
        print("Registration failed: \(error)")
    }
}
```

### 5. User Login/Logout

```swift
// Associate installation with user
PushPlatform.shared.login(userID: "user_12345") { result in
    switch result {
    case .success:
        print("User logged in")
    case .failure(let error):
        print("Login failed: \(error)")
    }
}

// Disassociate user (installation remains active)
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

- **[Quick Start Guide](docs/QUICK_START.md)**: Step-by-step integration tutorial
- **[API Reference](docs/API_REFERENCE.md)**: Complete API documentation
- **[Troubleshooting](docs/TROUBLESHOOTING.md)**: Common issues and solutions
- **[Compatibility Matrix](docs/COMPATIBILITY_MATRIX.md)**: Supported iOS versions and devices
- **[Example App](Example/)**: Complete working example with SwiftUI

## Key Capabilities

### Push Notifications

- **Foreground**: Banner, sound, badge displayed while app is active
- **Background**: Notification center display with tap-to-open
- **Silent**: Background content updates without user notification
- **Custom Actions**: Reply, accept, dismiss buttons

### VoIP & CallKit

- **PushKit Integration**: VoIP push delivery even when app is terminated
- **CallKit UI**: Native incoming call screen with accept/decline
- **Call Metadata**: Caller name, phone number, custom data
- **Background Handling**: Process calls without launching full UI

### Deduplication

- **Event ID Tracking**: Prevent duplicate notifications by `event_id`
- **Foreground Suppression**: Duplicate foreground notifications blocked
- **Background Logging**: Duplicate taps logged but callback fires (user intent)
- **Call ID Deduplication**: Prevent duplicate CallKit calls

### Offline Support

- **Automatic Retry**: Exponential backoff (2^n seconds, max 60s)
- **Max Retries**: 5 attempts before failure
- **Network Errors**: Retry on connection failures
- **Server Errors**: Retry on 5xx and 429 status codes
- **Client Errors**: No retry on 4xx (invalid request)

## Security

- **Token Masking**: Device tokens logged with first 8 hex chars only
- **No Plaintext Storage**: Tokens never stored in UserDefaults
- **Secure Transmission**: HTTPS required for all API calls
- **Debug Mode**: Verbose logging without exposing sensitive data

## Architecture

```
PushPlatform (Singleton)
├── Configuration
├── InstallationManager (UUID persistence)
├── TokenRegistry (APNs + VoIP tokens)
├── APNsTokenManager (UIApplication delegate)
├── PushKitManager (PKPushRegistry)
├── UserManager (Login/logout with retry)
├── NotificationDelegate (UNUserNotificationCenter)
└── CallKitIntegration (CXProvider)
```

## Testing

Run unit tests:

```bash
swift test
```

Run specific test:

```bash
swift test --filter SDKIntegrationTests
```

View test coverage:

```bash
swift test --enable-code-coverage
```

## Example App

The Example app demonstrates all SDK features:

```bash
cd Example
open PushPlatformExample.xcodeproj
```

See [Example/README.md](Example/README.md) for setup instructions.

## Troubleshooting

### No push notifications received

- Verify running on **physical device** (not Simulator)
- Check APNs certificate matches bundle ID
- Verify `aps-environment` in entitlements (development/production)
- Check push notification capability enabled in Xcode

### Token registration fails

- Verify `registerForRemoteNotifications()` called on main thread
- Check device has network connection
- Verify API key is valid
- Check debug logs for detailed error messages

### VoIP push not received when app terminated

- Verify PushKit entitlement: `com.apple.developer.pushkit`
- Check VoIP certificate configured in backend
- Verify CallKit integration implemented
- Test with sandbox environment first

See [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) for more issues and solutions.

## Compatibility

| iOS Version | Status | Notes |
|-------------|--------|-------|
| iOS 17.x | ✅ Tested | Full support |
| iOS 16.x | ✅ Tested | Full support |
| iOS 15.x | ✅ Tested | Full support |
| iOS 14.x | ✅ Tested | Uses `.banner` presentation option |
| iOS 13.x | ✅ Tested | Uses `.alert` presentation option |
| iOS 12.x | ❌ Not supported | Minimum iOS 13.0 required |

See [docs/COMPATIBILITY_MATRIX.md](docs/COMPATIBILITY_MATRIX.md) for detailed compatibility information.

## Contributing

Contributions are welcome! Please read [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## License

This project is licensed under the MIT License - see [LICENSE](LICENSE) file for details.

## Support

- **Documentation**: [docs/](docs/)
- **Issues**: [GitHub Issues](https://github.com/your-org/push-platform-sdk-ios/issues)
- **Email**: support@pushplatform.example
- **Slack**: [Join our community](https://pushplatform.slack.com)

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for release history.

## Roadmap

- [ ] iOS 18 support
- [ ] Rich notifications with media attachments
- [ ] Notification categories and custom actions
- [ ] Analytics and delivery tracking
- [ ] SwiftUI-native API
- [ ] Combine publishers for reactive programming

---

Made with ❤️ by the PushPlatform team
