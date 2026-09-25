# Troubleshooting Guide

Common issues and solutions for PushPlatform iOS SDK.

## Quick Diagnostics

Enable debug mode to see detailed logs:

```swift
PushPlatform.shared.configure(
    apiKey: "pk_test_...",
    apiBaseURL: "https://api.pushplatform.example",
    environment: .development,
    debugMode: true  // Enable verbose logging
)
```

---

## Push Notifications

### Issue: No push notifications received

**Symptoms**: App doesn't receive push notifications.

**Possible Causes & Solutions**:

#### 1. Running on Simulator

**Problem**: iOS Simulator doesn't support push notifications.

**Solution**: Test on a physical iOS device.

#### 2. APNs Certificate Mismatch

**Problem**: APNs certificate doesn't match app's bundle ID.

**Solution**:
- Go to Apple Developer Portal → Certificates, Identifiers & Profiles
- Verify certificate bundle ID matches your app
- Download and install certificate
- Configure certificate in PushPlatform backend

#### 3. Wrong Environment

**Problem**: Using development certificate with production environment (or vice versa).

**Solution**:
- Check `aps-environment` in entitlements matches certificate type:
  ```xml
  <key>aps-environment</key>
  <string>development</string>  <!-- or "production" -->
  ```
- Verify SDK environment matches:
  ```swift
  environment: .development  // or .production
  ```

#### 4. Push Capability Not Enabled

**Problem**: Push Notifications capability not enabled in Xcode.

**Solution**:
1. Select app target
2. Go to Signing & Capabilities
3. Add Push Notifications capability
4. Clean build folder (⇧⌘K)
5. Rebuild

#### 5. User Denied Permission

**Problem**: User tapped "Don't Allow" when asked for notification permission.

**Solution**:
- Check permission status:
  ```swift
  UNUserNotificationCenter.current().getNotificationSettings { settings in
      print("Authorization status: \(settings.authorizationStatus)")
  }
  ```
- If denied, guide user to Settings → Notifications → YourApp → Allow Notifications

#### 6. Token Not Registered

**Problem**: Device token not sent to backend.

**Solution**:
- Check `didRegisterTokens()` callback is fired
- Enable debug mode and verify API request succeeds
- Check logs for error messages

---

### Issue: Token registration fails

**Symptoms**: `didFailRegisterTokens(error:)` called.

**Debugging**:

```swift
func didFailRegisterTokens(error: SDKError) {
    switch error {
    case .notConfigured:
        print("SDK not configured - call configure() first")
    case .invalidAPIKey:
        print("API key format invalid - check starts with pk_")
    case .networkError(let underlying):
        print("Network error: \(underlying)")
    case .apiError(let statusCode, let message):
        print("API error \(statusCode): \(message)")
    case .maxRetriesExceeded:
        print("All retries failed - check network")
    }
}
```

**Solutions by Error Type**:

#### `.notConfigured`

Call `configure()` before `didRegisterAPNsToken()`.

#### `.invalidAPIKey`

Check API key format:
- Development: `pk_test_...`
- Production: `pk_live_...`

#### `.networkError`

- Check device has internet connection
- Verify API base URL is correct
- SDK retries automatically (max 5 attempts)

#### `.apiError(401, ...)`

Invalid API key - verify key in dashboard.

#### `.apiError(404, ...)`

Installation not found - SDK will create new installation.

#### `.apiError(429, ...)`

Rate limited - SDK retries with backoff.

#### `.maxRetriesExceeded`

Network unstable - registration will retry when app next launches.

---

### Issue: Duplicate notifications

**Symptoms**: Same notification appears multiple times.

**Cause**: Backend sends same `event_id` multiple times.

**Solution**:

SDK automatically deduplicates by `event_id`. Ensure backend sends unique IDs:

```json
{
  "notification": { ... },
  "data": {
    "event_id": "evt_unique_12345"  // Must be unique
  }
}
```

**Verify Deduplication**:

Enable debug mode and check logs:
```
✅ Added event_id to deduplication cache: evt_12345
⚠️ Duplicate event_id: evt_12345, suppressing foreground notification
```

---

### Issue: Notifications not shown in foreground

**Symptoms**: Notification arrives but no banner shown while app is active.

**Cause**: Not implementing `UNUserNotificationCenterDelegate`.

**Solution**:

