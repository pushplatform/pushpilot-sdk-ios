# Compatibility Matrix

Supported platforms, iOS versions, and devices for PushPlatform iOS SDK.

## iOS Version Support

| iOS Version | Status | SDK Support | Notes |
|-------------|--------|-------------|-------|
| **iOS 17.x** | ✅ Fully Tested | Full support | Latest features supported |
| **iOS 16.x** | ✅ Fully Tested | Full support | All features work |
| **iOS 15.x** | ✅ Fully Tested | Full support | All features work |
| **iOS 14.x** | ✅ Tested | Full support | Uses `.banner` presentation |
| **iOS 13.x** | ✅ Tested | Full support | Minimum version, uses `.alert` presentation |
| **iOS 12.x** | ❌ Not Supported | - | Upgrade to iOS 13+ required |
| **iOS 11.x and older** | ❌ Not Supported | - | Not supported |

### Minimum Requirements

- **Deployment Target**: iOS 13.0+
- **SDK Version**: 1.0.0+
- **Swift**: 5.7+
- **Xcode**: 14.0+

---

## Xcode Compatibility

| Xcode Version | Swift Version | Status | Notes |
|---------------|---------------|--------|-------|
| **Xcode 15.x** | Swift 5.9 | ✅ Recommended | Latest stable |
| **Xcode 14.3+** | Swift 5.8 | ✅ Supported | Fully compatible |
| **Xcode 14.0-14.2** | Swift 5.7 | ✅ Supported | Minimum version |
| **Xcode 13.x** | Swift 5.6 | ⚠️ Limited | May work but not tested |
| **Xcode 12.x and older** | Swift 5.5- | ❌ Not Supported | Upgrade required |

---

## Device Support

### iPhone

| Device | iOS Range | APNs | VoIP | CallKit | Status |
|--------|-----------|------|------|---------|--------|
| iPhone 15 Pro Max | 17.x | ✅ | ✅ | ✅ | Tested |
| iPhone 15 Pro | 17.x | ✅ | ✅ | ✅ | Tested |
| iPhone 15 Plus | 17.x | ✅ | ✅ | ✅ | Tested |
| iPhone 15 | 17.x | ✅ | ✅ | ✅ | Tested |
| iPhone 14 Pro Max | 16.x-17.x | ✅ | ✅ | ✅ | Tested |
| iPhone 14 Pro | 16.x-17.x | ✅ | ✅ | ✅ | Tested |
| iPhone 14 Plus | 16.x-17.x | ✅ | ✅ | ✅ | Tested |
| iPhone 14 | 16.x-17.x | ✅ | ✅ | ✅ | Tested |
| iPhone 13 Pro Max | 15.x-17.x | ✅ | ✅ | ✅ | Tested |
| iPhone 13 Pro | 15.x-17.x | ✅ | ✅ | ✅ | Tested |
| iPhone 13 | 15.x-17.x | ✅ | ✅ | ✅ | Tested |
| iPhone 13 mini | 15.x-17.x | ✅ | ✅ | ✅ | Tested |
| iPhone 12 Pro Max | 14.x-17.x | ✅ | ✅ | ✅ | Tested |
| iPhone 12 Pro | 14.x-17.x | ✅ | ✅ | ✅ | Tested |
| iPhone 12 | 14.x-17.x | ✅ | ✅ | ✅ | Tested |
| iPhone 12 mini | 14.x-17.x | ✅ | ✅ | ✅ | Tested |
| iPhone 11 Pro Max | 13.x-16.x | ✅ | ✅ | ✅ | Tested |
| iPhone 11 Pro | 13.x-16.x | ✅ | ✅ | ✅ | Tested |
| iPhone 11 | 13.x-17.x | ✅ | ✅ | ✅ | Tested |
| iPhone XS Max | 13.x-16.x | ✅ | ✅ | ✅ | Compatible |
| iPhone XS | 13.x-16.x | ✅ | ✅ | ✅ | Compatible |
| iPhone XR | 13.x-16.x | ✅ | ✅ | ✅ | Compatible |
| iPhone X | 13.x-16.x | ✅ | ✅ | ✅ | Compatible |
| iPhone 8 Plus | 13.x-16.x | ✅ | ✅ | ✅ | Compatible |
| iPhone 8 | 13.x-16.x | ✅ | ✅ | ✅ | Compatible |
| iPhone 7 and older | Max iOS 12 | ❌ | ❌ | ❌ | Not supported |

### iPad

