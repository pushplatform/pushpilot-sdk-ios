# API Reference

Complete API documentation for PushPlatform iOS SDK.

## Table of Contents

- [PushPlatform](#pushplatform)
- [Configuration](#configuration)
- [PushPlatformDelegate](#pushplatformdelegate)
- [Models](#models)
- [Errors](#errors)

---

## PushPlatform

Main SDK façade - singleton instance for push platform integration.

### Properties

#### `shared`

```swift
public static let shared: PushPlatform
```

Shared singleton instance. Use this to access all SDK functionality.

**Example**:
```swift
PushPlatform.shared.configure(apiKey: "pk_live_...", ...)
```

#### `delegate`

```swift
public weak var delegate: PushPlatformDelegate?
```

Delegate to receive SDK callbacks.

**Example**:
```swift
PushPlatform.shared.delegate = self
```

---

### Methods

#### `configure(apiKey:apiBaseURL:environment:debugMode:)`

Initialize SDK with API credentials and environment settings.

```swift
public func configure(
    apiKey: String,
    apiBaseURL: String,
    environment: Environment,
    debugMode: Bool
)
```

**Parameters**:
- `apiKey`: API key from dashboard (devices:write scope). Format: `pk_live_...` or `pk_test_...`
- `apiBaseURL`: Base URL for API (e.g., `https://api.pushplatform.example`)
- `environment`: `.development` or `.production`
- `debugMode`: Enable verbose logging (disable in production)

**Example**:
```swift
PushPlatform.shared.configure(
    apiKey: "<set API key from dashboard>",
    apiBaseURL: "https://api.pushplatform.example",
    environment: .production,
    debugMode: false
)
```

**Notes**:
- Must be called before any other SDK methods
- Typically called in `AppDelegate.didFinishLaunchingWithOptions`
- Installation ID is generated on first configuration
- Triggers `didInitialize(installationID:)` delegate callback

---

#### `didRegisterAPNsToken(_:)`

Register APNs device token received from system.

```swift
public func didRegisterAPNsToken(_ deviceToken: Data)
```

**Parameters**:
- `deviceToken`: Device token from `didRegisterForRemoteNotificationsWithDeviceToken`

**Example**:
```swift
func application(_ application: UIApplication, 
                 didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    PushPlatform.shared.didRegisterAPNsToken(deviceToken)
}
```

**Behavior**:
- Converts token to hex string
- Sends to backend via POST `/v1/installations/{id}/tokens`
- Retries on network errors with exponential backoff
- Triggers `didRegisterTokens()` on success or `didFailRegisterTokens(error:)` on failure

---

#### `didFailToRegisterAPNs(_:)`

Handle APNs registration failure.

```swift
public func didFailToRegisterAPNs(_ error: Error)
```

**Parameters**:
- `error`: Error from `didFailToRegisterForRemoteNotificationsWithError`

**Example**:
```swift
func application(_ application: UIApplication, 
                 didFailToRegisterForRemoteNotificationsWithError error: Error) {
    PushPlatform.shared.didFailToRegisterAPNs(error)
}
```

**Behavior**:
- Logs error with debug information
- Triggers `didFailRegisterTokens(error:)` delegate callback

---

#### `login(userID:completion:)`

Associate installation with external user ID.

```swift
public func login(
    userID: String,
    completion: @escaping (Result<Void, SDKError>) -> Void
)
```

**Parameters**:
- `userID`: External user ID from your system (e.g., `user_12345`)
- `completion`: Result callback

**Example**:
```swift
PushPlatform.shared.login(userID: "user_12345") { result in
    switch result {
    case .success:
        print("User logged in")
    case .failure(let error):
        print("Login failed: \(error)")
    }
}
```

**Behavior**:
- Sends PATCH `/v1/installations/{id}` with `external_user_id`
- Retries on network errors (max 5 attempts)
- Returns `.notConfigured` if SDK not initialized
- Returns `.maxRetriesExceeded` if all retries fail

**Retry Strategy**:
- Network errors: retry with exponential backoff
- 5xx/429 errors: retry
- 4xx errors: no retry (invalid request)
- Delay: min(2^attempt, 60) seconds

---

#### `logout(completion:)`

Disassociate user from installation (installation remains active).

```swift
public func logout(
    completion: @escaping (Result<Void, SDKError>) -> Void
)
```

**Parameters**:
- `completion`: Result callback

**Example**:
```swift
PushPlatform.shared.logout { result in
    switch result {
    case .success:
        print("User logged out")
    case .failure(let error):
        print("Logout failed: \(error)")
    }
}
```

**Behavior**:
- Sends PATCH `/v1/installations/{id}` with `external_user_id: null`
- Installation remains active (can still receive broadcasts)
- Same retry strategy as `login`

---

#### `getInstallationID()`

Get current installation ID.

```swift
public func getInstallationID() -> UUID?
```

**Returns**: Installation UUID or `nil` if not configured

**Example**:
```swift
if let installationID = PushPlatform.shared.getInstallationID() {
    print("Installation ID: \(installationID)")
}
```

---

#### `handleForegroundNotification(_:completionHandler:)`

Handle foreground notification (call from `willPresent` delegate).

```swift
@available(iOS 10.0, *)
public func handleForegroundNotification(
    _ notification: UNNotification,
    completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
)
```

**Parameters**:
- `notification`: UNNotification from system
- `completionHandler`: Presentation options callback

**Example**:
```swift
func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
) {
    PushPlatform.shared.handleForegroundNotification(notification, completionHandler: completionHandler)
}
```

**Behavior**:
- Parses notification payload
- Checks deduplication cache by `event_id`
- Suppresses duplicate notifications (empty presentation options)
- Fires `didReceiveNotification(_:context:)` delegate callback
- Returns `.banner` (iOS 14+) or `.alert` (iOS 13) + `.sound` + `.badge`

---

#### `handleNotificationResponse(_:completionHandler:)`

Handle notification response (call from `didReceive` delegate).

```swift
@available(iOS 10.0, *)
public func handleNotificationResponse(
    _ response: UNNotificationResponse,
    completionHandler: @escaping () -> Void
)
```

**Parameters**:
- `response`: UNNotificationResponse from system
- `completionHandler`: Completion callback

**Example**:
```swift
func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
) {
    PushPlatform.shared.handleNotificationResponse(response, completionHandler: completionHandler)
}
```

**Behavior**:
- Parses notification payload
- Checks deduplication (logs but doesn't suppress - user tapped)
- Fires `didOpenNotification(_:action:context:)` for default/custom actions
- No callback for dismiss action (`UNNotificationDismissActionIdentifier`)

---

## PushPlatformDelegate

Protocol for receiving SDK callbacks.

### Methods

#### `didInitialize(installationID:)`

SDK initialized with installation ID.

```swift
func didInitialize(installationID: UUID)
```

**Parameters**:
- `installationID`: Unique installation identifier

**Example**:
```swift
func didInitialize(installationID: UUID) {
    print("SDK initialized: \(installationID)")
    UserDefaults.standard.set(installationID.uuidString, forKey: "installation_id")
}
```

**Called**: After `configure()` completes

---

#### `didRegisterTokens()`

Tokens registered successfully with backend.

```swift
func didRegisterTokens()
```

**Example**:
```swift
func didRegisterTokens() {
    print("✅ Ready to receive push notifications")
}
```

**Called**: After successful token registration API call

---

#### `didFailRegisterTokens(error:)`

Token registration failed.

```swift
func didFailRegisterTokens(error: SDKError)
```

**Parameters**:
- `error`: Reason for failure

**Example**:
```swift
func didFailRegisterTokens(error: SDKError) {
    if case .networkError = error {
        // Retry will happen automatically
    } else {
        // Show error to user
        showAlert(message: "Failed to register: \(error)")
    }
}
```

---

#### `didReceiveNotification(_:context:)`

Notification received (foreground or background).

```swift
func didReceiveNotification(_ notification: Notification, context: NotificationContext)
```

**Parameters**:
- `notification`: Parsed notification data
- `context`: Delivery context (foreground/background)

**Example**:
```swift
func didReceiveNotification(_ notification: Notification, context: NotificationContext) {
    if context.isForeground {
        // Update UI in-app
        showInAppBanner(notification)
    }
    
    // Handle custom data
    if let orderID = notification.customData["order_id"] as? String {
        refreshOrder(orderID)
    }
}
```

---

#### `didOpenNotification(_:action:context:)`

User tapped notification.

```swift
func didOpenNotification(_ notification: Notification, action: String?, context: NotificationContext)
```

**Parameters**:
- `notification`: Parsed notification data
- `action`: Action identifier (`nil` for default tap, custom string for action button)
- `context`: Delivery context (always `isForeground: false`)

**Example**:
```swift
func didOpenNotification(_ notification: Notification, action: String?, context: NotificationContext) {
    if action == "REPLY_ACTION" {
        // Handle reply action
    } else {
        // Navigate to content
        if let screenID = notification.customData["screen_id"] as? String {
            navigate(to: screenID)
        }
    }
}
```

---

#### `didReceiveIncomingCall(callID:callerName:metadata:)`

VoIP push received - incoming call.

```swift
func didReceiveIncomingCall(callID: String, callerName: String, metadata: [String: Any])
```

**Parameters**:
- `callID`: Unique call identifier
- `callerName`: Caller display name
- `metadata`: Additional call data

**Example**:
```swift
func didReceiveIncomingCall(callID: String, callerName: String, metadata: [String: Any]) {
    // CallKit UI shown automatically
    // Prepare call connection
    if let callType = metadata["type"] as? String {
        setupCall(id: callID, type: callType)
    }
}
```

**Notes**:
- CallKit UI is shown automatically
- Called even when app is terminated
- Must complete quickly (< 10 seconds)

---

#### `didUpdateAPNsToken()`

APNs token updated (e.g., after app reinstall).

```swift
func didUpdateAPNsToken()
```

**Example**:
```swift
func didUpdateAPNsToken() {
    print("Token rotated - new token registered")
}
```

---

#### `didUpdateVoIPToken()`

VoIP token updated.

```swift
func didUpdateVoIPToken()
```

**Example**:
```swift
func didUpdateVoIPToken() {
    print("VoIP token rotated")
}
```

---

## Models

### Notification

Parsed notification data.

```swift
public struct Notification {
    public let title: String?
    public let body: String?
    public let badge: Int?
    public let sound: String?
    public let eventID: String?
    public let callID: String?
    public let customData: [String: Any]
}
```

**Properties**:
- `title`: Notification title
- `body`: Notification body text
- `badge`: Badge count
- `sound`: Sound filename
- `eventID`: Event identifier for deduplication
- `callID`: Call identifier (for VoIP)
- `customData`: All custom fields from payload

**Example Payload**:
```json
{
  "aps": {
    "alert": {
      "title": "New Message",
      "body": "You have a new message"
    },
    "badge": 3,
    "sound": "default"
  },
  "event_id": "evt_12345",
  "order_id": "ord_67890",
  "screen": "orders"
}
```

Parsed as:
```swift
Notification(
    title: "New Message",
    body: "You have a new message",
    badge: 3,
    sound: "default",
    eventID: "evt_12345",
    callID: nil,
    customData: ["order_id": "ord_67890", "screen": "orders"]
)
```

---

### NotificationContext

Delivery context for notification.

```swift
public struct NotificationContext {
    public let isForeground: Bool
}
```

**Properties**:
- `isForeground`: `true` if app was in foreground, `false` if background/terminated

---

### Environment

SDK environment configuration.

```swift
public enum Environment {
    case development
    case production
}
```

**Values**:
- `.development`: Use sandbox APNs
- `.production`: Use production APNs

---

## Errors

### SDKError

SDK error types.

```swift
public enum SDKError: Error {
    case notConfigured
    case invalidAPIKey
    case networkError(Error)
    case apiError(statusCode: Int, message: String)
    case maxRetriesExceeded
}
```

**Cases**:

#### `notConfigured`

SDK not initialized via `configure()`.

**Resolution**: Call `configure()` before other SDK methods.

#### `invalidAPIKey`

API key format is invalid.

**Resolution**: Check API key starts with `pk_live_` or `pk_test_`.

#### `networkError(Error)`

Network request failed.

**Resolution**: Check internet connection. SDK retries automatically.

#### `apiError(statusCode:message:)`

API returned error response.

**Resolution**: Check status code and message. 4xx errors indicate invalid request.

#### `maxRetriesExceeded`

All retry attempts failed.

**Resolution**: Check network connection and API status.

---

## Usage Examples

### Complete Integration

```swift
import UIKit
import UserNotifications
import PushPlatformSDK

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        // Configure SDK
        PushPlatform.shared.configure(
            apiKey: "pk_live_your_key",
            apiBaseURL: "https://api.pushplatform.example",
            environment: .production,
            debugMode: false
        )
        
        PushPlatform.shared.delegate = self
        
        // Request permissions
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            if granted {
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
        }
        
        UNUserNotificationCenter.current().delegate = self
        
        return true
    }
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        PushPlatform.shared.didRegisterAPNsToken(deviceToken)
    }
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        PushPlatform.shared.didFailToRegisterAPNs(error)
    }
}

extension AppDelegate: PushPlatformDelegate {
    func didInitialize(installationID: UUID) {
        print("Installation ID: \(installationID)")
    }
    
    func didRegisterTokens() {
        print("Ready to receive push")
    }
    
    func didFailRegisterTokens(error: SDKError) {
        print("Registration failed: \(error)")
    }
    
    func didReceiveNotification(_ notification: Notification, context: NotificationContext) {
        print("Notification: \(notification.title ?? "")")
    }
    
    func didOpenNotification(_ notification: Notification, action: String?, context: NotificationContext) {
        print("Opened: \(notification.title ?? "")")
    }
    
    func didReceiveIncomingCall(callID: String, callerName: String, metadata: [String : Any]) {
        print("Call from: \(callerName)")
    }
    
    func didUpdateAPNsToken() {
        print("APNs token updated")
    }
    
    func didUpdateVoIPToken() {
        print("VoIP token updated")
    }
}

extension AppDelegate: UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        PushPlatform.shared.handleForegroundNotification(notification, completionHandler: completionHandler)
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        PushPlatform.shared.handleNotificationResponse(response, completionHandler: completionHandler)
    }
}
```

---

## Thread Safety

All SDK methods are thread-safe and can be called from any thread. Delegate callbacks are dispatched on the main thread.

## Performance

- SDK initialization: < 100ms
- Token registration: < 500ms (network dependent)
- Notification parsing: < 1ms

## Binary Size

SDK bundle size: ~400KB (release build)

---

**Version**: 1.0.0  
**Last Updated**: 2024-01-16
