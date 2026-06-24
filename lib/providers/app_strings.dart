import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/app_settings.dart';
import '../models/user_model.dart';
import 'app_providers.dart';

class AppStrings {
  const AppStrings._(this.lang);
  final AppLanguage lang;

  bool get _ru => lang == AppLanguage.russian;

  // ── Welcome screen ────────────────────────────────────────────
  String get helloIAm            => _ru ? 'Привет, я '                            : 'Hello, I am ';
  String get elyonName           => 'Elyon';
  String get howCanIHelp         => _ru ? 'Чем могу помочь сегодня?'              : 'How can I help you today?';
  String get chipWhatCanYouDo    => _ru ? 'Что ты умеешь?'                         : 'What can you do?';
  String get chipShortStory      => _ru ? 'Напиши короткий рассказ'               : 'Write me a short story';
  String get chipQuantum         => _ru ? 'Объясни квантовые вычисления'          : 'Explain quantum computing';
  String get chipPlanWeek        => _ru ? 'Помоги спланировать неделю'            : 'Help me plan my week';
  String get chipTranslateRu     => _ru ? 'Переведи на русский'                   : 'Translate to Russian';
  String get chipDebugCode       => _ru ? 'Найди ошибку в коде'                   : 'Debug my code';

  // ── Top nav / model dropdown ──────────────────────────────────
  String get newChat              => _ru ? 'Новый чат'                             : 'New chat';
  // Фикс 1: убраны упоминания DeepSeek/Gemini — нейтральные описания
  String get modelCoreDesc        => _ru ? 'Быстро и бесплатно · 15 сообщ/день'   : 'Fast & free · 15 msg/day';
  String get modelNovaDesc        => _ru ? 'Умнее · 25 сообщ/день'                : 'Smarter responses · 25 msg/day';
  String get modelProDesc         => _ru ? 'Глубокое рассуждение · 30 сообщ/день' : 'Deep reasoning · 30 msg/day';
  String get modelAbsolutionDesc  => _ru ? 'Максимум возможностей · 30 сообщ/день': 'Maximum capability · 30 msg/day';

  // ── Sidebar ────────────────────────────────────────────────────
  String get recentChats      => _ru ? 'Недавние чаты'   : 'Recent Chats';
  String get noConversations  => _ru ? 'Пока нет чатов'  : 'No conversations yet';
  String get newChatTile      => _ru ? 'Новый чат'        : 'New Chat';
  String get navProfile       => _ru ? 'Профиль'          : 'Profile';
  String get navPricing       => _ru ? 'Тарифы'           : 'Pricing';
  String get navSettings      => _ru ? 'Настройки'        : 'Settings';
  String get navAdmin         => _ru ? 'Админ-панель'     : 'Admin Panel';
  String get navPrivacy       => _ru ? 'Политика конфиденциальности' : 'Privacy Policy';
  String get navTerms         => _ru ? 'Условия использования'       : 'Terms of Service';

  // ── Chat input ─────────────────────────────────────────────────
  String get messageElyon     => _ru ? 'Сообщение Elyon...' : 'Message Elyon...';
  String get dailyLimitHit    => _ru ? 'Дневной лимит сообщений достигнут' : 'Daily message limit reached';
  String get inputHint        => _ru
      ? 'Elyon может ошибаться. Проверяйте важную информацию.'
      : 'Elyon can make mistakes. Consider checking important information.';
  String get enterToSend      => _ru
      ? 'Enter — отправить · Shift+Enter — новая строка'
      : 'Enter to send · Shift+Enter for new line';
  String get dailyLimitReached => _ru
      ? 'Дневной лимит достигнут. Улучшите план.'
      : 'Daily limit reached. Upgrade to continue.';