| Device | iOS Range | APNs | VoIP | CallKit | Status |
|--------|-----------|------|------|---------|--------|
| iPad Pro 12.9" (6th gen) | 15.x-17.x | ✅ | ✅ | ✅ | Tested |
| iPad Pro 11" (4th gen) | 16.x-17.x | ✅ | ✅ | ✅ | Tested |
| iPad Air (5th gen) | 15.x-17.x | ✅ | ✅ | ✅ | Tested |
| iPad (10th gen) | 16.x-17.x | ✅ | ✅ | ✅ | Tested |
| iPad mini (6th gen) | 15.x-17.x | ✅ | ✅ | ✅ | Tested |
| iPad Pro 12.9" (3rd-5th gen) | 13.x-17.x | ✅ | ✅ | ✅ | Compatible |
| iPad Pro 11" (1st-3rd gen) | 13.x-17.x | ✅ | ✅ | ✅ | Compatible |
| iPad Air (3rd-4th gen) | 13.x-17.x | ✅ | ✅ | ✅ | Compatible |
| iPad (7th-9th gen) | 13.x-17.x | ✅ | ✅ | ✅ | Compatible |
| iPad mini (5th gen) | 13.x-17.x | ✅ | ✅ | ✅ | Compatible |

### iPod touch

| Device | iOS Range | APNs | VoIP | CallKit | Status |
|--------|-----------|------|------|---------|--------|
| iPod touch (7th gen) | 13.x-15.x | ✅ | ⚠️ | ⚠️ | APNs only |

**Note**: iPod touch doesn't have cellular, so VoIP/CallKit functionality limited.

---

## Simulator Support

| Feature | Simulator | Physical Device |
|---------|-----------|-----------------|
| SDK Initialization | ✅ | ✅ |
| APNs Token Registration | ❌ | ✅ |
| VoIP Token Registration | ❌ | ✅ |
| Push Notifications | ❌ | ✅ |
| CallKit | ⚠️ Limited | ✅ |
| User Login/Logout | ✅ | ✅ |
| Notification Parsing | ✅ | ✅ |
| Deduplication | ✅ | ✅ |

**Testing Recommendation**: Always test push notifications on physical devices. Simulator can only test non-push SDK features.

---

## Feature Availability by iOS Version

### iOS 13.0+

✅ **Available**:
- APNs push notifications
- Silent push (content-available)
- VoIP push with PushKit
- CallKit integration
- Notification deduplication
- User management
- Offline retry
- Debug logging

⚠️ **Limitations**:
- Foreground notifications use `.alert` instead of `.banner`

### iOS 14.0+

✅ **New Features**:
- `.banner` presentation option for foreground notifications
- Improved notification grouping
- Widget support (app-level, not SDK)

### iOS 15.0+

✅ **New Features**:
- Focus mode integration
- Notification summaries
- Time-sensitive notifications (via payload)

### iOS 16.0+

✅ **New Features**:
- Live Activities (app-level, not SDK)
- Notification filtering

### iOS 17.0+

✅ **New Features**:
- Interactive widgets
- StandBy mode notifications

---

## Swift Package Manager

| SPM Version | Status | Notes |
|-------------|--------|-------|
| Swift 5.9 (Xcode 15) | ✅ Recommended | Latest |
| Swift 5.8 (Xcode 14.3) | ✅ Supported | Fully compatible |
| Swift 5.7 (Xcode 14.0) | ✅ Supported | Minimum |
| Swift 5.6 and older | ❌ Not Supported | Upgrade required |

---

## SwiftUI Compatibility

| SwiftUI Version | iOS Version | Status |
|-----------------|-------------|--------|
| SwiftUI 5.0 | iOS 17+ | ✅ Supported |
| SwiftUI 4.0 | iOS 16+ | ✅ Supported |
| SwiftUI 3.0 | iOS 15+ | ✅ Supported |
| SwiftUI 2.0 | iOS 14+ | ✅ Supported |
| SwiftUI 1.0 | iOS 13+ | ✅ Supported |

**Integration**: Use `@UIApplicationDelegateAdaptor` for AppDelegate setup.

---

## UIKit Compatibility

| UIKit Version | iOS Version | Status |
|---------------|-------------|--------|
| UIKit (iOS 17) | iOS 17+ | ✅ Fully Supported |
| UIKit (iOS 16) | iOS 16+ | ✅ Fully Supported |
| UIKit (iOS 15) | iOS 15+ | ✅ Fully Supported |
| UIKit (iOS 14) | iOS 14+ | ✅ Fully Supported |
| UIKit (iOS 13) | iOS 13+ | ✅ Fully Supported |

**Integration**: Standard AppDelegate implementation.

---

## Certificate Types

### APNs Certificates

| Environment | Certificate Type | Status |
|-------------|-----------------|--------|
| Development | APNs Development SSL | ✅ Supported |
| Production | APNs Production SSL | ✅ Supported |
| Universal | APNs Universal | ✅ Supported |

### VoIP Certificates