```swift
extension AppDelegate: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Delegate to SDK - handles deduplication and presentation
        PushPlatform.shared.handleForegroundNotification(notification, completionHandler: completionHandler)
    }
}

// Don't forget to set delegate
UNUserNotificationCenter.current().delegate = self
```

---

## VoIP Push

### Issue: VoIP push not received when app terminated

**Symptoms**: VoIP push works when app is active/background, but not when terminated.

**Possible Causes & Solutions**:

#### 1. PushKit Entitlement Missing

**Solution**:

Check entitlements file includes:
```xml
<key>com.apple.developer.pushkit</key>
<array>
    <string>voip</string>
</array>
```

#### 2. VoIP Certificate Not Configured

**Solution**:
- Create VoIP Services certificate in Apple Developer Portal
- Configure certificate in PushPlatform backend
- Verify certificate type is VoIP (not APNs)

#### 3. CallKit Not Implemented

**Problem**: Apple requires CallKit for VoIP push since iOS 13.

**Solution**: SDK handles CallKit automatically. Verify `didReceiveIncomingCall` is implemented:

```swift
func didReceiveIncomingCall(callID: String, callerName: String, metadata: [String: Any]) {
    print("Incoming call from \(callerName)")
    // CallKit UI shown automatically by SDK
}
```

#### 4. Testing in Wrong Environment

**Solution**: Test with sandbox VoIP certificate first, then production.

---

### Issue: CallKit UI not shown

**Symptoms**: VoIP push received but no incoming call screen.

**Debugging**:

Check console for:
```
📞 Incoming call from John Smith
   Call ID: call_12345
```

**Solutions**:

#### 1. CallKit Permission Denied

Check Info.plist includes:
```xml
<key>NSMicrophoneUsageDescription</key>
<string>We need microphone access for calls</string>
```

#### 2. Invalid Caller Info

CallKit requires non-empty caller name. Check payload:
```json
{
  "call_id": "call_12345",
  "caller_name": "John Smith",  // Must not be empty
  "caller_number": "+1234567890"
}
```

---

## User Management

### Issue: Login fails

**Symptoms**: `login(userID:completion:)` returns failure.

**Debugging**:

```swift
PushPlatform.shared.login(userID: "user_123") { result in
    if case .failure(let error) = result {
        print("Login error: \(error)")
    }
}
```

**Solutions**:

#### `.notConfigured`

Call `configure()` before `login()`.

#### `.networkError`

SDK retries automatically. Check:
- Device has internet
- API base URL is correct
- Firewall doesn't block requests

#### `.apiError(400, ...)`

Invalid user ID format. Ensure:
- User ID is not empty
- No special characters causing encoding issues

#### `.maxRetriesExceeded`

All retries failed. Try again when network is stable.

---

### Issue: Logout doesn't work

**Symptoms**: User still receives targeted push after logout.

**Expected Behavior**: After logout:
- Installation remains active
- User-targeted push won't be delivered
- Broadcast push still delivered

**Verification**:

Check backend logs show:
```
PATCH /v1/installations/{id}
{ "external_user_id": null }
```

If still receiving user push, backend targeting may be cached. Wait 1-2 minutes.

---

## Installation

### Issue: Installation ID changes on every app launch

**Symptoms**: New installation ID generated each launch.

**Cause**: Installation ID storage corrupted.

**Solution**:

Installation ID persists in Keychain automatically. If regenerating:
1. Delete app from device
2. Reinstall
3. Verify persistence:
   ```swift
   func didInitialize(installationID: UUID) {
       print("Installation ID: \(installationID)")
       // Should be same across launches
   }
   ```

---

### Issue: Multiple installations for same device

**Symptoms**: Backend shows multiple installation IDs for one device.

**Expected Behavior**: Each app install creates new installation ID.

**Scenarios**:
- ✅ Reinstall app → New installation ID (expected)
- ✅ Update app → Same installation ID (expected)
- ❌ App launch → New installation ID (bug - see above)

---

## Build & Integration

### Issue: SDK not found after adding package

**Symptoms**: `import PushPlatformSDK` shows "No such module".

**Solutions**:

1. Clean build folder: Product → Clean Build Folder (⇧⌘K)
2. Reset package caches: File → Packages → Reset Package Caches
3. Verify package added to correct target:
   - Select target → General → Frameworks, Libraries, and Embedded Content
   - Ensure PushPlatformSDK is listed
4. Rebuild project

---

### Issue: Compilation errors after SDK update

