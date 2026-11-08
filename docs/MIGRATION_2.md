# Переход на PushPilot 2.0

## Обычные уведомления

Инициализация SDK регистрирует обычный APNs/FCM транспорт. Секретный ключ
отправки в мобильное приложение не помещается. При смене пользователя вызовите
login/external user ID, при выходе — logout; VoIP и alert подписки принадлежат
одной installation. Дождитесь успешной регистрации перед тестовой отправкой.
Ошибку регистрации нельзя считать успешной подпиской.

React Native позволяет подключить слушатели до initialize. Нативные ранние события
сохраняются до подключения соответствующего JS/Dart слушателя. Повторные initialize
для той же конфигурации разделяют один запрос; смена application/server/environment
в одном процессе отклоняется. Для фоновых APNs включите Remote notifications.
Нативный AppDelegate может явно передать userInfo в
`PushPlatform.shared.handleBackgroundNotification(userInfo)` и завершить собственный
fetch callback. SDK также подключает автоматический AppDelegate bridge.
Это не обещает запуск JS/Dart из silent push.

## Входящие звонки iOS

Обычный initialize больше не создаёт PushKit registry или CallKit provider.
В приложении должен быть ровно один владелец звонка и системного интерфейса.
Если приложение уже использует PushKit + CallKeep/CallKit:

1. Инициализируйте PushPilot нативно при запуске, с тем же UUID приложения, что в JS/Dart.
2. В существующем PushKit token callback вызовите
   `PushPlatform.shared.registerVoIPToken(credentials.token)`.
3. Передайте payload в `PushPlatform.shared.handleVoIPNotification(payload.dictionaryPayload)` для receipt.
   В incoming PushKit callback немедленно сообщите звонок своему CallKit provider,
   затем завершите PushKit completion. Не ждите загрузки JS/Dart или WebSocket.
4. После загрузки прикладного runtime восстановите состояние звонка с сервером,
   обработайте answer/decline, настройте аудиосессию и медиатранспорт.

Если собственного PushKit registry нет, создайте его через
`PushPlatform.shared.startVoIPNotifications { payload, completion in ... }`.
Handler выполняется нативно и обязан сообщить реальный входящий звонок CallKit.
PushPilot не реализует сигнализацию, WebRTC, ответ на звонок или аудио.
Схема бизнес-полей произвольна: transport передаёт payload без интерпретации.
Flutter `registerForVoIP()` проверяет наличие нативной интеграции.

Отправка входящего звонка: `notification_type: "voip"`, `priority: "critical_voip"`,
`ttl_seconds: 30` (или меньше), собственные call ID и deadline в custom data.
На iOS выбирается только apns_voip, на Android — срочное FCM data сообщение.
Поле `data.type` не выбирает транспорт. Нет подмены VoIP обычным alert.
Отмену передавайте через сигнализацию и явно background push. Background APNs
может задержаться; UI звонка обязан иметь локальный deadline и сверяться с сервером
перед ответом. Не отправляйте отмену или другие фоновые команды через VoIP.

## Android и существующий FirebaseMessagingService

Если приложение объявляет свой service для MESSAGING_EVENT, передавайте сообщения
в `PushPlatform.getInstance().handleRemoteMessage(context, message)` и новые токены
в `registerFcmToken(token)`. Для сообщения, UI которого показывает само приложение,
используйте `displayNotification = false`. SDK возвращает false для чужих сообщений.
Нативная обработка уведомления не должна зависеть от старта React Native/Flutter.
Телефон должен разрешать уведомления, а полноэкранные звонки требуют отдельных
Android permissions и системного calling API приложения.

## Установка

- React Native: `npm install @pushplatform/react-native`.
- Flutter: `flutter pub add push_platform_flutter`.
- Android: `implementation("com.pushplatform:sdk-android:[2.0.0,3.0)")`.
- iOS: Swift Package Manager с совместимым диапазоном 2.x или CocoaPods:

```ruby
pod 'PushPlatformSDK', '>= 2.0.0', '< 3.0'
```

React Native и Flutter подключают SDK основного приложения транзитивно.
Отдельные записи native SDK в основном target Podfile не нужны.
Для подтверждений доставки при закрытом iOS-приложении добавьте отдельный NSE target:

```ruby
target 'PushPlatformNotificationServiceExtension' do
	pod 'PushPlatformExtension', '>= 2.0.0', '< 3.0'
end
```

Проверяйте alert, открытие, badge, входящий звонок, answer, двустороннее аудио,
отмену, decline, expiry и повторную доставку на физических устройствах: foreground,
background, заблокированный экран, перезапуск процесса и восстановление сети.
Android force-stop в системных настройках требует ручного запуска приложения.
Доставку silent APNs нельзя гарантировать в каждом состоянии ОС.

Apple: https://developer.apple.com/documentation/pushkit/responding-to-voip-notifications-from-pushkit
Firebase: https://firebase.google.com/docs/cloud-messaging/flutter/receive-messages

## Подтверждения доставки iOS без запуска приложения

Notification Service Extension и основное приложение должны иметь одну App Group
`group.<bundle id приложения>.pushplatform` в entitlements и provisioning profiles.
SDK определяет bundle ID содержащего приложения независимо от имени extension.
Для собственной схемы группы задайте `PushPlatformAppGroup` в Info.plist обоих
таргетов; в extension можно явно задать `PushPlatformApplicationBundleID`.
Одного добавления capability только основному target недостаточно.
Каждое параллельное уведомление имеет собственные completion и receipt request.

При собственной Android Activity передайте новый notification Intent из
`onNewIntent` в `PushPlatform.getInstance().handleNotificationIntent(intent)` и
сохраните его через `setIntent(intent)`. Это нужно при уже работающей Activity.
Мосты React Native и Flutter делают это автоматически. У каждого уведомления
собственный PendingIntent: нажатие не должно подменяться последним пришедшим push.
