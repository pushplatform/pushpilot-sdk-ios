# PushPilot iOS SDK

Нативный SDK для регистрации устройства в PushPilot, уведомлений APNs и входящих VoIP-звонков. Пакет самостоятельный, без сторонних зависимостей. Исходный модуль и API сохраняют имена `PushPlatformSDK` и `PushPlatform`.

Требования: iOS 13+, Swift 5.5+; для примера на SwiftUI — Swift 5.7+. Сборка приложения требует Xcode с iOS SDK. macOS, watchOS и tvOS не поддерживаются.

## Формы инициализации

Выполните один из вариантов один раз при запуске приложения.
`debugMode: true` включает диагностику; для обычной работы используйте `false`.

```swift
PushPlatform.shared.initialize(.init(
    applicationId: "YOUR_APPLICATION_UUID",
    debugMode: true
))

PushPlatform.shared.initialize("YOUR_APPLICATION_UUID")
```

## Установка через Swift Package Manager (рекомендуется)

Swift Package Manager (SPM) — основной способ установки SDK и получения новых версий. Новые версии выпускаются через Git-теги и GitHub Releases в этом репозитории; их доступность в SPM не зависит от публикации в CocoaPods Trunk.

В Xcode выберите **File → Add Package Dependencies**, укажите:

```text
https://github.com/pushplatform/pushpilot-sdk-ios.git
```

Выберите правило **Up to Next Major Version** от `2.0.0`. Добавьте продукт **PushPlatformSDK** в target приложения. Для Notification Service Extension добавьте продукт **PushPlatformExtension**, не полный SDK.

Для приложения с `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/pushplatform/pushpilot-sdk-ios.git", from: "2.0.0")
]
// В dependencies вашего target:
// .product(name: "PushPlatformSDK", package: "pushpilot-sdk-ios")
// NSE: .product(name: "PushPlatformExtension", package: "pushpilot-sdk-ios")
```

Репозиторий публичный: GitHub-токен, доступ к приватным репозиториям и соседние checkout не нужны.

## CocoaPods

Подключите SDK в target основного приложения:

```ruby
platform :ios, '13.0'
target 'MyApp' do
  use_frameworks!
  pod 'PushPlatformSDK', '>= 2.0.0', '< 3.0'
end
```

## Подтверждение доставки при закрытом приложении

iOS показывает баннер и не запускает приложение. Счётчик `received` в этом случае отправляет Notification Service Extension через `PushPlatformExtension` из пода. Без target баннер и открытие по нажатию остаются. Пока приложение открыто, `received` отправляет основной SDK.

1. В Xcode выберите **File → New → Target → Notification Service Extension**. На вопрос Activate scheme нажмите **Don't Activate**. Deployment Target совпадает с приложением и не ниже iOS 13.
2. Bundle ID extension — bundle ID приложения плюс `.PushPlatformNotificationService`. Для `com.example.app` это `com.example.app.PushPlatformNotificationService`.
3. На target приложения и на target extension включите capability **App Groups** и одну группу `group.<bundle id приложения>.pushplatform`. Для примера выше это `group.com.example.app.pushplatform`. В имени группы нет суффикса extension.
4. Подключите отдельный target extension с PushPlatformExtension. Основному приложению нужен PushPlatformSDK; он уже подключён в разделе CocoaPods выше.

```ruby
target 'PushPlatformNotificationServiceExtension' do
	pod 'PushPlatformExtension', '>= 2.0.0', '< 3.0'
end
```

```swift
import UserNotifications
import PushPlatformExtension

class NotificationService: UNNotificationServiceExtension {
    var contentHandler: ((UNNotificationContent) -> Void)?
    var receivedRequest: UNNotificationRequest!
    var bestAttemptContent: UNMutableNotificationContent?

    override func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        self.receivedRequest = request
        self.contentHandler = contentHandler
        bestAttemptContent = request.content.mutableCopy() as? UNMutableNotificationContent
        if let bestAttemptContent {
            PushPlatformExtension.didReceive(receivedRequest, with: bestAttemptContent, withContentHandler: contentHandler)
        } else {
            contentHandler(request.content)
        }
    }

    override func serviceExtensionTimeWillExpire() {
        if let contentHandler, let bestAttemptContent,
           PushPlatformExtension.serviceExtensionTimeWillExpireRequest(receivedRequest, with: bestAttemptContent) {
            contentHandler(bestAttemptContent)
        }
    }
}
```

В extension — только `import PushPlatformExtension`. `import PushPlatformSDK` даёт `No such module 'PushPlatformSDK'`, потому что полный SDK в NSE не линкуется. Extension не меняет заголовок, текст и картинку. React Native, Expo и Flutter этот target не создают. Его добавляет владелец приложения тем же способом.

Получите UUID приложения PushPilot. Регистрация устройства секретный ключ не отправляет.

```swift
import UIKit
import UserNotifications
import PushPlatformSDK

@main
final class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        let center = UNUserNotificationCenter.current()
        center.delegate = self

        PushPlatform.shared.initialize("YOUR_APPLICATION_UUID") { result in
            switch result {
            case .success:
                center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
                    guard granted, error == nil else { return }
                    DispatchQueue.main.async {
                        application.registerForRemoteNotifications()
                    }
                }
            case .failure(let error):
                print("PushPilot: \(error)")
            }
        }
        return true
    }

    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        PushPlatform.shared.didRegisterAPNsToken(deviceToken)
    }

    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        PushPlatform.shared.didFailToRegisterAPNs(error)
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        PushPlatform.shared.handleForegroundNotification(notification, completionHandler: completionHandler)
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        PushPlatform.shared.handleNotificationResponse(response, completionHandler: completionHandler)
    }
}
```

