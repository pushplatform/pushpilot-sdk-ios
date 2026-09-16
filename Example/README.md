# PushPlatform Example App

Demo iOS application showcasing PushPlatform SDK integration.

## Features

- SDK initialization with installation ID display
- APNs and VoIP token registration status
- User login/logout functionality
- Real-time notification display (foreground and background)
- Incoming call notifications
- Token status monitoring

## Requirements

- iOS 13.0+
- Xcode 14.0+
- Swift 5.7+

## Setup

### 1. Configure Signing

Open `Example/PushPlatformExample.xcodeproj` and configure:

- **Team**: Select your development team
- **Bundle Identifier**: Change to your unique identifier (e.g., `com.yourcompany.pushplatform.example`)

### 2. Enable Push Notifications

In Xcode project settings:

1. Go to **Signing & Capabilities**
2. Click **+ Capability**
3. Add **Push Notifications**
4. Add **Background Modes**:
   - Enable "Remote notifications"
   - Enable "Voice over IP"

### 3. Configure APNs

#### Development (Sandbox)

1. Go to Apple Developer Portal
2. Create APNs Development SSL certificate
3. Download and install certificate in Keychain
4. Export `.p12` file for backend configuration

#### Production

1. Create APNs Production SSL certificate
2. Update `Info.plist`: Change `aps-environment` to `production`
3. Update `AppDelegate.swift`: Change `environment` to `.production`

### 4. Run the App

```bash
cd Example
open PushPlatformExample.xcodeproj
```

Build and run on a physical device (push notifications don't work in Simulator).

## Testing Scenarios

### 1. SDK Initialization

**Expected**: Installation ID appears in UI immediately after launch.

**Verify**: Check console for `✅ SDK initialized with installation ID:`

### 2. Token Registration

**Expected**: APNs and VoIP token status changes from "Pending" to "Registered".

**Verify**: Check console for `📱 APNs token received` and `🔄 APNs token updated`

### 3. User Login

**Steps**:
1. Enter user ID (e.g., `user_12345`)
2. Tap "Login"
3. Wait for success

**Expected**: UI shows "Logged in as: user_12345"

**Verify**: Check console for `User login requested: userID=user_12345`

### 4. Foreground Notification

**Steps**:
1. Send push notification via backend API while app is in foreground
2. Notification banner appears at top of screen
3. Notification appears in "Recent Notifications" section

**Payload example**:
```json
{
  "aps": {
    "alert": {
      "title": "New Message",
      "body": "You have a new message from John"
    },
    "sound": "default",
    "badge": 1
  },
  "event_id": "evt_test_12345",
  "custom_key": "custom_value"
}
```

**Expected**:
- Banner displays with title and body
- Notification appears in list with event_id
- Console shows `📬 Notification received (foreground=true)`

### 5. Background Notification Tap

**Steps**:
1. Send push notification while app is in background
2. Tap notification from notification center
3. App opens and shows notification in list

**Expected**:
- App launches or becomes active
- Notification appears in "Recent Notifications"
- Console shows `🔔 Notification opened`

### 6. Duplicate Notification Suppression

**Steps**:
1. Send notification with `event_id`
2. Send same notification again with same `event_id`

**Expected**:
- First notification displays normally
- Second notification is suppressed
- Console shows `Duplicate event_id: evt_..., suppressing`

### 7. VoIP Push

**Steps**:
1. Send VoIP push via PushKit
2. CallKit UI appears (if CallKit integrated)
3. Call appears in "Recent Calls" section

**Payload example**:
```json
{
  "call_id": "call_67890",
  "caller_name": "Alice Smith",
  "caller_number": "+1234567890"
}
```

**Expected**:
- Call notification appears immediately
- Console shows `📞 Incoming call from Alice Smith`

### 8. Token Update

**Steps**:
1. Delete and reinstall app
2. Launch app
3. New tokens are registered

**Expected**:
- Installation ID persists (same UUID)
- New APNs and VoIP tokens sent to backend
- Console shows `🔄 APNs token updated`

### 9. User Logout

**Steps**:
1. Tap "Logout" button
2. Wait for success

**Expected**:
- UI returns to login form
- Installation remains active
- Console shows `User logout requested`

### 10. Error Handling

**Steps**:
1. Turn off network
2. Try to login
3. Observe retry behavior

**Expected**:
- Error alert appears after retries exhausted
- Console shows retry attempts with exponential backoff

## Troubleshooting

### No push notifications

- Verify running on physical device (not Simulator)
- Check APNs certificate is valid
- Verify `aps-environment` in entitlements matches certificate type
- Check Bundle ID matches certificate

### Token registration fails

- Check console for detailed error messages
- Verify push notification capability enabled
- Check entitlements file is included in build

### Notifications not appearing in UI

- Check delegate methods are called (console logs)
- Verify NotificationCenter observers are set up
- Check for any errors in console

## Architecture

```
AppDelegate
├─ SDK initialization (configure)
├─ Push registration (didRegisterForRemoteNotifications)
├─ PushPlatformDelegate implementation
└─ UNUserNotificationCenterDelegate implementation

ContentView (SwiftUI)
├─ Installation ID display
├─ Token status indicators
├─ Login/logout UI
├─ Notification list
└─ Call list

ContentViewModel
├─ State management (@Published properties)
├─ NotificationCenter observers
├─ SDK method calls (login/logout)
└─ UI updates
```

## Integration Testing

See `Tests/IntegrationTests/` for automated integration tests using mock backend.
