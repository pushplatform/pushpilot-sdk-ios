# iOS API — 2.0.3

Публичный фасад — `PushPlatform.shared` из модуля `PushPlatformSDK`.

## Инициализация

```swift
PushPlatform.shared.initialize(.init(
    applicationId: "YOUR_APPLICATION_UUID",
    debugMode: false
)) { result in
    // Result<UUID, SDKError>
}
```

Также поддерживается `initialize(applicationId, completion:)`. `InitializeOptions`
содержит applicationId, debugMode и
foregroundBannerFallback. Используется стандартный сервер PushPilot.
Ключ отправки в клиентском коде не требуется. Обычная инициализация включает APNs;
VoIP подключается отдельно. Повторная инициализация с той же конфигурацией ожидает
общий результат; изменение конфигурации в работающем процессе отклоняется.

## Установка, токены и пользователь

| Метод | Контракт |
| --- | --- |
| `getInstallationID() -> UUID?` | ID после регистрации на сервере |
| `getSubscriptionID() -> String?` | ID APNs-подписки после регистрации токена |
| `getDeviceToken() -> String?` | Последний APNs-токен или nil |
| `didRegisterAPNsToken(_ token: Data)` | Forwarding системного APNs callback |
| `didFailToRegisterAPNs(_ error: Error)` | Forwarding ошибки APNs |
| `refreshMetadata()` | Обновление информации об устройстве и разрешениях |
| `login(userID:metadata:completion:)` | Привязка внешнего пользователя; completion — Result<Void, SDKError> |
| `logout(completion:)` | Снятие привязки пользователя |

Ранние токены сохраняются до готовности регистрации. Изменения токена и пользователя
обрабатываются последовательно; сетевые операции повторяются после восстановления сети.

## События уведомлений

Назначьте `delegate: PushPlatformDelegate` до инициализации. Делегат получает
`didInitialize`, `didRegisterTokens`, `didFailRegisterTokens`,
`didReceiveNotification`, `didOpenNotification`, `didUpdateAPNsToken`,
`didUpdateVoIPToken` и `didUpdateDeviceToken`.

`notificationWillDisplay(_ event: NotificationDisplayEvent)` позволяет вызвать
`preventDefault()` до возврата обработчика. Для отложенного решения используйте
`deferDecision()`, затем `finish()`; foregroundBannerFallback ограничивает ожидание.

При собственной UNUserNotificationCenter/AppDelegate интеграции доступны
`handleBackgroundNotification`, `handleForegroundNotification` и
`handleNotificationResponse`. Счётчики доставки/открытия SDK отправляет сам.
`notificationID` отделён от пользовательского customData.

## VoIP

| Метод | Назначение |
| --- | --- |
| `registerVoIPToken(_ token: Data)` | Токен существующего PushKit registry |
| `handleVoIPNotification(_ payload: [AnyHashable: Any]) -> Bool` | Подтверждение получения host-owned VoIP push |
| `startVoIPNotifications(handler:)` | PushKit registry с нативным обработчиком приложения |
| `isVoIPConfigured` | Наличие нативной VoIP-интеграции |

Обработчик имеет тип `([AnyHashable: Any], @escaping () -> Void) -> Void`.
Он сообщает входящий в CallKit и завершает PushKit callback после нативного
`reportNewIncomingCall`. Приложение управляет provider, ответом, завершением,
сигналингом и аудио. Делегат обычных уведомлений не заменяет этот обработчик.

Полная интеграция: [MIGRATION_2.md](MIGRATION_2.md).

## Ошибки

Completion возвращает SDKError: notConfigured, networkError, apiError, invalidToken,
maxRetriesExceeded или keychainAccessDenied. Случай invalidAPIKey сохранён для совместимости; ключ отправки не является параметром initialize. HTTP status/message доступны в apiError.
Ошибка регистрации не означает готовую подписку. Секреты серверной отправки не
используются для device registration.
