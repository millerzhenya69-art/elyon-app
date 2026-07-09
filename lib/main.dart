import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app_links/app_links.dart';
import 'package:url_launcher/url_launcher.dart';
import 'theme/app_theme.dart';
import 'models/app_settings.dart';
import 'providers/app_providers.dart';
import 'services/storage_service.dart';
import 'services/windows_services.dart';
import 'services/update_service.dart';
import 'screens/auth_screen.dart';
import 'screens/main_screen.dart';
import 'screens/splash_screen.dart';
import 'widgets/app_window_shell.dart';

// Conditional import: реальный window_manager на десктопе, stub на Android
import 'package:window_manager/window_manager.dart'
    if (dart.library.js_interop) 'stubs/window_manager_stub.dart'
    if (dart.library.js) 'stubs/window_manager_stub.dart';

export 'stubs/window_manager_stub.dart' show WindowListener;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isWindows) {
    await WindowsServices.init();
  }

  final storage = StorageService();
  await storage.init();

  final savedSettings = await storage.loadSettings();
  final savedUser     = await storage.loadUser();
  final savedSessions = await storage.loadSessions();

  runApp(ProviderScope(
    overrides: [storageServiceProvider.overrideWithValue(storage)],
    child: ElyonApp(
      initialSettings: savedSettings,
      initialUser:     savedUser,
      initialSessions: savedSessions,
    ),
  ));
}

class ElyonApp extends ConsumerStatefulWidget {
  const ElyonApp({super.key,
    required this.initialSettings,
    required this.initialUser,
    required this.initialSessions,
  });
  final AppSettings initialSettings;
  final dynamic initialUser;
  final dynamic initialSessions;

  @override
  ConsumerState<ElyonApp> createState() => _ElyonAppState();
}

class _ElyonAppState extends ConsumerState<ElyonApp> with WindowListener {
  final _navigatorKey = GlobalKey<NavigatorState>();
  bool _showSplash = true;
  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSub;

  @override
  void initState() {
    super.initState();
    if (Platform.isWindows) {
      windowManager.addListener(this);
      windowManager.setPreventClose(true);
    }
    if (Platform.isAndroid || Platform.isIOS) {
      _initDeepLinks();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(settingsProvider.notifier).load(widget.initialSettings);
      if (widget.initialUser != null) {
        ref.read(userProvider.notifier).setUser(widget.initialUser!);
        Future.microtask(() async {
          final authService = ref.read(authServiceProvider);
          final updated = await authService.syncUserFromServer(widget.initialUser!);
          if (updated != null && mounted) {
            ref.read(userProvider.notifier).setUser(updated);
          }
        });
      }
      if (widget.initialSessions != null) {
        ref.read(sessionsProvider.notifier).load(widget.initialSessions!);
      }
      _checkForUpdate();
    });
  }

  @override
  void dispose() {
    _linkSub?.cancel();
    if (Platform.isWindows) {
      windowManager.removeListener(this);
      WindowsServices().dispose();
    }
    super.dispose();
  }

  // ── Deep link: elyonai://auth?token=... (from Telegram /auth) ────
  Future<void> _initDeepLinks() async {
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) _handleIncomingLink(initialUri);
    } catch (_) {
      // no initial link — normal cold start
    }
    _linkSub = _appLinks.uriLinkStream.listen(
      _handleIncomingLink,
      onError: (_) {},
    );
  }

  void _handleIncomingLink(Uri uri) {
    if (uri.scheme != 'elyonai') return;
    final token = uri.queryParameters['token'];
    if (token == null || token.isEmpty) return;
    _completeTelegramLogin(token);
  }

  Future<void> _completeTelegramLogin(String token) async {
    try {
      final authService = ref.read(authServiceProvider);
      final user = await authService.signInWithTelegramToken(token);
      if (!mounted) return;
      ref.read(userProvider.notifier).setUser(user);
      _navigatorKey.currentState?.pushReplacementNamed('/app');
    } catch (_) {
      // Token invalid/expired/network error — user can still fall back to
      // pasting the token manually on the Telegram sign-in screen.
    }
  }

  @override
  Future<void> onWindowClose() async {
    if (Platform.isWindows) await WindowsServices().onWindowClose();
  }

  // ── Update check ───────────────────────────────────
  Future<void> _checkForUpdate() async {
    // Small delay so this never competes with the splash/auth flow for
    // attention — update prompt shows a couple seconds after landing.
    await Future.delayed(const Duration(seconds: 3));
    if (!mounted) return;
    final service = UpdateService();
    final info = await service.checkForUpdate();
    service.dispose();
    if (info == null || !mounted) return;

    final context = _navigatorKey.currentContext;
    if (context == null) return;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        title: const Text('Доступно обновление'),
        content: Text(
          'Вышла версия ${info.version}. Скачать и установить сейчас?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Позже'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              launchUrl(Uri.parse(info.downloadUrl),
                  mode: LaunchMode.externalApplication);
            },
            child: const Text('Скачать'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final fontSize  = ref.watch(settingsProvider).fontSize;
    final user      = ref.watch(userProvider);

    final theme = switch (themeMode) {
      AppThemeMode.dark   => AppTheme.dark(),
      AppThemeMode.amoled => AppTheme.amoled(),
      AppThemeMode.light  => AppTheme.light(),
    };

    return MaterialApp(
      title: 'Elyon AI',
      debugShowCheckedModeBanner: false,
      theme: theme,
      navigatorKey: _navigatorKey,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(fontSize.scale),
        ),
        child: AppWindowShell(child: child!),
      ),
      home: _showSplash
          ? SplashScreen(onFinished: () {
              final route = user != null ? '/app' : '/auth';
              _navigatorKey.currentState?.pushReplacementNamed(route);
              setState(() => _showSplash = false);
            })
          : (user != null ? const MainScreen() : const AuthScreen()),
      routes: {
        '/auth': (_) => const AuthScreen(),
        '/app':  (_) => const MainScreen(),
      },
    );
  }
}
