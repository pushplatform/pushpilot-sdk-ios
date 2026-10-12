# Выпуск самостоятельного iOS SDK PushPilot

Внутренний журнал. Публичная инструкция для разработчика находится в `README.md`.

## Исходное состояние — 2026-10-12

- Инструкции `AGENTS.md` в SDK и цепочке родительских директорий не обнаружены.
- Рабочее дерево было чистым; исходная ветка `main`, коммит `dd759a5878cba045c50f1c4aec82069374106313`.
- Создана ветка `release/ios-sdk-1.0.0`.
- Origin: `https://github.com/pushplatform/pushpilot-sdk-ios.git`. GitHub API без авторизации сообщает `private: false`, `visibility: public`; анонимный Git endpoint возвращает HTTP 200. Изменять видимость или создавать новый репозиторий не нужно.
- В origin есть только `main`; опубликованных тегов и GitHub Releases нет. Локальный тег `private-alpha-foundation-2026-09-26` не является публичным релизом и не переносится.
- Старый changelog заявлял 1.0.0 от 2024-01-16 без подтверждения публикации. Номер podspec и модели SDK уже был 1.0.0; для первого самостоятельного релиза сохраняется 1.0.0.
- `split-source` — устаревший локальный remote. Он не используется для сборки, проверки или публикации. Соседние checkout не требуются.

## Изменения

- Удалён `unsafeFlags(["-enable-library-evolution"])`: SwiftPM запрещает зависимым пакетам использовать продукты с unsafe build flags. Для распространения исходников library evolution не требуется.
- CocoaPods сохранён: публичный Git URL, тег `v1.0.0`, реальные метаданные и полный набор используемых системных frameworks. Установка документирована через Git, без CocoaPods Trunk.
- Добавлен отсутствовавший файл MIT, ранее объявленный в README и podspec.
- Example manifest использует публичный URL и правильную package identity вместо локального path.
- README заменён русской инструкцией с `applicationID`, ожиданием completion, передачей APNs callbacks, настройкой APNs и фактическими ограничениями. Удалены недостоверные утверждения о протестированных версиях и отсутствующем Xcode-проекте.
- Реализация `Sources/` и существующие тесты не изменялись. Android и остальные компоненты не изменялись.

## Проверка

Существующие unit/integration/runtime-проверки не повторяются. История содержит `1fbad4d` (`audit: verify native iOS and Android runtime`) и последующие исправления контракта. Это сведения из истории, а не новый прогон или подтверждение старых численных claims о покрытии.

Новая проверка: один чистый iOS App, подключающий опубликованный release-коммит по HTTPS как remote Swift package. Пример `AppDelegate` извлекается непосредственно из README и компилируется вместе с SDK. Отдельные DerivedData, package cache и checkout; Git credentials отключены; нет локальных source dependencies. Команда:

```sh
ruby scripts/check-spm-installation.rb <PUBLISHED_COMMIT_SHA>
```

Требуются Xcode и Ruby gem `xcodeproj` (уже установлен вместе с CocoaPods на машине проверки). Сборка `generic/platform=iOS Simulator`, signing отключён. Приложение не запускается, реальные push и deploy не выполняются. Не запускать проверку повторно после успешного результата без новых изменений упаковки или SDK.

Результат — **PASS**, 2026-10-12:

- Опубликованный и проверенный коммит: `0dca1fbb8f4092779bed30b2a076d96e3709d8b7`.
- Xcode 26.3 (17C529), Apple Swift 6.2.4; `BUILD SUCCEEDED`.
- `Package.resolved` содержит ровно один pin: `pushpilot-sdk-ios`, публичный origin и точный проверенный SHA. Зависимостей из других репозиториев нет.
- Чистый consumer и лог: `/var/folders/by/6d96f_9s5p56nbyht2h4qzqh0000gn/T/pushpilot-ios-spm-20261012-29394-puxtaz/`, `build.log`. Эти временные артефакты не требуются пользователю для установки.
- CocoaPods: `pod ipc spec PushPlatformSDK.podspec` успешно разобрал spec; `pod spec lint PushPlatformSDK.podspec --quick --allow-warnings` — `PushPlatformSDK.podspec passed validation`. Это проверка метаданных, без отдельной CocoaPods-сборки и без установки ещё не опубликованного тега. Публикация в Trunk не входит в этот релиз.
- После проверки меняется только этот внутренний журнал. Исходники, Package.swift, podspec и README остаются точно теми, что проверены; повторная сборка не требуется.