**Symptoms**: Breaking changes after SDK version update.

**Solution**:

Check [CHANGELOG.md](../CHANGELOG.md) for breaking changes.

For v1.x → v2.x migration, see MIGRATION_GUIDE.md.

---

## Performance

### Issue: Slow SDK initialization

**Symptoms**: `configure()` takes > 1 second.

**Expected**: < 100ms

**Debugging**:

```swift
let start = Date()
PushPlatform.shared.configure(...)
let duration = Date().timeIntervalSince(start)
print("SDK initialized in \(duration * 1000)ms")
```

**Solutions**:

1. Call `configure()` early in `didFinishLaunchingWithOptions`
2. Don't block main thread before configuration
3. Check for main thread locks/deadlocks

---

### Issue: High memory usage

**Symptoms**: App memory spikes after SDK initialization.

**Expected**: SDK uses < 2MB

**Cause**: Likely external to SDK. Profile with Instruments:
1. Product → Profile (⌘I)
2. Select Leaks instrument
3. Look for SDK-related leaks

If SDK-related, report issue with:
- Memory graph
- iOS version
- Device model

---

## Debugging Tips

### Enable Debug Logs

```swift
PushPlatform.shared.configure(..., debugMode: true)
```

Logs show:
- ✅ SDK initialization
- 📱 Token registration
- 🔄 API requests (tokens masked)
- 📬 Notification parsing
- 🚫 Deduplication checks
- 🔁 Retry attempts

### Check Installation ID

```swift
if let id = PushPlatform.shared.getInstallationID() {
    print("Installation ID: \(id)")
} else {
    print("SDK not configured")
}
```

### Verify Token Registration

```swift
func didRegisterTokens() {
    print("✅ Tokens registered - ready for push")
}

func didFailRegisterTokens(error: SDKError) {
    print("❌ Registration failed: \(error)")
}
```

### Test with cURL

Send test push:

```bash
curl -X POST https://api.pushplatform.example/v1/push/send \
  -H "Authorization: Bearer $PUSHPLATFORM_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "installation_id": "YOUR_INSTALLATION_ID",
    "notification": {
      "title": "Test",
      "body": "Manual test notification"
    }
  }'
```

---

## Common Error Messages

### "SDK not configured"

**Error**: `SDKError.notConfigured`

**Cause**: Calling SDK methods before `configure()`.

**Fix**: Call `configure()` in `didFinishLaunchingWithOptions`:
```swift
func application(_ application: UIApplication, didFinishLaunchingWithOptions ...) -> Bool {
    PushPlatform.shared.configure(...)  // Call first
    return true
}
```

---

### "Invalid API key format"

**Error**: `SDKError.invalidAPIKey`

**Cause**: API key doesn't match expected format.

**Fix**: Verify key starts with `pk_test_` or `pk_live_`.

---

### "No aps-environment entitlement"

**Error**: Token registration fails silently.

**Cause**: Entitlements file missing or not included in build.

**Fix**:
1. Verify entitlements file exists
2. Target → Build Settings → Code Signing Entitlements
3. Set to `YourApp/YourApp.entitlements`
4. Clean and rebuild

---

### "PushKit credential update failed"

**Error**: VoIP token registration fails.

**Cause**: VoIP certificate invalid or expired.

**Fix**:
1. Check certificate expiration in Apple Developer Portal
2. Regenerate if expired
3. Update backend configuration
4. Test with sandbox first

---

## Still Having Issues?

If problem persists:

1. **Check Example App**: Run [Example/](../Example/) to verify SDK works
2. **Enable Debug Mode**: `debugMode: true` for detailed logs
3. **Test Increments**: Isolate issue (APNs only? VoIP only? Both?)
4. **Minimal Reproduction**: Create minimal app reproducing issue
5. **Report Issue**:
   - GitHub: [Issues](https://github.com/your-org/push-platform-sdk-ios/issues)
   - Include: iOS version, Xcode version, debug logs, reproduction steps

---

## Emergency Troubleshooting

### Complete Reset

If all else fails:

1. Delete app from device
2. Clean build folder (⇧⌘K)
3. Quit Xcode
4. Delete derived data:
   ```bash
   rm -rf ~/Library/Developer/Xcode/DerivedData
   ```
5. Reopen project
6. Rebuild and reinstall
7. Check logs from fresh start

---

**Last Updated**: 2024-01-16  
**SDK Version**: 1.0.0
