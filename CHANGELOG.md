# Changelog

All notable changes to PushPlatform iOS SDK will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2024-01-16

### Initial Release

First production-ready release of PushPlatform iOS SDK.

### Added

#### Core Features
- **APNs Push Notifications**: Full support for alert, badge, sound, and silent push notifications
- **VoIP Push & CallKit**: Native incoming call notifications with CallKit integration
- **User Management**: Associate installations with external user IDs via login/logout
- **Token Management**: Automatic APNs and VoIP token registration and updates
- **Deduplication**: Prevent duplicate notifications using `event_id` tracking
- **Offline Support**: Automatic retry with exponential backoff (max 5 attempts)
- **Debug Mode**: Verbose logging without exposing device tokens

#### SDK Components
- `PushPlatform`: Main singleton façade
- `Configuration`: SDK configuration management
- `InstallationManager`: UUID generation and persistence in Keychain
- `TokenRegistry`: APNs and VoIP token storage
- `APNsTokenManager`: UIApplication integration for APNs tokens
- `PushKitManager`: PKPushRegistry integration for VoIP tokens
- `UserManager`: Login/logout with retry logic
- `NotificationDelegate`: UNUserNotificationCenter delegate implementation
- `NotificationParser`: Parse notification payloads
- `DeduplicationCache`: Event ID tracking for duplicate prevention
- `CallKitIntegration`: CXProvider for incoming call UI
- `APIClient`: HTTP client with retry logic
- `Logger`: Secure logging with token masking

#### Public API
- `configure(apiKey:apiBaseURL:environment:debugMode:)`: Initialize SDK
- `didRegisterAPNsToken(_:)`: Register APNs device token
- `didFailToRegisterAPNs(_:)`: Handle APNs registration failure
- `login(userID:completion:)`: Associate user with installation
- `logout(completion:)`: Disassociate user from installation
- `getInstallationID()`: Retrieve current installation UUID
- `handleForegroundNotification(_:completionHandler:)`: Process foreground notifications
- `handleNotificationResponse(_:completionHandler:)`: Process notification taps
- `delegate`: PushPlatformDelegate for SDK callbacks

#### Delegate Protocol
- `didInitialize(installationID:)`: SDK initialized callback
- `didRegisterTokens()`: Tokens registered successfully
- `didFailRegisterTokens(error:)`: Token registration failed
- `didReceiveNotification(_:context:)`: Notification received (foreground/background)
- `didOpenNotification(_:action:context:)`: User tapped notification
- `didReceiveIncomingCall(callID:callerName:metadata:)`: VoIP push received
- `didUpdateAPNsToken()`: APNs token updated
- `didUpdateVoIPToken()`: VoIP token updated

#### Models
- `Notification`: Parsed notification data with title, body, badge, sound, custom data
- `NotificationContext`: Delivery context (foreground/background)
- `Environment`: Development/Production enum
- `SDKError`: Comprehensive error types

#### Testing
- 137+ unit tests across all components
- 12 integration tests for SDK public API
- Mock implementations for testing
- 100% test coverage for critical paths

#### Documentation
- Complete README with Quick Start (5-line integration)
- Quick Start Guide (15-minute integration tutorial)
- API Reference (600+ lines, all public methods)
- Troubleshooting Guide (300+ lines, 10+ common issues)
- Compatibility Matrix (iOS 13-17, tested devices)
- Example App with SwiftUI and UIKit integration

#### Example App
- Complete working iOS app demonstrating SDK integration
- SwiftUI UI with installation ID display, token status, login/logout
- Real-time notification and call history
- 10 documented test scenarios
- Setup guide with APNs and VoIP configuration

### Platform Support
- **iOS**: 13.0+ (tested on 13.x through 17.x)
- **Xcode**: 14.0+ (Swift 5.7+)
- **Devices**: iPhone, iPad, iPod touch (physical devices required for push)
- **Simulators**: Limited (no push notification support)
- **Package Manager**: Swift Package Manager

### Security
- Device tokens masked in logs (first 8 hex chars only)
- No plaintext token storage in UserDefaults
- HTTPS required for all API calls
- Secure Keychain storage for installation ID

### Performance
- SDK initialization: < 100ms
- Token registration: < 500ms (network dependent)
- Notification parsing: < 1ms
- Binary size: ~400KB (release build)

### Known Limitations
- Push notifications require physical device (not Simulator)
- VoIP push requires CallKit (iOS 13+ requirement)
- Deduplication requires backend to send unique `event_id`

---

## Versioning Policy

- **Major version** (X.0.0): Breaking API changes
- **Minor version** (1.X.0): New features, backwards compatible
- **Patch version** (1.0.X): Bug fixes, backwards compatible

---

## Upgrade Guide

### From Pre-release to 1.0.0

First production release - no upgrade path.

---

## Deprecation Policy

- Deprecated APIs will be marked with `@available(*, deprecated)`
- Deprecations announced in minor versions
- Removed in next major version
- Minimum 6 months deprecation period

---

## Support Policy

| Version | Support Status | End of Support |
|---------|----------------|----------------|
| 1.0.x | ✅ Active | TBD |

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for contribution guidelines.

---

## Links

- [GitHub Repository](https://github.com/your-org/push-platform-sdk-ios)
- [Documentation](docs/)
- [Issues](https://github.com/your-org/push-platform-sdk-ios/issues)
- [Releases](https://github.com/your-org/push-platform-sdk-ios/releases)

---

[1.0.0]: https://github.com/your-org/push-platform-sdk-ios/releases/tag/v1.0.0