| Environment | Certificate Type | Status |
|-------------|-----------------|--------|
| Development | VoIP Services (Sandbox) | ✅ Supported |
| Production | VoIP Services (Production) | ✅ Supported |

---

## Network Requirements

| Requirement | Details |
|-------------|---------|
| **Protocol** | HTTPS only (TLS 1.2+) |
| **Connectivity** | Internet required for token registration |
| **IPv4** | ✅ Supported |
| **IPv6** | ✅ Supported |
| **Proxy** | ✅ System proxy supported |
| **VPN** | ✅ Compatible |

---

## Testing Environments

### Development (Sandbox)

| Feature | Status |
|---------|--------|
| APNs Sandbox | ✅ Supported |
| VoIP Sandbox | ✅ Supported |
| Development Provisioning | ✅ Supported |
| TestFlight | ✅ Supported |

### Production

| Feature | Status |
|---------|--------|
| APNs Production | ✅ Supported |
| VoIP Production | ✅ Supported |
| App Store | ✅ Supported |
| Enterprise Distribution | ✅ Supported |

---

## Known Issues

### iOS 13.0-13.1

**Issue**: VoIP push may not wake app from terminated state consistently.

**Workaround**: Update to iOS 13.2+.

**Status**: Fixed in iOS 13.2.

### iOS 14.0

**Issue**: CallKit may crash on first launch if microphone permission not granted.

**Workaround**: Request microphone permission before VoIP push.

**Status**: Fixed in iOS 14.1.

### Xcode 14.0

**Issue**: SPM cache corruption on first build.

**Workaround**: File → Packages → Reset Package Caches.

**Status**: Fixed in Xcode 14.1.

---

## Architecture Support

| Architecture | Status | Devices |
|--------------|--------|---------|
| arm64 | ✅ Supported | iPhone 5s and later, iPad Air and later |
| arm64e | ✅ Supported | iPhone XS and later |
| x86_64 (Simulator) | ✅ Supported | macOS Intel |
| arm64 (Simulator) | ✅ Supported | Apple Silicon Macs |

---

## Performance Benchmarks

Measured on iPhone 14 Pro (iOS 17.0):

| Operation | Duration | Notes |
|-----------|----------|-------|
| SDK Initialization | < 50ms | Average |
| Token Registration | < 300ms | Network dependent |
| Notification Parsing | < 1ms | Per notification |
| Deduplication Check | < 0.1ms | Cache lookup |
| Login API Call | ~200ms | Network dependent |

---

## Binary Size Impact

| Configuration | Size Impact |
|---------------|-------------|
| Debug Build | ~800KB |
| Release Build | ~400KB |
| With Bitcode | ~450KB |

**Note**: Actual size depends on app's other dependencies and build settings.

---

## Third-Party Dependencies

**None** - SDK has zero external dependencies.

Benefits:
- ✅ Small binary size
- ✅ No version conflicts
- ✅ Fast compilation
- ✅ Secure supply chain

---

## Testing Matrix

| Test Type | iOS 13 | iOS 14 | iOS 15 | iOS 16 | iOS 17 |
|-----------|--------|--------|--------|--------|--------|
| Unit Tests | ✅ | ✅ | ✅ | ✅ | ✅ |
| Integration Tests | ✅ | ✅ | ✅ | ✅ | ✅ |
| UI Tests | ✅ | ✅ | ✅ | ✅ | ✅ |
| Real Device Tests | ✅ | ✅ | ✅ | ✅ | ✅ |
| Simulator Tests | ⚠️ | ⚠️ | ⚠️ | ⚠️ | ⚠️ |

⚠️ Simulator tests exclude push notification functionality.

---

## Continuous Integration

| CI Platform | Status | Notes |
|-------------|--------|-------|
| GitHub Actions | ✅ Supported | Example workflow provided |
| Xcode Cloud | ✅ Supported | Native support |
| CircleCI | ✅ Supported | macOS executors |
| Travis CI | ✅ Supported | macOS images |
| Jenkins | ✅ Supported | macOS agents |
| Bitrise | ✅ Supported | Xcode stacks |

---

## Version History

| SDK Version | Release Date | Min iOS | Min Xcode | Status |
|-------------|--------------|---------|-----------|--------|
| 1.0.0 | 2024-01-16 | 13.0 | 14.0 | Current |

---

## Future Support

### Planned

- iOS 18 support (when released)
- Vision Pro support
- Mac Catalyst support

### Under Consideration

- watchOS push notifications
- tvOS support

---

## Questions?

If you encounter compatibility issues not listed here:

1. Check [Troubleshooting Guide](TROUBLESHOOTING.md)
2. Review [GitHub Issues](https://github.com/your-org/push-platform-sdk-ios/issues)
3. Contact support: support@pushplatform.example

---

**Last Updated**: 2024-01-16  
**SDK Version**: 1.0.0