  // ── Settings panel ────────────────────────────────────────────
  String get settingsTitle     => _ru ? 'Настройки'        : 'Settings';
  String get appearance        => _ru ? 'Внешний вид'      : 'Appearance';
  String get theme              => _ru ? 'Тема'             : 'Theme';
  String get fontSize           => _ru ? 'Размер шрифта'   : 'Font Size';
  String get language           => _ru ? 'Язык'             : 'Language';
  String get interfaceLanguage  => _ru ? 'Язык интерфейса' : 'Interface Language';
  String get chatSection        => _ru ? 'Чат'              : 'Chat';
  String get streamingResponses => _ru ? 'Потоковые ответы' : 'Streaming Responses';
  String get streamingSub       => _ru
      ? 'Показывать ответ ИИ по мере генерации'
      : 'Show AI reply as it is generated';

  String get themeDark   => _ru ? 'Тёмная'  : 'Dark';
  String get themeAmoled => 'AMOLED';
  String get themeLight  => _ru ? 'Светлая' : 'Light';

  String get fontSmall  => _ru ? 'Маленький' : 'Small';
  String get fontMedium => _ru ? 'Средний'   : 'Medium';
  String get fontLarge  => _ru ? 'Большой'   : 'Large';

  String get langEnglish => 'English';
  String get langRussian => 'Русский';

  // ── Pricing panel ─────────────────────────────────────────────
  String get pricingTitle  => _ru ? 'Тарифы'        : 'Pricing';
  String get free           => _ru ? 'Бесплатно'     : 'Free';
  String get perMonth       => _ru ? ' / месяц'      : ' / month';
  String get messagesPerDay => _ru ? 'сообщений / день' : 'messages / day';
  String get currentPlan    => _ru ? 'Текущий план'   : 'Current Plan';
  String get getStarted     => _ru ? 'Начать'          : 'Get Started';
  String get subscribe      => _ru ? 'Подписаться'     : 'Subscribe';

  // Фикс 1: нейтральные описания без упоминания DeepSeek/Gemini
  String tierDescription(SubscriptionTier tier) {
    if (!_ru) {
      switch (tier) {
        case SubscriptionTier.core:
          return 'Fast and always free. Perfect for everyday questions and quick tasks.';
        case SubscriptionTier.nova:
          return 'Smarter and faster. Built for work that demands real quality.';
        case SubscriptionTier.pro:
          return 'Deep reasoning and nuanced analysis for complex challenges.';
        case SubscriptionTier.absolution:
          return 'Maximum capability. The most powerful intelligence Elyon offers.';
      }
    }
    switch (tier) {
      case SubscriptionTier.core:
        return 'Бесплатно и быстро. Идеально для повседневных вопросов.';
      case SubscriptionTier.nova:
        return 'Умнее и быстрее. Создан для задач, требующих настоящего качества.';
      case SubscriptionTier.pro:
        return 'Глубокий анализ и рассуждение для сложных задач.';
      case SubscriptionTier.absolution:
        return 'Максимальные возможности. Самый мощный интеллект Elyon.';
    }
  }

  // ── Profile panel ──────────────────────────────────────────────
  String get profileTitle      => _ru ? 'Профиль'              : 'Profile';
  String get currentPlanLabel  => _ru ? 'Текущий план'          : 'Current Plan';
  String get authProvider      => _ru ? 'Способ авторизации'    : 'Auth Provider';
  String get memberSince       => _ru ? 'Дата регистрации'      : 'Member Since';
  String get upgradePlan       => _ru ? 'Улучшить план →'       : 'Upgrade Plan →';
  String get signOut           => _ru ? 'Выйти'                 : 'Sign Out';
  String messagesRemaining(int n) =>
      _ru ? '$n сообщений осталось сегодня' : '$n messages remaining today';

