# 1.2.7 — 2026-11-03

- При входе в приложение бейдж иконки становится 0 и серверный счётчик сбрасывается через `PUT /badge`.
- Notification Service Extension в `Sources/PushPlatformNotificationService` подтверждает получение, не меняя баннер. Target extension и App Group `group.<bundle id>.pushplatform` включает владелец приложения. Без них баннер остаётся, а `received` при закрытом приложении не отправляется.
- При входе SDK сообщает сессию для метрики `influenced`.

# 1.2.6 — 2026-11-02

- При тапе по уведомлению SDK отправляет `PUT /notifications/{id}`, включая запуск закрытого приложения. До `initialize` и до регистрации токена открытие ждёт в очереди. Приложению ничего вызывать не нужно.
- `Notification.notificationID` содержит id уведомления от сервера. Поле `notification_id` больше не попадает в `customData`.
- `getSubscriptionID()` возвращает id подписки APNs из ответа регистрации токена. Он хранится в Keychain.

# 1.2.5 — 2026-11-02

- `foregroundBannerFallback` задаёт секунды запасного системного баннера, если `finish()` не вызван. Ноль и отсутствие оставляют ожидание обработчика.

# 1.2.4 — 2026-11-02

- Внутренний адрес называется `serverURL`. Публичный `initialize` по-прежнему принимает `url`.
- Баннер foreground больше не показывается сам через 8 секунд. Он уходит из `finish()` после обработчика. Если обработчик не вернулся, баннер не показывается. Баннер до запуска процесса по-прежнему рисует система.

# 1.2.3 — 2026-11-02

- CocoaPods.org kept the 1.0.0 README after 1.2.2 because the GitHub commit API timed out. This version exists so the site can fetch the current install text. The SDK code is unchanged.

# 1.2.2 — 2026-11-02

- `login` принимает metadata и отправляет её в тело login. Сервер сохраняет её в тегах пользователя.
- Показ foreground-уведомления можно отложить до `finish()`, чтобы обёртка дождалась своего обработчика. Синхронный `preventDefault()` без откладывания работает как раньше.
- `getDeviceToken()` отдаёт последний hex APNs-токен.

# 1.2.1 — 2026-11-02

- Install instructions in the README and on CocoaPods say 1.2.1. The 1.2.0 CocoaPods page still embeds an older README that tells you to install 1.0.0.
- Deduplication eviction follows insertion order and is visible to the next lookup.

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
