# Инструкция по настройке Windows-специфических файлов
# ────────────────────────────────────────────────────────────────

## 1. windows/runner/main.cpp
Добавь в начало функции wWinMain(), ДО создания окна:

```cpp
// Для корректной работы tray_manager
::SetProcessDpiAwarenessContext(DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2);
```

## 2. assets/images/elyon_logo.ico
Нужен .ico файл для иконки в трее.
Конвертируй elyon_logo.png → .ico онлайн (https://convertio.co/png-ico/)
Размеры: 16x16, 32x32, 48x48, 256x256 в одном .ico файле.
Положи в: assets/images/elyon_logo.ico

## 3. pubspec.yaml — добавь ico в assets
assets:
  - assets/images/
  - assets/fonts/
  - assets/images/elyon_logo.ico   # ← уже покрывается assets/images/

## 4. windows/runner/Runner.rc — иконка окна
В строке IDI_APP_ICON замени путь если нужно:
  IDI_APP_ICON ICON "resources\\app_icon.ico"
Положи elyon_logo.ico как resources/app_icon.ico внутри windows/runner/

## 5. flutter pub get
После обновления pubspec.yaml выполни:
  flutter pub get
  flutter pub upgrade

## 6. Команды сборки
# Debug запуск (Windows):
  flutter run -d windows

# Release сборка:
  flutter build windows --release

# Готовый exe будет в:
  build/windows/x64/runner/Release/elyon_ai.exe
