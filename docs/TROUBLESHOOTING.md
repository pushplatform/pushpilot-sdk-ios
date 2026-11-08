# Диагностика iOS SDK 2.0.1

## Установка и версии

Используйте совместимые продукты PushPlatformSDK и PushPlatformExtension ветки 2.x. Для extension импортируйте PushPlatformExtension; для
приложения — PushPlatformSDK. Сверьте версии в Package.resolved или Podfile.lock.

## Регистрация

Передавайте UUID приложения PushPilot в initialize. Ключ серверной отправки для
регистрации не требуется. Проверьте результат initialize и didFailRegisterTokens:
получение APNs-токена ещё не означает принятую сервером подписку. При потере сети
SDK повторяет регистрацию. Не меняйте applicationId/URL в существующем процессе.

## Нет баннера

Проверьте системное разрешение уведомлений, Push Notifications capability,
подпись приложения и соответствие APNs transport entitlement. Учитывайте
foreground preventDefault и системные настройки показа уведомлений.

## Нет received при закрытом приложении

Проверьте Notification Service Extension, mutable-content в alert payload и общую
App Group у приложения и extension, включая entitlements/provisioning profiles.
Группа по умолчанию — group.<app bundle ID>.pushplatform; для своей группы задайте
PushPlatformAppGroup в Info.plist обоих targets. Не подключайте полный SDK к NSE.

## Не приходит входящий звонок

Обычный initialize включает APNs. Для VoIP настройте существующий PushKit registry
с forwarding токена/payload либо startVoIPNotifications(handler:). Приложение
сообщает звонок через свой CallKit provider до завершения PushKit callback.
Проверьте отдельную VoIP-подписку, credentials/topic, transport=voip и deadline.
JS/Dart и WebSocket не должны задерживать нативный reportNewIncomingCall.

## Ответ с заблокированного экрана

Сохраните нативное answer-событие до готовности runtime и payload. Восстановите
сигналинг, аудиосессию и состояние вызова. Один вызов должен иметь одного владельца
CallKit UI. Завершённые/истёкшие приглашения не должны открываться повторно.

[API](API_REFERENCE.md) · [Миграция](MIGRATION_2.md) ·
[Issues](https://github.com/pushplatform/pushpilot-sdk-ios/issues)
