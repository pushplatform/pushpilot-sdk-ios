# Changelog

All notable changes to PushPlatform iOS SDK will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Initial iOS SDK implementation (Phase 6A)
- Swift Package Manager support (iOS 13+)
- Installation ID management with Keychain storage
- APNs token registration (alert, silent)
- PushKit VoIP token support (planned)
- CallKit integration for incoming calls (planned)
- Foreground/background notification handling (planned)
- Event deduplication (LRU cache, 24h TTL) (planned)
- User login/logout API (planned)
- Offline retry with exponential backoff (planned)
- Debug logging with token masking
- Secure storage (no plaintext tokens)
- REST API v1 integration (planned)

## [1.0.0] - TBD

### Added
- First production release
- Complete APNs and PushKit integration
- CallKit support for VoIP calls
- Comprehensive documentation
- Example app
- 80+ unit tests
- Real device testing verification

---

**Note**: This SDK is currently in development (Phase 6A). Features marked as "planned" are scheduled for upcoming tasks.
