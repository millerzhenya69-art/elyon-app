# Elyon AI — Flutter Windows App

Cross-platform AI assistant. Built with Flutter, targeting Windows first,
then Android, macOS, Linux.

---

## Prerequisites

| Tool | Version | Install |
|------|---------|---------|
| Flutter SDK | ≥ 3.19 | https://flutter.dev/docs/get-started/install/windows |
| Dart | ≥ 3.0 | bundled with Flutter |
| Visual Studio 2022 | Community+ | with "Desktop development with C++" workload |
| Git | any | https://git-scm.com |

---

## 1. Clone & install dependencies

```bash
git clone https://github.com/YOUR_USERNAME/elyon-app.git
cd elyon-app
flutter pub get
```

---

## 2. Add fonts

Download and place in `assets/fonts/`:

```
assets/fonts/
  InstrumentSerif-Regular.ttf   ← fonts.google.com/specimen/Instrument+Serif
  InstrumentSerif-Italic.ttf
  DMSans-Light.ttf              ← fonts.google.com/specimen/DM+Sans
  DMSans-Regular.ttf
  DMSans-Medium.ttf
```

---

## 3. Add logo

Place your logo (PNG, transparent background) at:

```
assets/images/elyon_logo.png   ← recommended: 512×512px
```

Then update these files to use the real image instead of the "E" placeholder:
- `lib/widgets/top_nav_bar.dart` → `_NavIconBtn` logo section
- `lib/widgets/welcome_screen.dart` → `_FloatingLogo`
- `lib/widgets/messages_list.dart` → `_AiAvatar`

Replace placeholder containers with:
```dart
Image.asset('assets/images/elyon_logo.png', width: 26, height: 26)
```

---

## 4. Configure backend URL

Open `lib/services/ai_service.dart` and set your Render URL:

```dart
const String _kBaseUrl = 'https://YOUR-APP.onrender.com';
```

---

## 5. Run on Windows

```bash
flutter run -d windows
```

Build a release EXE:
```bash
flutter build windows --release
# Output: build/windows/x64/runner/Release/elyon_ai.exe
```

---

## Project structure

```
lib/
├── main.dart                   ← Entry point, window config
├── theme/
│   ├── app_colors.dart         ← Color tokens (mirrors web CSS vars)
│   ├── app_text_styles.dart    ← Typography (Instrument Serif + DM Sans)
│   └── app_theme.dart          ← ThemeData: dark / amoled / light
├── models/
│   ├── chat_message.dart       ← ChatMessage, ChatSession
│   ├── user_model.dart         ← AppUser, SubscriptionTier
│   └── app_settings.dart       ← AppSettings, AppThemeMode, AppLanguage
├── providers/
│   └── app_providers.dart      ← Riverpod: settings, user, sessions, chat
├── services/
│   ├── ai_service.dart         ← HTTP client for Flask backend
│   └── storage_service.dart    ← SharedPreferences persistence
├── screens/
│   ├── main_screen.dart        ← Shell: nav + panels router
│   └── settings_screen.dart    ← Settings + Pricing panels
└── widgets/
    ├── top_nav_bar.dart         ← Fixed 52px nav bar
    ├── sidebar_drawer.dart      ← Slide-down history + nav links
    ├── welcome_screen.dart      ← Empty-state: logo + chips + input
    ├── messages_list.dart       ← Chat bubbles + typing indicator
    └── chat_input_box.dart      ← Auto-grow textarea + send button
```

---

## Subscription tiers

| Plan | Model | Daily limit | Price |
|------|-------|-------------|-------|
| Core | DeepSeek | 15 msg/day | Free |
| Nova | Gemini Flash | 25 msg/day | 100 ₽/mo |
| Elyon PRO | Gemini Thinking | 40 msg/day | 200 ₽/mo |
| Elyon Absolution | Gemini Pro | 50 msg/day | 300 ₽/mo |

---

## Upcoming iterations

- [ ] Google OAuth sign-in
- [ ] Telegram Login Widget (via backend)
- [ ] Admin panel with real stats
- [ ] Voice message input
- [ ] ЮКасса + PayPal payment integration
- [ ] Android build
- [ ] macOS / Linux builds
```
