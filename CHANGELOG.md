# 1.2.0 — 2026-11-01

- `initialize` takes an application id or options with `url` and `environment`. Registration does not send a secret.
- The SDK receives the APNs token and notification taps itself, and a foreground notification can call `preventDefault()`.
- CocoaPods `PushPlatformSDK` 1.2.0 and git tag `v1.2.0` are commit `c7f497f`. A later cache-eviction fix is not part of this tag.

# 1.1.0 — 2026-11-01

- Unified application ID and permanent shared application key for SDK and server; no project/environment setup step.
- Actual device kind, language, time zone, OS/SDK/app version and notification permission metadata. Unknown facts stay unknown.
- Optional legacy environment compatibility; iOS defaults to build-entitlement APNs transport detection.
- Test subscription remains a separate console marker.

# История изменений

## [1.0.0](https://github.com/pushplatform/pushpilot-sdk-ios/releases/tag/v1.0.0) — 2026-10-12

- Самостоятельное распространение существующего iOS SDK через публичный Swift Package Manager без сторонних зависимостей.
- Удалены небезопасные build flags, мешавшие использованию продукта как зависимости.
- CocoaPods podspec получает исходники из публичного Git по тегу `v1.0.0`.
- Podspec `PushPlatformSDK` версии `1.0.0` опубликован в [CocoaPods Trunk](https://cocoapods.org/pods/PushPlatformSDK).
- Добавлен файл ранее заявленной лицензии MIT.
- README на русском: установка, актуальная асинхронная регистрация с `applicationID`, APNs и ограничения SDK.
- Пример ссылается на публичный пакет вместо локального checkout.

Публичные имена модуля `PushPlatformSDK` и фасада `PushPlatform` сохранены. Реализация SDK не изменена.

До этого исходники содержали запись о версии 1.0.0 от 2024-01-16 без соответствующего публичного тега или GitHub Release. Первый подтверждённый самостоятельный выпуск опубликован 2026-10-12 из коммита `c67bcdf57ab150a5835570e4b695b173c1953bc1`.
