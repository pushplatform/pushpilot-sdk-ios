# PushPilot iOS SDK

Нативный SDK для регистрации устройства в PushPilot, уведомлений APNs и входящих VoIP-звонков. Пакет самостоятельный, без сторонних зависимостей. Исходный модуль и API сохраняют имена `PushPlatformSDK` и `PushPlatform`.

Требования: iOS 13+, Swift 5.5+; для примера на SwiftUI — Swift 5.7+. Сборка приложения требует Xcode с iOS SDK. macOS, watchOS и tvOS не поддерживаются.

## Установка через Swift Package Manager (рекомендуется)

Swift Package Manager (SPM) — основной способ установки SDK и получения новых версий. Новые версии выпускаются через Git-теги и GitHub Releases в этом репозитории; их доступность в SPM не зависит от публикации в CocoaPods Trunk.

В Xcode выберите **File → Add Package Dependencies**, укажите:

```text
https://github.com/pushplatform/pushpilot-sdk-ios.git
```

Выберите версию **1.2.7** или правило **Up to Next Major Version** от `1.2.7`. Добавьте продукт **PushPlatformSDK** в target приложения.

Для приложения с `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/pushplatform/pushpilot-sdk-ios.git", from: "1.2.7")
]
// В dependencies вашего target:
// .product(name: "PushPlatformSDK", package: "pushpilot-sdk-ios")
```

Репозиторий публичный: GitHub-токен, доступ к приватным репозиториям и соседние checkout не нужны.

## CocoaPods

`PushPlatformSDK` **1.2.7** ставится через Swift Package Manager. CocoaPods Trunk сейчас отдаёт **1.2.6**: версия 1.2.7 туда ещё не принята. Для нативного iOS-приложения через CocoaPods:

```ruby
platform :ios, '13.0'
target 'MyApp' do
  use_frameworks!
  pod 'PushPlatformSDK', '1.2.6'
end
```

Выполните `pod install --repo-update` и откройте `.xcworkspace`. При использовании React Native добавлять эту строку вручную не требуется: RN bridge объявляет зависимость, CocoaPods устанавливает её через autolinking. Expo plugin по-прежнему может использовать закреплённые исходники из npm-пакета.

Для одного target выбирайте один способ подключения SDK. При переходе на SPM удалите зависимость SDK из Podfile и выполните `pod install`, затем добавьте SPM package по инструкции выше. Продукт и импорт остаются `PushPlatformSDK`.

Порядок выпуска новых версий: [docs/RELEASING.md](docs/RELEASING.md).

## Подтверждение доставки при закрытом приложении

iOS показывает баннер и не запускает приложение. Счётчик `received` в этом случае отправляет Notification Service Extension. Без него баннер и открытие по нажатию остаются, а подтверждение получения при закрытом приложении не уходит. Пока приложение открыто, `received` отправляет основной SDK, extension для этого не нужен.

Готовый файл лежит в git и не входит в pod и в библиотеку SPM. Его компилирует только target extension:

[Sources/PushPlatformNotificationService/NotificationService.swift](Sources/PushPlatformNotificationService/NotificationService.swift)

1. В Xcode выберите **File → New → Target → Notification Service Extension**. На вопрос Activate scheme нажмите **Don't Activate**. Deployment Target совпадает с приложением и не ниже iOS 13.
2. Bundle ID extension — bundle ID приложения плюс `.PushPlatformNotificationService`. Для `com.example.app` это `com.example.app.PushPlatformNotificationService`.
3. На target приложения и на target extension включите capability **App Groups** и одну группу `group.<bundle id приложения>.pushplatform`. Для примера выше это `group.com.example.app.pushplatform`. В имени группы нет суффикса extension.
4. Замените созданный Xcode `NotificationService.swift` файлом по пути выше. Extension не меняет заголовок, текст и картинку баннера.

```swift
import UserNotifications

/// Add this file to a Notification Service Extension target. The extension bundle id
/// must be the application bundle id plus `.PushPlatformNotificationService`, and both
/// targets need the App Group `group.<application bundle id>.pushplatform`.
/// The extension reports receipt and does not change the banner.
class NotificationService: UNNotificationServiceExtension {
    override func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        guard let content = request.content.mutableCopy() as? UNMutableNotificationContent else {
            contentHandler(request.content)
            return
        }
        let userInfo = request.content.userInfo
        let notificationID = userInfo["notification_id"] as? String
        let bundleID = (Bundle.main.bundleIdentifier ?? "").replacingOccurrences(of: ".PushPlatformNotificationService", with: "")
        let defaults = UserDefaults(suiteName: "group.\(bundleID).pushplatform")
        let serverURL = defaults?.string(forKey: "server_url")
        let applicationID = defaults?.string(forKey: "application_id")
        let subscriptionID = defaults?.string(forKey: "subscription_id")
        guard let notificationID, !notificationID.isEmpty,
              let serverURL, let applicationID, let subscriptionID, !subscriptionID.isEmpty,
              let encoded = notificationID.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let url = URL(string: "\(serverURL)/notifications/\(encoded)") else {
            contentHandler(content)
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: [
            "app_id": applicationID,
            "subscription_id": subscriptionID,
            "received": true,
        ])
        let task = URLSession.shared.dataTask(with: request) { _, _, _ in
            contentHandler(content)
        }
        task.resume()
    }
}
```

