# Quick Start Guide

This guide walks you through integrating the PushPlatform iOS SDK into your app in 15 minutes.

## Prerequisites

- Xcode 14.0 or later
- iOS 13.0+ deployment target
- Apple Developer account
- Physical iOS device (push notifications don't work in Simulator)

## Step 1: Add SDK to Your Project

### Using Swift Package Manager (Recommended)

1. Open your Xcode project
2. Go to **File → Add Packages...**
3. Enter the repository URL: `https://github.com/your-org/push-platform-sdk-ios.git`
4. Select **Up to Next Major Version** and click **Add Package**
5. Select your app target and click **Add Package**

### Manual Installation

Alternatively, add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/your-org/push-platform-sdk-ios.git", from: "1.0.0")
]
```

## Step 2: Configure Capabilities

### Enable Push Notifications

1. Select your app target in Xcode
2. Go to **Signing & Capabilities** tab
3. Click **+ Capability**
4. Add **Push Notifications**

### Enable Background Modes

1. In **Signing & Capabilities**, click **+ Capability** again
2. Add **Background Modes**
3. Check these boxes:
   - ☑️ **Remote notifications**
   - ☑️ **Voice over IP** (if using VoIP push)

### Configure Entitlements

Your `YourApp.entitlements` file should include:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>aps-environment</key>
    <string>development</string>
    
    <!-- Only if using VoIP push -->
    <key>com.apple.developer.pushkit</key>
    <array>
        <string>voip</string>
    </array>
</dict>
</plist>
```

**Note**: Change `aps-environment` to `production` for App Store builds.

## Step 3: Get Your API Key

