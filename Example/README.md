# Исходники примера PushPilot

Эта папка содержит SwiftUI/UIKit-исходники для интеграции в собственное iOS-приложение; готового `.xcodeproj` здесь нет. Создайте iOS App в Xcode и подключите публичный Swift-пакет по [инструкции установки](../README.md).

`Package.swift` использует тот же публичный репозиторий и продукт `PushPlatformSDK`, без локального `path` и соседних checkout. Сам SwiftPM executable target не заменяет проект iOS-приложения с signing и capabilities.

При переносе исходников обновите параметры SDK по минимальному примеру в README, передайте `applicationID` либо задайте `PushPlatformApplicationID` в `Info.plist`. APNs-токен регистрируйте после успешного `configure`. Значения URL и ключей в исходниках — заполнители.

Настройка APNs, entitlements и ограничения VoIP описаны в [README](../README.md). Для проверки установки без запуска приложения используется `scripts/check-spm-installation.rb`; её результаты сохраняются отдельно в `docs/RELEASING.md`.
