# Unified application SDK release

Version: 1.1.0. One application ID/key across SDKs and server. The key is deliberately extractable and grants device registration/read access and message sending/history only for that application; no organization/platform/billing administration.

No project/environment selection is needed. Optional legacy environment arguments remain compatible. APNs sandbox/production follows the build entitlement and is a transport property. Native SDK metadata includes real model/versions/locale/timezone/permission/device kind; Web reports unknown hardware kind. Test subscription is a separate console flag.

Validation on 2026-11-01: Android 170 tests and release Maven staging; iOS metadata tests plus 21 affected API/token integration tests on Simulator; RN 98 JS tests, Expo plugin tests, packed-distribution Maven/Pod probes and actual Android/iOS consumer builds; Flutter 74 tests and actual Android/iOS consumer builds. Web 91 unit tests, 11 browser scenarios headless and the actual notification display scenario in a visible macOS browser (headless macOS resolves showNotification without retaining a visible notification). The actual built Web SDK also registered through the unified real API and origin policy in console acceptance.

Console acceptance uses a disposable postgres database and real queue/worker with guarded mock transports. Same key registers iOS/Android/Web; two native devices share an External ID, metadata/tags/test-marker persist; composer creates one message/two accepted mock deliveries. No real push, credentials exchange with Apple/Firebase, or charging occurred. Real device/provider delivery still requires the customer's actual APNs/Firebase/Web credentials, OS permission and signed builds.

## Publication verified on 2026-11-01

SPM `v1.1.0` is published at commit `f04eaa4028d8f2d02c8bbecddec3084d84386295`. Native sources are also bundled into the wrappers. Bare React Native additionally resolves the public CocoaPods dependency: version 1.1.0 was published on 2026-11-01 from the unchanged v1.1.0 podspec. Bundled-path tests alone do not verify this integration. [PR #4](https://github.com/pushplatform/pushpilot-sdk-ios/pull/4).


## CocoaPods correction, 2026-11-01

Normal Trunk validation compiled SDK 1.1.0 from its immutable tag. Trunk returned an internal error after accepting the spec; version API reports a GitHub update conflict, while public Specs commit `9ad0dfc27d72d23843c49dee367e4125b4b4ec6b` and the podspec CDN expose the expected unchanged 1.1.0 spec. No duplicate push or tag movement was performed. The separate CDN version index must propagate before bare CocoaPods resolution succeeds. The RN repository now gates releases on the version index/spec/source and contains actual bare autolinking CI without a local native Pod override.
