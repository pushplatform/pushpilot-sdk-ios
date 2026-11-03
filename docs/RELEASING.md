# Выпуск самостоятельного iOS SDK PushPilot

Актуальный порядок выпуска. Архив публикации 1.0.0 ниже его не отменяет. Инструкция по установке находится в [README.md](../README.md).

## Куда публикуется каждая версия

Выпуск не закрыт, пока одна и та же версия не попала в оба канала:

1. Swift Package Manager и каталог [Swift Package Index](https://swiftpackageindex.com/pushplatform/pushpilot-sdk-ios).
2. CocoaPods Trunk.

Тег и GitHub Release без этих двух шагов выпуск не закрывают. Опубликованный тег не двигать и не переиспользовать. Уже принятую Trunk версию не перезаливать.

### Swift Package Manager и Swift Package Index

SPM ставит пакет по git-тегу `vX.Y.Z` из `https://github.com/pushplatform/pushpilot-sdk-ios.git`. В коммите тега должен быть корневой `Package.swift`. Отдельного реестра, куда заливают архив, у SPM нет.

Swift Package Index — каталог, в котором пакет ищут. Репозиторий добавлен и влит: [PackageList #16012](https://github.com/SwiftPackageIndex/PackageList/pull/16012), URL `https://github.com/pushplatform/pushpilot-sdk-ios.git`. Следующий semver-тег индекс подхватывает сам. Повторный pull request на каждую новую версию не нужен.

Если страницы пакета в индексе нет, выпуск не закрывать. Нужно снова отправить этот URL в [SwiftPackageIndex/PackageList](https://github.com/SwiftPackageIndex/PackageList): issue по шаблону Add Package или pull request в `packages.json`. Готово только после вливания.

### CocoaPods Trunk

Та же версия уходит в Trunk:

```sh
pod trunk push PushPlatformSDK.podspec --allow-warnings
```

Номер в podspec равен тегу. Готово, когда Trunk API, публичный spec и CDN-индекс отдают эту версию. Локальный pod и успешный lint без регистрации в Trunk публикацией не считаются. Если ответ Trunk неоднозначный, сначала проверить версию, spec и индекс и не отправлять ту же версию второй раз. CDN может отстать от уже принятого spec.

React Native и Flutter, которые тянут `PushPlatformSDK` через CocoaPods, выпускаются после появления этой версии в индексе Trunk. Пока её там нет, их `pod install` не соберётся.

По [плану CocoaPods](https://blog.cocoapods.org/CocoaPods-Specs-Repo/) приём новых podspec постоянно закроется 2 декабря 2026. Уже залитые версии останутся. До этой даты каждая новая версия SDK публикуется в Trunk, пропуск не заменяет публикацию. Пробная read-only неделя 2–6 ноября 2026 отклоняет любой новый podspec до пятницы 6 ноября, 12:00 ET. Тег в эту неделю создавать можно, номер версии из-за отказа не повышать: `pod trunk push` повторить, когда приём откроется. После 2 декабря 2026 в отчёте о выпуске прямо пишется, что Trunk закрыт и новая версия туда не отправлялась. Тег SPM и наличие пакета в Swift Package Index остаются обязательными.

## Порядок нового выпуска

1. Подготовьте изменения и changelog для реальной новой версии, проведите review и выберите точный итоговый коммит. Изменения только документации не требуют повышения версии SDK, нового тега или GitHub Release.
2. Подготовьте release notes: установка через SPM и строка `pod 'PushPlatformSDK', 'X.Y.Z'`. Версия в podspec, README и notes одна и та же.
3. Из этого репозитория создайте тег новой версии на выбранном коммите и отправьте его в публичный origin. Ниже заполните версию, полный SHA и путь к подготовленным release notes:

   ```sh
   VERSION='X.Y.Z'
   RELEASE_COMMIT='<FULL_REVIEWED_COMMIT_SHA>'
   RELEASE_NOTES='/path/to/release-notes.md'
   git fetch origin --tags
   git tag -a "v${VERSION}" "${RELEASE_COMMIT}" -m "PushPilot iOS SDK ${VERSION}"
   git push origin "refs/tags/v${VERSION}"
   ```

4. После успешного push тега опубликуйте GitHub Release:

   ```sh
   gh release create "v${VERSION}" \
     --repo pushplatform/pushpilot-sdk-ios \
     --verify-tag \
     --title "PushPilot iOS SDK ${VERSION}" \
     --notes-file "${RELEASE_NOTES}"
   ```

   Если создание GitHub Release завершилось ошибкой, повторите этот шаг для уже отправленного тега. По тегу SPM уже видит версию. Это ещё не закрытый выпуск: впереди каталог и Trunk.

5. Проверьте страницу пакета в Swift Package Index. Репозиторий уже влит в PackageList запросом [#16012](https://github.com/SwiftPackageIndex/PackageList/pull/16012). Если страницы нет, отправьте `https://github.com/pushplatform/pushpilot-sdk-ios.git` снова и дождитесь вливания.
6. Опубликуйте ту же версию в CocoaPods Trunk командой из раздела выше. React Native и Flutter с зависимостью на этот pod выпускаются только после появления версии в CDN-индексе.

Не перемещайте и не переиспользуйте опубликованные теги, включая `v1.0.0`. Signing, Apple Developer и серверные APNs-данные для выпуска исходного Swift-пакета не нужны.

## Автоматизация

`.github/workflows/ci.yml` гоняет тесты и ничего не публикует. `.github/workflows/release.yml` по ручному запуску с `publish: true` выполняет `pod trunk push`. Этот запуск не проверяет Swift Package Index и сам по себе выпуск не закрывает.

Тег можно создать до секрета Trunk: иначе в read-only неделю SPM не выпустить. Закрытие выпуска всё равно ждёт оба канала из раздела «Куда публикуется каждая версия».

## Архив выпуска 1.0.0 — 2026-10-12

Ниже сохранён исторический журнал первого выпуска. Упоминания согласования SHA, авторизации и публикации Trunk относятся к выполненным действиям для 1.0.0; для новых выпусков действует порядок выше.

### Исходное состояние

- Инструкции `AGENTS.md` в SDK и цепочке родительских директорий не обнаружены.
- Рабочее дерево было чистым; исходная ветка `main`, коммит `dd759a5878cba045c50f1c4aec82069374106313`.
- Создана ветка `release/ios-sdk-1.0.0`.
- Origin: `https://github.com/pushplatform/pushpilot-sdk-ios.git`. GitHub API без авторизации сообщает `private: false`, `visibility: public`; анонимный Git endpoint возвращает HTTP 200. Изменять видимость или создавать новый репозиторий не нужно.
- В origin есть только `main`; опубликованных тегов и GitHub Releases нет. Локальный тег `private-alpha-foundation-2026-09-26` не является публичным релизом и не переносится.
- Старый changelog заявлял 1.0.0 от 2024-01-16 без подтверждения публикации. Номер podspec и модели SDK уже был 1.0.0; для первого самостоятельного релиза сохраняется 1.0.0.
- `split-source` — устаревший локальный remote. Он не используется для сборки, проверки или публикации. Соседние checkout не требуются.

### Изменения

- Удалён `unsafeFlags(["-enable-library-evolution"])`: SwiftPM запрещает зависимым пакетам использовать продукты с unsafe build flags. Для распространения исходников library evolution не требуется.
- CocoaPods сохранён: публичный Git URL, тег `v1.0.0`, реальные метаданные и полный набор используемых системных frameworks. Установка документирована через Git, без CocoaPods Trunk.
- Добавлен отсутствовавший файл MIT, ранее объявленный в README и podspec.
- Example manifest использует публичный URL и правильную package identity вместо локального path.
- README заменён русской инструкцией с `applicationID`, ожиданием completion, передачей APNs callbacks, настройкой APNs и фактическими ограничениями. Удалены недостоверные утверждения о протестированных версиях и отсутствующем Xcode-проекте.
- Реализация `Sources/` и существующие тесты не изменялись. Android и остальные компоненты не изменялись.

### Проверка

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

### Публикация после согласования коммита

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

### Публикация — 2026-10-12

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

### CocoaPods Trunk — публикация завершена, 2026-10-12

Владелец подтвердил авторизацию Trunk. Сессия успешно проверена; ранее проверенный `PushPlatformSDK.podspec` совпадает с файлом опубликованного тега `v1.0.0`.

- В Trunk отправлен JSON podspec через тот же endpoint и serializer, которые использует `pod trunk push`, без запуска его повторного локального lint/build. Серверная проверка Trunk сохранялась.
- Клиент получил ошибку `Calling the GitHub commit API timed out`. До повторной отправки проверено фактическое состояние: версия уже зарегистрирована и podspec опубликован. Повторный POST не выполнялся.
- Trunk API подтверждает `PushPlatformSDK` версии `1.0.0`, время регистрации `2026-10-12 11:55:19 UTC`; endpoint опубликованного spec возвращает HTTP 200.
- Публичный CocoaPods Specs содержит `Specs/a/4/5/PushPlatformSDK/1.0.0/PushPlatformSDK.podspec.json`; его raw URL и CocoaPods CDN возвращают HTTP 200. Источник spec — публичный Git SDK, тег `v1.0.0`.
- Опубликованный pod: https://cocoapods.org/pods/PushPlatformSDK (страница доступна, HTTP 200).
- GitHub Release обновлён: указаны завершённая публикация Trunk, ссылка на pod и установка `pod 'PushPlatformSDK', '1.0.0'`.
- README и CHANGELOG обновлены для опубликованной версии. Эти изменения документации сохраняются в `release/ios-sdk-1.0.0-publication`; тег `v1.0.0` не перемещался.
- Установку, lint, сборку, unit/integration/runtime-тесты и CI повторно не запускали. Реальные push, deploy и merge агентом не выполнялись.

Публикация iOS SDK 1.0.0 завершена: Swift Package Manager, CocoaPods Trunk и установка CocoaPods непосредственно из Git-тега доступны без приватных репозиториев и соседних checkout.