В существующем UIKit-приложении добавьте методы в свой `AppDelegate`, оставив его настройку UI. В SwiftUI подключите этот delegate через `@UIApplicationDelegateAdaptor(AppDelegate.self)` и уберите `@main` у `AppDelegate`.

`initialize` регистрирует installation асинхронно. Перед регистрацией APNs-токена, `login` и `logout` дождитесь `.success`. Передайте UUID приложения в `applicationId` или используйте короткую строковую форму. UUID устройства сохраняется в Keychain; `getInstallationID()` возвращает ID, выданный сервером после успешной регистрации.

После успешной настройки:

```swift
PushPlatform.shared.login(userID: "user-123") { result in
    // Обработка результата; при изменении UI перейдите на main queue.
}
PushPlatform.shared.logout { result in
    // Удаляется привязка пользователя; installation остаётся.
}
```

Для событий приложения назначьте `PushPlatform.shared.delegate`, реализовав `PushPlatformDelegate`. Delegate хранится слабо: приложение должно удерживать его. Тип уведомления SDK — `PushPlatformSDK.Notification`, чтобы не путать его с `Foundation.Notification`.

## Настройка APNs

1. Для Bundle ID приложения включите Push Notifications в Apple Developer и добавьте capability **Push Notifications** в Xcode. Signing profile должен включать entitlement `aps-environment`.
2. На стороне сервера PushPilot настройте APNs authentication key (`.p8`, Key ID, Team ID) либо поддерживаемый сервером сертификат. Эти данные остаются на сервере.
3. Согласуйте Bundle ID, APNs topic и окружение: `.development` для sandbox, `.production` для production. SDK не меняет signing и entitlements; `aps-environment` определяется профилем подписи, а не `Info.plist`.
4. Для silent push добавьте **Background Modes → Remote notifications** и обработчик `application(_:didReceiveRemoteNotification:fetchCompletionHandler:)` в приложении. SDK не предоставляет отдельного публичного обработчика фонового обновления.
5. Для реальных VoIP-звонков добавьте **Background Modes → Voice over IP**, настройте серверный VoIP topic и отправляйте `call_id` в формате UUID и `caller_name`. Приложение владеет CallKit provider. Передавайте VoIP-токен в `registerVoIPToken` из своего PushKit registry либо вызовите `startVoIPNotifications(handler:)` с нативным обработчиком, который сообщает входящий в CallKit. Обычная инициализация SDK не включает VoIP.

Подробности платформы: [регистрация APNs](https://developer.apple.com/documentation/usernotifications/registering-your-app-with-apns) и [ключи APNs](https://developer.apple.com/help/account/capabilities/communicate-with-apns-using-authentication-tokens/).

## Возможности и ограничения

- Регистрация installation, APNs/VoIP-токенов и привязка внешнего пользователя через `login`/`logout`.
- Обработка уведомлений в foreground и нажатий через переданные системные callbacks. Дедупликация по `event_id` работает в памяти текущего процесса; SDK не может отменить уже показанное системой фоновое уведомление.
- Повторные попытки регистрации токенов и login/logout при сетевых ошибках, HTTP 429 и 5xx. При недоступности сети SDK повторяет инициализацию и регистрацию после восстановления соединения.
- Нативный VoIP handler передаёт входящий вызов приложению; приложение управляет CallKit, ответом, завершением и аудиотранспортом.
- Разрешения, категории действий, переходы внутри приложения, rich media и обработка silent push настраиваются приложением. Доставка и фоновые запуски зависят от APNs и iOS.
- SDK не содержит сертификатов или подписанного бинарного framework: установка из исходников не требует signing самого пакета. Реальный APNs требует корректно подписанного приложения и серверной конфигурации; проверяйте доставку отдельно на устройстве.
- `debugMode: true` предназначен для разработки: логи могут содержать идентификаторы пользователя и installation.

[Исходники примера](Example/), [история изменений](CHANGELOG.md), [Issues](https://github.com/pushplatform/pushpilot-sdk-ios/issues). Лицензия — [MIT](LICENSE).


### Текущий контракт (2.0.1)

`initialize` принимает UUID приложения либо options с applicationId и debugMode. Sandbox APNs определяется профилем подписания. Секретный ключ для регистрации не нужен. `login(userID:metadata:)` записывает metadata в теги пользователя. `getDeviceToken()` возвращает последний hex APNs-токен или `nil`, пока система его не выдала. `preventDefault()` на показе в foreground скрывает баннер, звук и бейдж, если вызван до возврата делегата. При тапе SDK сам отправляет `PUT /notifications/{id}`, даже если приложение было закрыто; до `initialize` открытие ждёт в очереди. `notification.notificationID` — id из ответа `POST /notifications`, он не попадает в `customData`. `getSubscriptionID()` возвращает id подписки APNs после регистрации токена.

### Unified application contract

Use the same application ID in SDKs on every platform. Device registration does not require a secret key. Keep the permanent application key in server code for sending notifications; rotate or revoke it in the console.
No project or environment selection is required. Existing explicit environment arguments remain supported for compatibility.
The SDK reports actual model, OS/SDK/app versions, language, time zone, notification permission and device kind. Unknown values remain unknown; emulator/simulator detection is not device attestation. A test subscription is a separate console flag.
Metadata refreshes on foreground entry and after a permission change.
APNs sandbox/production is a transport property: the SDK derives it from simulator/build entitlement when environment is omitted. Configure Push Notifications in Xcode and use a provisioning profile with the correct aps-environment.