React Native, Expo и Flutter этот target не создают. Его добавляет владелец приложения в Xcode тем же способом.

Получите UUID приложения PushPilot. Регистрация устройства секретный ключ не отправляет. Если нужен свой сервер, передайте его в `InitializeOptions.url`; без адреса SDK использует https://api.pushpilot.ru. Не встраивайте административные ключи и секреты APNs. Замените UUID в примере на свой.

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

        PushPlatform.shared.initialize("11111111-1111-1111-1111-111111111111") { result in
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

`configure` регистрирует installation асинхронно. Перед регистрацией APNs-токена, `login` и `logout` дождитесь `.success`. Вместо аргумента `applicationID` можно указать строку UUID в `Info.plist` под ключом `PushPlatformApplicationID`. UUID устройства сохраняется в Keychain; `getInstallationID()` возвращает ID, выданный сервером после успешной регистрации.

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
5. Для реальных VoIP-звонков добавьте **Background Modes → Voice over IP**, настройте серверный VoIP topic и отправляйте `call_id` в формате UUID и `caller_name`. SDK создаёт PushKit registry и CallKit provider автоматически; публичного переключателя отключения VoIP сейчас нет.

Подробности платформы: [регистрация APNs](https://developer.apple.com/documentation/usernotifications/registering-your-app-with-apns) и [ключи APNs](https://developer.apple.com/help/account/capabilities/communicate-with-apns-using-authentication-tokens/).

## Возможности и ограничения

- Регистрация installation, APNs/VoIP-токенов и привязка внешнего пользователя через `login`/`logout`.
- Обработка уведомлений в foreground и нажатий через переданные системные callbacks. Дедупликация по `event_id` работает в памяти текущего процесса; SDK не может отменить уже показанное системой фоновое уведомление.
- Повторные попытки регистрации токенов и login/logout при сетевых ошибках, HTTP 429 и 5xx. Очередь операций не сохраняется между запусками; автоматического retry первоначального `configure` нет.
- CallKit сообщает о входящем звонке, но SDK не реализует аудиотранспорт и публичные callbacks для управления разговором. Интеграцию звонков необходимо отдельно оценить для своего приложения и требований Apple.
- Разрешения, категории действий, переходы внутри приложения, rich media и обработка silent push настраиваются приложением. Доставка и фоновые запуски зависят от APNs и iOS.
- SDK не содержит сертификатов или подписанного бинарного framework: установка из исходников не требует signing самого пакета. Реальный APNs требует корректно подписанного приложения и серверной конфигурации; проверяйте доставку отдельно на устройстве.
- `debugMode: true` предназначен для разработки: логи могут содержать идентификаторы пользователя и installation. Используйте HTTPS URL своего API; значение URL по умолчанию является заполнителем.

[Исходники примера](Example/), [история изменений](CHANGELOG.md), [Issues](https://github.com/pushplatform/pushpilot-sdk-ios/issues). Лицензия — [MIT](LICENSE).


### Текущий контракт (1.2.1)

`initialize` принимает application id или options с `url` и `environment`. Секретный ключ для регистрации не нужен. `login(userID:metadata:)` записывает metadata в теги пользователя. `getDeviceToken()` возвращает последний hex APNs-токен или `nil`, пока система его не выдала. `preventDefault()` на показе в foreground скрывает баннер, звук и бейдж, если вызван до возврата делегата. При тапе SDK сам отправляет `PUT /notifications/{id}`, даже если приложение было закрыто; до `initialize` открытие ждёт в очереди. `notification.notificationID` — id из ответа `POST /notifications`, он не попадает в `customData`. `getSubscriptionID()` возвращает id подписки APNs после регистрации токена. Ставьте 1.2.7.

### Unified application contract (1.1.0)

Use one application ID and its permanent application key on every platform and your server.
The key is extractable from the client and permits device registration and message sending **only for that application**. It cannot manage the organization or billing. Rotate/revoke it in the console.
No project or environment selection is required. Existing explicit environment arguments remain supported for compatibility.
The SDK reports actual model, OS/SDK/app versions, language, time zone, notification permission and device kind. Unknown values remain unknown; emulator/simulator detection is not device attestation. A test subscription is a separate console flag.
Metadata refreshes on foreground entry and after a permission change.
APNs sandbox/production is a transport property: the SDK derives it from simulator/build entitlement when environment is omitted. Configure Push Notifications in Xcode and use a provisioning profile with the correct aps-environment.