1. Log in to [PushPlatform Dashboard](https://dashboard.pushplatform.example)
2. Navigate to **Settings → API Keys**
3. Create new key with **devices:write** scope
4. Copy the API key (starts with `pk_live_` or `pk_test_`)

## Step 4: Initialize SDK

### Import SDK

Add to your `AppDelegate.swift`:

```swift
import UIKit
import UserNotifications
import PushPlatformSDK
```

### Configure in didFinishLaunching

```swift
@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        // Configure SDK
        PushPlatform.shared.configure(
            apiKey: "pk_live_your_api_key_here",
            apiBaseURL: "https://api.pushplatform.example",
            environment: .production,
            debugMode: false  // Set true for development
        )
        
        // Set delegate
        PushPlatform.shared.delegate = self
        
        // Request notification permissions
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .sound, .badge]
        ) { granted, error in
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
}
```

## Step 5: Handle APNs Registration

Add these methods to `AppDelegate`:

```swift
extension AppDelegate {
    
    // APNs token received
    func application(_ application: UIApplication, 
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        print("📱 APNs token received")
        PushPlatform.shared.didRegisterAPNsToken(deviceToken)
    }
    
    // APNs registration failed
    func application(_ application: UIApplication, 
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("❌ APNs registration failed: \(error.localizedDescription)")
        PushPlatform.shared.didFailToRegisterAPNs(error)
    }
}
```

## Step 6: Implement Delegate

Implement `PushPlatformDelegate` to receive callbacks:

```swift
extension AppDelegate: PushPlatformDelegate {
    
    // SDK initialized with installation ID
    func didInitialize(installationID: UUID) {
        print("✅ SDK initialized: \(installationID)")
        // Save installation ID if needed
    }
    
    // Tokens registered successfully
    func didRegisterTokens() {
        print("✅ Tokens registered successfully")
    }
    
    // Token registration failed
    func didFailRegisterTokens(error: SDKError) {
        print("❌ Token registration failed: \(error)")
    }
    
    // Notification received (foreground or background)
    func didReceiveNotification(_ notification: Notification, context: NotificationContext) {
        print("📬 Notification received")
        print("   Title: \(notification.title ?? "nil")")
        print("   Body: \(notification.body ?? "nil")")
        print("   Foreground: \(context.isForeground)")
        
        // Handle notification data
        if let customData = notification.customData["order_id"] {
            print("   Order ID: \(customData)")
        }
    }
    
    // Notification tapped/opened
    func didOpenNotification(_ notification: Notification, action: String?, context: NotificationContext) {
        print("🔔 Notification opened")
        print("   Action: \(action ?? "default tap")")
        
        // Navigate to relevant screen
        if let orderID = notification.customData["order_id"] as? String {
            // Navigate to order details
        }
    }
    
    // Incoming VoIP call
    func didReceiveIncomingCall(callID: String, callerName: String, metadata: [String: Any]) {
        print("📞 Incoming call from \(callerName)")
        print("   Call ID: \(callID)")
        
        // CallKit UI will be shown automatically
    }
    
    // APNs token updated
    func didUpdateAPNsToken() {
        print("🔄 APNs token updated")
    }
    
    // VoIP token updated
    func didUpdateVoIPToken() {
        print("🔄 VoIP token updated")
    }
}
```

## Step 7: Handle Foreground Notifications

Implement `UNUserNotificationCenterDelegate` to handle foreground notifications:

```swift
extension AppDelegate: UNUserNotificationCenterDelegate {
    
    // Notification arrives while app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        print("📨 Foreground notification")
        
        // Delegate to SDK for parsing and deduplication
        PushPlatform.shared.handleForegroundNotification(notification, completionHandler: completionHandler)
    }
    
    // User tapped notification
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        print("📲 Notification tapped")
        
        // Delegate to SDK
        PushPlatform.shared.handleNotificationResponse(response, completionHandler: completionHandler)
    }
}
```

## Step 8: User Login (Optional)

Associate the installation with a user ID:

```swift
// When user logs in
PushPlatform.shared.login(userID: "user_12345") { result in
    switch result {
    case .success:
        print("✅ User logged in")
    case .failure(let error):
        print("❌ Login failed: \(error)")
    }
}

// When user logs out
PushPlatform.shared.logout { result in
    switch result {
    case .success:
        print("✅ User logged out")
    case .failure(let error):
        print("❌ Logout failed: \(error)")
    }
}
```

## Step 9: Test Push Notifications

### Test Alert Push (Sandbox)

Send a test notification from your backend:

```bash
curl -X POST https://api.pushplatform.example/v1/push/send \
  -H "Authorization: Bearer $PUSHPLATFORM_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "installation_id": "YOUR_INSTALLATION_ID",
    "notification": {
      "title": "Test Notification",
      "body": "This is a test from PushPlatform SDK",
      "badge": 1,
      "sound": "default"
    },
    "data": {
      "event_id": "evt_test_001",
      "custom_key": "custom_value"
    }
  }'
```

### Test VoIP Push

Send a VoIP push:

```bash
curl -X POST https://api.pushplatform.example/v1/push/voip \
  -H "Authorization: Bearer $PUSHPLATFORM_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "installation_id": "YOUR_INSTALLATION_ID",
    "call": {
      "call_id": "call_12345",
      "caller_name": "John Smith",
      "caller_number": "+1234567890"
    }
  }'
```

## Step 10: Verify Installation

Get your installation ID:

```swift
if let installationID = PushPlatform.shared.getInstallationID() {
    print("Installation ID: \(installationID)")
}
```

You can display this in your app's settings or debug screen for testing.

## Common Issues

### Push notifications not received

**Problem**: Device doesn't receive push notifications.

**Solutions**:
- Ensure running on **physical device** (not Simulator)
- Verify APNs certificate is configured in backend
- Check `aps-environment` matches certificate type (development/production)
- Verify bundle ID matches certificate
- Check device has internet connection

### Token registration fails

**Problem**: `didFailRegisterTokens` called with error.

**Solutions**:
- Check API key is valid
- Verify `apiBaseURL` is correct
- Check device has internet connection
- Enable debug mode to see detailed logs:
  ```swift
  PushPlatform.shared.configure(..., debugMode: true)
  ```

### VoIP push not working

**Problem**: VoIP push not received when app is terminated.

**Solutions**:
- Verify PushKit entitlement is enabled
- Check VoIP certificate configured in backend
- Implement CallKit integration (SDK handles this automatically)
- Test with sandbox environment first

### Duplicate notifications

**Problem**: Same notification appears multiple times.

**Solution**: SDK automatically deduplicates by `event_id`. Ensure your backend sends unique `event_id` for each notification:

```json
{
  "notification": { ... },
  "data": {
    "event_id": "evt_unique_12345"
  }
}
```

## Next Steps

- **[API Reference](API_REFERENCE.md)**: Explore all SDK methods and properties
- **[Troubleshooting](TROUBLESHOOTING.md)**: Solutions for common issues
- **[Example App](../Example/)**: See complete working example
- **[Compatibility Matrix](COMPATIBILITY_MATRIX.md)**: Supported iOS versions

## SwiftUI Integration

For SwiftUI apps, use `@UIApplicationDelegateAdaptor`:

```swift
import SwiftUI

@main
struct YourApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

Then implement `AppDelegate` as shown above.

## Advanced Topics

### Custom Notification Actions

Define custom actions in your notification payload:

```json
{
  "notification": {
    "title": "New Message",
    "body": "You have a new message",
    "category": "MESSAGE_CATEGORY"
  }
}
```

Register categories in your app:

```swift
let replyAction = UNTextInputNotificationAction(
    identifier: "REPLY_ACTION",
    title: "Reply",
    options: []
)

let category = UNNotificationCategory(
    identifier: "MESSAGE_CATEGORY",
    actions: [replyAction],
    intentIdentifiers: [],
    options: []
)

UNUserNotificationCenter.current().setNotificationCategories([category])
```

Handle in delegate:

```swift
func didOpenNotification(_ notification: Notification, action: String?, context: NotificationContext) {
    if action == "REPLY_ACTION" {
        // Handle reply action
    }
}
```

### Silent Push Notifications

Send silent push for background updates:

```json
{
  "notification": {
    "content_available": 1
  },
  "data": {
    "background_task": "sync_messages"
  }
}
```

Handle in `didReceiveNotification` - no UI will be shown.

### Debug Logging

Enable debug mode to see detailed logs:

```swift
PushPlatform.shared.configure(..., debugMode: true)
```

Logs will show:
- Token registration flow
- API requests/responses (tokens masked)
- Notification parsing
- Deduplication checks
- Retry attempts

**Important**: Disable debug mode in production builds.

## Production Checklist

Before releasing to App Store:

- [ ] Change `aps-environment` to `production`
- [ ] Use production APNs certificate
- [ ] Set `debugMode: false`
- [ ] Use `pk_live_` API key
- [ ] Test on multiple iOS versions
- [ ] Test push notifications in production environment
- [ ] Verify no console logs expose sensitive data
- [ ] Test app reinstall flow
- [ ] Test token rotation
- [ ] Test offline/online transitions

## Support

Need help? Check these resources:

- **Documentation**: [Full documentation](../docs/)
- **Example App**: [Working example](../Example/)
- **Troubleshooting**: [Common issues](TROUBLESHOOTING.md)
- **Issues**: [GitHub Issues](https://github.com/your-org/push-platform-sdk-ios/issues)
- **Email**: support@pushplatform.example

---

**Estimated integration time**: 15 minutes  
**Difficulty**: Beginner-friendly