  // ── Auth screen ────────────────────────────────────────────────
  String get signIn               => _ru ? 'Войти'                      : 'Sign in';
  String get signUp               => _ru ? 'Регистрация'                : 'Sign up';
  String get createAccount        => _ru ? 'Создать аккаунт'            : 'Create account';
  String get continueWithGoogle   => _ru ? 'Продолжить с Google'        : 'Continue with Google';
  String get continueWithTelegram => _ru ? 'Продолжить с Telegram'      : 'Continue with Telegram';
  String get orContinueWithEmail  => _ru ? 'или продолжите с email'     : 'or continue with email';
  String get firstName            => _ru ? 'Имя'                         : 'First Name';
  String get lastName             => _ru ? 'Фамилия'                     : 'Last Name';
  String get email                => _ru ? 'Email'                       : 'Email';
  String get password             => _ru ? 'Пароль'                      : 'Password';
  String get alreadyHaveAccount   => _ru
      ? 'Уже есть аккаунт? Переключитесь ниже.'
      : 'Already have an account? Switch below.';
  String get newToElyon           => _ru
      ? 'Новичок в Elyon? Переключитесь на регистрацию ниже.'
      : 'New to Elyon? Switch to sign up below.';
  String get agreeTerms           => _ru
      ? 'Продолжая, вы соглашаетесь с Условиями использования и Политикой конфиденциальности Elyon.'
      : "By continuing you agree to Elyon's Terms of Service and Privacy Policy.";

  // ── Admin panel ────────────────────────────────────────────────
  String get adminTitle => _ru ? 'Админ-панель' : 'Admin Panel';

  // ── Telegram auth flow ─────────────────────────────────────────
  String get continueWithTelegramTitle => _ru ? 'Продолжить с Telegram' : 'Continue with Telegram';
  String get tgStep1    => _ru ? 'Откройте @Elyon_by_unkony_bot в Telegram'          : 'Open @Elyon_by_unkony_bot in Telegram';
  String get tgStep2    => _ru ? 'Отправьте /auth — бот пришлёт кнопку входа'         : 'Send /auth — the bot will reply with a login button';
  String get tgStep3    => _ru ? 'Нажмите «Login to Elyon AI» в сообщении бота'       : 'Tap "Login to Elyon AI" in the bot message';
  String get tgStep4    => _ru ? 'Скопируйте токен и вставьте его здесь'              : 'Copy the token and paste it here';
  String get openTelegramBot       => _ru ? 'Открыть Telegram-бота' : 'Open Telegram Bot';
  String tgWaiting(int s)          => _ru ? 'Ожидание входа через Telegram... (${s}с)' : 'Waiting for Telegram login... (${s}s)';
  String get pasteTokenManually    => _ru ? 'Вставить токен вручную →' : 'Paste token manually →';
  String get loginToken            => _ru ? 'Токен входа'             : 'Login Token';
  String get pasteTokenHint        => _ru ? 'Вставьте токен или ссылку от бота...' : 'Paste token or link from bot...';
  String get verifyToken           => _ru ? 'Проверить токен'         : 'Verify Token';
  String get openBotAgain          => _ru ? 'Открыть бота снова →'    : 'Open bot again →';
  String get backToSignIn          => _ru ? 'Назад ко входу'          : 'Back to sign in';
  String get pleasePasteToken      => _ru ? 'Пожалуйста, вставьте токен от бота.' : 'Please paste the token from the bot.';
  String get connectionErrorRetry  => _ru ? 'Ошибка соединения. Попробуйте снова.' : 'Connection error. Please try again.';

  // ── Verify email ───────────────────────────────────────────────
  String get checkYourInbox        => _ru ? 'Проверьте почту'     : 'Check your inbox';
  String get verificationLinkSent  => _ru
      ? 'Мы отправили ссылку для подтверждения на\n'
      : 'We sent a verification link to\n';

  // ── Pricing payment buttons ────────────────────────────────────
  String get payCard    => _ru ? 'Оплатить картой'   : 'Pay by card';
  String get payStars   => _ru ? 'Telegram Stars'    : 'Telegram Stars';

  static AppStrings of(WidgetRef ref) => ref.watch(stringsProvider);
}

final stringsProvider = Provider<AppStrings>((ref) {
  final lang = ref.watch(settingsProvider.select((s) => s.language));
  return AppStrings._(lang);
});
