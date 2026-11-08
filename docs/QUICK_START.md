# Быстрый старт — iOS SDK 2.0.1

## Установка

В Xcode добавьте Swift Package Manager package:
`https://github.com/pushplatform/pushpilot-sdk-ios.git`, совместимый диапазон 2.x.
Приложению нужен продукт `PushPlatformSDK`; Notification Service Extension —
отдельный продукт `PushPlatformExtension` той же версии.

Для приложения через CocoaPods подключите SDK совместимой ветки 2.x:

```ruby
pod 'PushPlatformSDK', '>= 2.0.0', '< 3.0'
```

## Регистрация

Включите Push Notifications capability. В AppDelegate инициализируйте SDK с UUID
приложения из PushPilot. Ключ серверной отправки для регистрации устройства не нужен.

```swift
import PushPlatformSDK
import UIKit
import UserNotifications

PushPlatform.shared.initialize(.init(
    applicationId: "YOUR_APPLICATION_UUID",
    debugMode: false
)) { result in
    switch result {
    case .success:
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            if granted {
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
        }
    case .failure(let error):
        print(error.localizedDescription)
    }
}
```

SDK подключает APNs callbacks автоматически. При собственном forwarding из
AppDelegate вызовите `didRegisterAPNsToken(deviceToken)` и
`didFailToRegisterAPNs(error)` в соответствующих системных callbacks.

## Пользователь

```swift
PushPlatform.shared.login(userID: "user-123") { result in
    // Handle success or error.
}
PushPlatform.shared.logout { result in
    // Handle success or error.
}
```

`getInstallationID()` доступен после успешной регистрации. `getDeviceToken()`
возвращает APNs-токен, когда он выдан системой; `getSubscriptionID()` — ID подписки
после принятия токена сервером.

## Подтверждение доставки при закрытом приложении

Добавьте Notification Service Extension и подключите его отдельный pod
и настройте одну App Group `group.<app bundle ID>.pushplatform` в обоих targets и
provisioning profiles. В NotificationService.swift используйте
`import PushPlatformExtension`. Полный пример приведён в [README](../README.md).

```ruby
target 'PushPlatformNotificationServiceExtension' do
	pod 'PushPlatformExtension', '>= 2.0.0', '< 3.0'
end
```

## Входящие звонки

Включите Background Modes → Voice over IP. Приложение владеет одним CallKit
provider. При своём PushKit registry передавайте токен в `registerVoIPToken` и
payload в `handleVoIPNotification`. Альтернатива —
`startVoIPNotifications(handler:)` с нативным обработчиком приложения.
Обработчик сообщает вызов в CallKit и завершает PushKit callback после
`reportNewIncomingCall`, не ожидая запуска JS/Dart. Ответ, сигналинг и аудио
реализует приложение. Подробности: [MIGRATION_2.md](MIGRATION_2.md).