CI на GitHub не запускался вручную и не ожидался; автоматический CI после push проверяет владелец. Реальные push, запуск приложения и deploy не выполнялись.

## Публикация после согласования коммита

CI проверяет владелец; агент не открывает браузер, не ждёт CI и не мержит PR. Создание публичного тега отложено до согласования точного SHA. Коммит для тега может быть review-коммитом release-ветки либо итоговым коммитом после merge; при squash необходимо явно согласовать новый SHA.

После согласования, из этого репозитория:

```sh
git fetch origin
# Подставить полный согласованный SHA, не main/HEAD.
git tag -a v1.0.0 <APPROVED_COMMIT_SHA> -m 'PushPilot iOS SDK 1.0.0'
git push origin refs/tags/v1.0.0
```

Не перемещать существующий тег. SPM и CocoaPods Git-installation получают версию именно по этому тегу; GitHub Release необязателен для установки.

Заголовок GitHub Release: `PushPilot iOS SDK 1.0.0`. Подготовленное описание:

> Первый самостоятельный выпуск iOS SDK PushPilot из публичного репозитория. Установка через Swift Package Manager или CocoaPods по Git-тегу v1.0.0. iOS 13+, без внешних зависимостей. Имена PushPlatformSDK и PushPlatform сохранены. Исправлены упаковка, метаданные и документация; реализация SDK не изменена. Настройка APNs и ограничения описаны в README.

Signing, Apple Developer и серверные APNs-данные для выпуска исходного Swift-пакета не нужны.

## Публикация — 2026-10-12

После merge PR #1 владелец разрешил выпуск из актуального `main`, включая GitHub Release и CocoaPods Trunk.

- Актуальный `main`: `c67bcdf57ab150a5835570e4b695b173c1953bc1` (`Merge pull request #1`). Дерево совпадает с `96b27f5576f7beece6390c561956183a7712d795`; упаковка и исходники совпадают с ранее проверенным коммитом.
- Создан и запушен annotated tag `v1.0.0`, указывающий на `c67bcdf57ab150a5835570e4b695b173c1953bc1`.
- GitHub Release опубликован, не draft и не prerelease: https://github.com/pushplatform/pushpilot-sdk-ios/releases/tag/v1.0.0 (2026-10-12T11:49:15Z).
- Установка SPM по версии 1.0.0 и CocoaPods по публичному Git-тегу теперь доступна.
- Пройденные проверки не повторялись. Реальные push, deploy и merge агентом не выполнялись.
- CocoaPods Trunk пока **не опубликован**: `pod trunk me` сообщает `You need to register a session first`; публичный Trunk API для `PushPlatformSDK` возвращает HTTP 404 (`No pod found with the specified name`).

Необходимое действие владельца на этой машине:

```sh
pod trunk register pavel.vladimiroff@gmail.com 'Pavel Vladimiroff' --description='PushPilot iOS SDK release'
```

При необходимости используйте другой адрес аккаунта CocoaPods. Подтвердите ссылку из письма и сообщите, что Trunk авторизован. Секреты, токен и ссылку из письма в чат не передавать. После появления сессии можно отправить ранее проверенный podspec в Trunk; повторять проверки установки или unit/runtime-тесты не нужно. Обычный `pod trunk push` автоматически повторяет локальный lint/build, поэтому при продолжении следует использовать Trunk API публикации того же JSON podspec, сохранив серверную проверку.

Этот журнал обновляется в отдельной ветке `release/ios-sdk-1.0.0-publication`; опубликованный тег остаётся на согласованном `main` и не перемещается.
