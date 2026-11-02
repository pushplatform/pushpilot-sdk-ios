# PushPilot iOS SDK

Нативный SDK для регистрации устройства в PushPilot, уведомлений APNs и входящих VoIP-звонков. Пакет самостоятельный, без сторонних зависимостей. Исходный модуль и API сохраняют имена `PushPlatformSDK` и `PushPlatform`.

Требования: iOS 13+, Swift 5.5+; для примера на SwiftUI — Swift 5.7+. Сборка приложения требует Xcode с iOS SDK. macOS, watchOS и tvOS не поддерживаются.

## Установка через Swift Package Manager (рекомендуется)

Swift Package Manager (SPM) — основной способ установки SDK и получения новых версий. Новые версии выпускаются через Git-теги и GitHub Releases в этом репозитории; их доступность в SPM не зависит от публикации в CocoaPods Trunk.

В Xcode выберите **File → Add Package Dependencies**, укажите:

```text
https://github.com/pushplatform/pushpilot-sdk-ios.git
```

Выберите версию **1.2.2** или правило **Up to Next Major Version** от `1.2.2`. Добавьте продукт **PushPlatformSDK** в target приложения.

Для приложения с `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/pushplatform/pushpilot-sdk-ios.git", from: "1.2.2")
]
// В dependencies вашего target:
// .product(name: "PushPlatformSDK", package: "pushpilot-sdk-ios")
```

Репозиторий публичный: GitHub-токен, доступ к приватным репозиториям и соседние checkout не нужны.

## CocoaPods

`PushPlatformSDK` версии **1.2.2** — текущая версия в CocoaPods Trunk. Для нативного iOS-приложения:

```ruby
platform :ios, '13.0'
target 'MyApp' do
  use_frameworks!
  pod 'PushPlatformSDK', '1.2.2'
end
```

Выполните `pod install --repo-update` и откройте `.xcworkspace`. При использовании React Native добавлять эту строку вручную не требуется: RN bridge объявляет зависимость, CocoaPods устанавливает её через autolinking. Expo plugin по-прежнему может использовать закреплённые исходники из npm-пакета.

Для одного target выбирайте один способ подключения SDK. При переходе на SPM удалите зависимость SDK из Podfile и выполните `pod install`, затем добавьте SPM package по инструкции выше. Продукт и импорт остаются `PushPlatformSDK`.

Порядок выпуска новых версий: [docs/RELEASING.md](docs/RELEASING.md).

## Минимальный пример

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

`initialize` принимает application id или options с `url` и `environment`. Секретный ключ для регистрации не нужен. `login(userID:metadata:)` записывает metadata в теги пользователя. `getDeviceToken()` возвращает последний hex APNs-токен или `nil`, пока система его не выдала. `preventDefault()` на показе в foreground скрывает баннер, звук и бейдж, если вызван до возврата делегата. Ставьте 1.2.2.

### Unified application contract (1.1.0)

Use one application ID and its permanent application key on every platform and your server.
The key is extractable from the client and permits device registration and message sending **only for that application**. It cannot manage the organization or billing. Rotate/revoke it in the console.
No project or environment selection is required. Existing explicit environment arguments remain supported for compatibility.
The SDK reports actual model, OS/SDK/app versions, language, time zone, notification permission and device kind. Unknown values remain unknown; emulator/simulator detection is not device attestation. A test subscription is a separate console flag.
Metadata refreshes on foreground entry and after a permission change.
APNs sandbox/production is a transport property: the SDK derives it from simulator/build entitlement when environment is omitted. Configure Push Notifications in Xcode and use a provisioning profile with the correct aps-environment.
