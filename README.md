# PushPilot iOS SDK

Нативный SDK для регистрации устройства в PushPilot, уведомлений APNs и входящих VoIP-звонков. Пакет самостоятельный, без сторонних зависимостей. Исходный модуль и API сохраняют имена `PushPlatformSDK` и `PushPlatform`.

Требования: iOS 13+, Swift 5.5+; для примера на SwiftUI — Swift 5.7+. Сборка приложения требует Xcode с iOS SDK. macOS, watchOS и tvOS не поддерживаются.

## Установка через Swift Package Manager

В Xcode выберите **File → Add Package Dependencies**, укажите:

```text
https://github.com/pushplatform/pushpilot-sdk-ios.git
```

Выберите версию **1.0.0** или правило **Up to Next Major Version** от `1.0.0`. Добавьте продукт **PushPlatformSDK** в target приложения.

Для приложения с `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/pushplatform/pushpilot-sdk-ios.git", from: "1.0.0")
]
// В dependencies вашего target:
// .product(name: "PushPlatformSDK", package: "pushpilot-sdk-ios")
```

Репозиторий публичный: GitHub-токен, доступ к приватным репозиториям и соседние checkout не нужны.

## CocoaPods

Версия 1.0.0 опубликована в [CocoaPods Trunk](https://cocoapods.org/pods/PushPlatformSDK):

```ruby
platform :ios, '13.0'
target 'MyApp' do
  use_frameworks!
  pod 'PushPlatformSDK', '1.0.0'
end
```

Выполните `pod install` и откройте созданный `.xcworkspace`. При необходимости установки непосредственно из публичного Git используйте `pod 'PushPlatformSDK', :git => 'https://github.com/pushplatform/pushpilot-sdk-ios.git', :tag => 'v1.0.0'`. Используйте в одном target один способ подключения SDK.

## Минимальный пример

Получите UUID приложения PushPilot, URL вашего API и предназначенный для SDK ключ со scope `devices:write`. Не встраивайте серверные административные ключи или ключ APNs в приложение. Замените значения в примере на свои; адрес `.example` ниже — заполнитель.

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

        PushPlatform.shared.configure(
            apiKey: "SDK_DEVICE_KEY",
            apiBaseURL: "https://api.your-company.example",
            environment: .development,
            applicationID: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        ) { result in
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
