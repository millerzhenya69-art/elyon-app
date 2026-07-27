import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import '../models/user_model.dart';
import '../services/storage_service.dart';

const String _kBaseUrl = 'https://elyon-ai-web.vercel.app/api/relay';

// Desktop (Windows/Linux/macOS) OAuth client. Type in Google Cloud Console:
// "Web application" ("Elyon AI Web").
//
// IMPORTANT: these three values are read from --dart-define at BUILD TIME,
// never hardcoded in source. GitHub's push protection correctly blocked an
// earlier commit that had the client_secret (and client IDs) as literal
// strings here - client_secret is a real secret and must never sit in git
// history, and even client IDs trip GitHub's scanner pattern. See
// build_release.local.ps1 (gitignored, not committed) for the actual values
// and the exact build commands.
const String _kGoogleClientId = String.fromEnvironment(
  'GOOGLE_CLIENT_ID_WEB',
  defaultValue: '',
);

// Google requires a client_secret for the token exchange even with PKCE for
// "Web application"-type OAuth clients (a documented Google-specific
// deviation from the PKCE spec, not a general OAuth requirement) - the same
// trade-off every desktop app embedding a Google client makes (e.g. gcloud
// CLI). Generate one at: Google Cloud Console -> Credentials -> Elyon AI Web
// -> Client secrets -> Add secret.
const String _kGoogleClientSecret = String.fromEnvironment(
  'GOOGLE_CLIENT_SECRET_WEB',
  defaultValue: '',
);

// Мобильным не нужен отдельный Google-клиент вообще — Google там
// общается только с сайтом (auth.html), приложение лишь открывает страницу
// через flutter_web_auth_2 и получает готовый результат через
// elyonai://auth-callback (см. signInWithGoogle ниже).

const String _kGoogleCallbackScheme = 'elyonai';

// ── Error types ───────────────────────────────────────────────────

enum AuthErrorType {
  invalidCredentials, emailTaken, needsVerification,
  tokenExpired, networkError, serverError, cancelled,
}

class AuthException implements Exception {
  const AuthException(this.type, this.message);
  final AuthErrorType type;
  final String message;
  @override String toString() => 'AuthException(${type.name}): $message';
}

// ── Service ───────────────────────────────────────────────────────

class AuthService {
  AuthService({http.Client? client, required this.storage})
      : _client = client ?? http.Client();
  final http.Client _client;
  final StorageService storage;

  // ── Email ─────────────────────────────────────────────────────

  Future<AppUser> signInWithEmail({
    required String email,
    required String password,
    String firstName = '',
    String lastName  = '',
    bool signUp = false,
  }) async {
    http.Response res;
    try {
      res = await _client.post(
        Uri.parse('$_kBaseUrl/api/auth/email'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'action': signUp ? 'signup' : 'signin',
          'email': email, 'password': password,
          if (signUp) 'first_name': firstName,
          if (signUp) 'last_name': lastName,
        }),
      ).timeout(const Duration(seconds: 20));
    } catch (e) {
      // Include the raw exception (type + message) so future reports are
      // actionable instead of everything collapsing into one generic
      // "check your internet" message that hides the real cause (TLS
      // handshake failure on old Android versions, DNS issues, actual
      // timeouts, etc).
      throw AuthException(AuthErrorType.networkError,
          'Connection failed. Check your internet connection. (${e.runtimeType}: $e)');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode == 200 && data['ok'] == true) {
      if (data['verify'] == true) {
        throw const AuthException(AuthErrorType.needsVerification,
            'Please verify your email before signing in.');
      }
      // Pass firstName/lastName explicitly so sign-in preserves the name
      // the user registered with (backend may return empty first_name on
      // plain sign-in responses).
      final user = _parseUser(
        data['user'] as Map<String, dynamic>,
        fallbackFirstName: firstName,
        fallbackLastName:  lastName,
      );
      await storage.saveUser(user);
      return user;
    } else if (res.statusCode == 409) {
      throw const AuthException(AuthErrorType.emailTaken,
          'Email already registered. Sign in instead.');
    } else if (res.statusCode == 401) {
      throw const AuthException(AuthErrorType.invalidCredentials,
          'Invalid email or password.');
    } else {
      throw AuthException(AuthErrorType.serverError,
          data['error']?.toString() ?? 'Something went wrong.');
    }
  }

  // ── Telegram token ────────────────────────────────────────────
  //
  // На мобильных платформах идём через flutter_web_auth_2 (браузер/WebView),
  // а не прямым HTTP-запросом из Dart. На отдельных (обычно старых/бюджетных)
  // Android-устройствах прямой сокет из Dart почему-то не резолвит тот же самый
  // домен ("Failed host lookup") из-за каких-то device-specific сетевых
  // ограничений/багов — проверено с разными DNS, с VPN и без, не помогло.
  // Chrome Custom Tabs/WebView использует сетевой стек системного браузера, а не
  // Dart-сокеты приложения, что обходит эту проблему целиком.
  Future<AppUser> signInWithTelegramToken(String token) async {
    if (Platform.isAndroid || Platform.isIOS) {
      return _signInWithTelegramTokenViaBrowser(token);
    }
    return _signInWithTelegramTokenDirect(token);
  }

  Future<AppUser> _signInWithTelegramTokenViaBrowser(String token) async {
    final authUrl = Uri.https('elyon-ai-web.vercel.app', '/auth.html', {
      'tg_token': token,
      'native':   '1',
    });

    String result;
    try {
      result = await FlutterWebAuth2.authenticate(
        url: authUrl.toString(),
        callbackUrlScheme: _kGoogleCallbackScheme,
      );
    } on PlatformException catch (e) {
      if (e.code == 'CANCELED') {
        throw const AuthException(AuthErrorType.cancelled,
            'Telegram sign-in was cancelled.');
      }
      throw AuthException(AuthErrorType.networkError,
          'Telegram sign-in failed: ${e.message ?? e.code}');
    }

    final params = Uri.parse(result).queryParameters;
    final error  = params['error'];
    if (error != null && error.isNotEmpty) {
      throw AuthException(AuthErrorType.tokenExpired, error);
    }
    final userId = params['user_id'];
    if (userId == null || userId.isEmpty) {
      throw const AuthException(AuthErrorType.serverError,
          'No user data returned by Telegram sign-in.');
    }

    final user = _parseUser({
      'user_id':    userId,
      'email':      params['email']      ?? '',
      'first_name': params['first_name'] ?? '',
      'last_name':  params['last_name']  ?? '',
      'avatar':     params['avatar']     ?? '',
      'provider':   params['provider']   ?? 'telegram',
      'username':   params['username']   ?? '',
      'sub_type':   params['sub_type']   ?? 'none',
    });
    await storage.saveUser(user);
    return user;
  }

  Future<AppUser> _signInWithTelegramTokenDirect(String token) async {
    http.Response res;
    try {
      res = await _client.post(
        Uri.parse('$_kBaseUrl/api/auth/telegram_token'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'token': token}),
      ).timeout(const Duration(seconds: 20));
    } catch (e) {
      throw AuthException(AuthErrorType.networkError,
          'Connection failed. Check your internet. (${e.runtimeType}: $e)');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode == 200 && data['ok'] == true) {
      final user = _parseUser(data['user'] as Map<String, dynamic>);
      await storage.saveUser(user);
      return user;
    } else if (res.statusCode == 401) {
      throw AuthException(AuthErrorType.tokenExpired,
          data['error']?.toString() ??
              'Token expired or already used. Send /auth again.');
    } else {
      throw AuthException(AuthErrorType.serverError,
          data['error']?.toString() ?? 'Telegram sign-in failed.');
    }
  }

  // ── Google OAuth ─────────────────────────────────────────────
  //
  // Mobile: точно так же, как Telegram выше — через flutter_web_auth_2
  // открываем auth.html в системном браузере/WebView, а сама страница
  // делает весь Google OAuth целиком в своём контексте (стандартный,
  // самый обычный случай для Google — обычный https-redirect_uri на
  // Web-клиента, без custom URI scheme, без типа клиента "Android", без
  // PKCE в приложении), а приложение получает только готовый результат
  // через elyonai://auth-callback.
  //
  // Причина перехода на это: implicit-флоу и затем PKCE через отдельный
  // Android-клиент стабильно падали с "doesn't comply with Google's OAuth 2.0
  // policy for keeping apps secure" ещё ДО того, как доходило до нашего колбэка
  // (ошибка показывалась на экране accounts.google.com до любого редиректа) —
  // то есть это было ограничение со стороны самого Google именно для
  // native/mobile OAuth-клиентов, а не баг в нашем коде перехвата колбэка
  // (тот баг отдельно нашли и починили — недостающий CallbackActivity для
  // flutter_web_auth_2 в AndroidManifest.xml, что подтвердилось тем, что
  // Telegram через тот же механизм заработал после фикса, а Google — нет,
  // потому что проблема вообще до редиректа, на стороне самого Google).
  //
  // Desktop оставлен как есть (PKCE через локальный loopback-сервер) —
  // там проблема была в database.cursor на бэкенде (уже починена), а не в
  // самом OAuth-флоу.

  Future<AppUser> signInWithGoogle() async {
    if (Platform.isAndroid || Platform.isIOS) {
      return _signInWithGoogleMobileViaBrowser();
    }
    return _signInWithGoogleDesktop();
  }

  Future<AppUser> _signInWithGoogleMobileViaBrowser() async {
    final authUrl = Uri.https('elyon-ai-web.vercel.app', '/auth.html', {
      'native':   '1',
      'provider': 'google',
    });

    String result;
    try {
      result = await FlutterWebAuth2.authenticate(
        url: authUrl.toString(),
        callbackUrlScheme: _kGoogleCallbackScheme,
      );
    } on PlatformException catch (e) {
      if (e.code == 'CANCELED') {
        throw const AuthException(AuthErrorType.cancelled,
            'Google sign-in was cancelled.');
      }
      throw AuthException(AuthErrorType.networkError,
          'Google sign-in failed: ${e.message ?? e.code}');
    }

    final params = Uri.parse(result).queryParameters;
    final error  = params['error'];
    if (error != null && error.isNotEmpty) {
      throw AuthException(AuthErrorType.serverError, error);
    }
    final userId = params['user_id'];
    if (userId == null || userId.isEmpty) {
      throw const AuthException(AuthErrorType.serverError,
          'No user data returned by Google sign-in.');
    }

    final user = _parseUser({
      'user_id':    userId,
      'email':      params['email']      ?? '',
      'first_name': params['first_name'] ?? '',
      'last_name':  params['last_name']  ?? '',
      'avatar':     params['avatar']     ?? '',
      'provider':   params['provider']   ?? 'google',
      'username':   params['username']   ?? '',
      'sub_type':   params['sub_type']   ?? 'none',
    });
    await storage.saveUser(user);
    return user;
  }

  // ── Desktop: Authorization Code + PKCE ──────────────────────────

  String _generateCodeVerifier() {
    final random = Random.secure();
    final bytes = List<int>.generate(64, (_) => random.nextInt(256));
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  String _codeChallengeFromVerifier(String verifier) {
    final digest = sha256.convert(utf8.encode(verifier));
    return base64Url.encode(digest.bytes).replaceAll('=', '');
  }

  Future<String> _exchangeCodeForToken({
    required String code,
    required String codeVerifier,
    required String clientId,
    required String redirectUri,
    String? clientSecret,
  }) async {
    http.Response res;
    try {
      res = await _client.post(
        Uri.parse('https://oauth2.googleapis.com/token'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'client_id':     clientId,
          'code':          code,
          'code_verifier': codeVerifier,
          'grant_type':    'authorization_code',
          'redirect_uri':  redirectUri,
          if (clientSecret != null && clientSecret.isNotEmpty)
            'client_secret': clientSecret,
        },
      ).timeout(const Duration(seconds: 15));
    } catch (e) {
      throw AuthException(AuthErrorType.networkError,
          'Could not reach Google to finish sign-in. (${e.runtimeType}: $e)');
    }
    if (res.statusCode != 200) {
      throw AuthException(AuthErrorType.serverError,
          'Google token exchange failed (${res.statusCode}): ${res.body}');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final accessToken = data['access_token'] as String?;
    if (accessToken == null) {
      throw const AuthException(AuthErrorType.serverError,
          'No access token in Google response.');
    }
    return accessToken;
  }

  HttpServer? _googleServer;
  Completer<String>? _googleCompleter;

  void cancelGoogleSignIn() {
    _googleCompleter?.completeError(
      const AuthException(AuthErrorType.cancelled, 'Google sign-in was cancelled.'),
    );
    _googleServer?.close(force: true);
    _googleServer = null;
    _googleCompleter = null;
  }

  // Desktop: local loopback redirect server. With the Authorization Code
  // flow, Google appends "?code=..." as a real query parameter (not a URL
  // fragment like the old implicit flow did) - the server can read it
  // directly from the request, no client-side JS hash-extraction needed.
  Future<AppUser> _signInWithGoogleDesktop() async {
    cancelGoogleSignIn();

    final codeVerifier  = _generateCodeVerifier();
    final codeChallenge = _codeChallengeFromVerifier(codeVerifier);

    final completer = Completer<String>();
    _googleCompleter = completer;

    HttpServer? server;
    try {
      try {
        server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      } on SocketException {
        try {
          server = await HttpServer.bind(InternetAddress.anyIPv4, 0);
        } on SocketException catch (e) {
          throw AuthException(AuthErrorType.networkError,
              'Could not start local sign-in server: ${e.message}');
        }
      }
      _googleServer = server;

      final callbackPort = server.port;
      server.listen((req) async {
        final code  = req.requestedUri.queryParameters['code'];
        final error = req.requestedUri.queryParameters['error'];
        req.response
          ..statusCode = 200
          ..headers.contentType = ContentType.html
          ..write('''<!DOCTYPE html><html><head><style>
            body{background:#0e0e0e;color:#f8f5f0;font-family:sans-serif;
                 display:flex;align-items:center;justify-content:center;
                 height:100vh;margin:0;text-align:center;}
            h2{color:#e8ddd0;font-size:22px;margin-bottom:8px;}
            p{color:rgba(248,245,240,0.5);font-size:14px;}
          </style></head><body>
          <div>
            <h2>${error == null ? '✓ Signed in to Elyon AI' : '✗ Sign-in failed'}</h2>
            <p>You can close this tab and return to the app.</p>
          </div>
          <script>setTimeout(()=>window.close(),1200);</script>
          </body></html>''')
          ..close();
        if (code != null && !completer.isCompleted) {
          completer.complete(code);
        } else if (error != null && !completer.isCompleted) {
          completer.completeError(
            AuthException(AuthErrorType.serverError, 'Google sign-in error: $error'));
        }
      });

      final redirectUri = 'http://localhost:$callbackPort';
      final authUrl = Uri.https('accounts.google.com', '/o/oauth2/v2/auth', {
        'client_id':             _kGoogleClientId,
        'redirect_uri':          redirectUri,
        'response_type':         'code',
        'code_challenge':        codeChallenge,
        'code_challenge_method': 'S256',
        'scope':                 'email profile openid',
        'prompt':                'select_account',
      });
      if (!await launchUrl(authUrl, mode: LaunchMode.externalApplication)) {
        throw const AuthException(AuthErrorType.networkError,
            'Could not open browser for Google sign-in.');
      }

      final code = await completer.future
          .timeout(const Duration(minutes: 5), onTimeout: () {
        throw const AuthException(AuthErrorType.cancelled,
            'Google sign-in timed out. Please try again.');
      });

      final accessToken = await _exchangeCodeForToken(
        code: code,
        codeVerifier: codeVerifier,
        clientId: _kGoogleClientId,
        redirectUri: redirectUri,
        clientSecret: _kGoogleClientSecret,
      );
      return await _verifyGoogleToken(accessToken);
    } finally {
      await server?.close(force: true);
      if (_googleCompleter == completer) {
        _googleServer = null;
        _googleCompleter = null;
      }
    }
  }

  Future<AppUser> _verifyGoogleToken(String accessToken) async {
    final profileRes = await _client.get(
      Uri.parse('https://www.googleapis.com/oauth2/v3/userinfo'),
      headers: {'Authorization': 'Bearer $accessToken'},
    ).timeout(const Duration(seconds: 15));

    if (profileRes.statusCode != 200) {
      throw const AuthException(AuthErrorType.serverError,
          'Failed to get Google profile.');
    }

    final profile = jsonDecode(profileRes.body) as Map<String, dynamic>;

    final res = await _client.post(
      Uri.parse('$_kBaseUrl/api/auth/google_profile'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'profile': profile}),
    ).timeout(const Duration(seconds: 15));

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode == 200 && data['ok'] == true) {
      final user = _parseUser(data['user'] as Map<String, dynamic>);
      await storage.saveUser(user);
      return user;
    } else {
      throw AuthException(AuthErrorType.serverError,
          data['error']?.toString() ?? 'Google sign-in failed.');
    }
  }

  // ── Restore / sign out ────────────────────────────────────────

  Future<AppUser?> restoreSession() async => storage.loadUser();
  Future<void> signOut() async => storage.clearUser();

  // ── Parse user from backend JSON ─────────────────────────────

  static const _ownerEmails    = ['zhenyamiller8@gmail.com', 'elyonaiteam@gmail.com'];
  static const _ownerUsernames = ['unkony'];

  AppUser _parseUser(
    Map<String, dynamic> json, {
    String fallbackFirstName = '',
    String fallbackLastName  = '',
  }) {
    final userId   = json['user_id']?.toString() ?? '';
    final email    = json['email']?.toString() ?? '';
    final provider = json['provider']?.toString() ?? 'email';
    final username = json['username']?.toString() ?? '';
    final subType  = json['sub_type']?.toString() ?? 'none';

    // ── Display name resolution ────────────────────────────────
    // Priority:
    //   1. first_name + last_name from backend response
    //   2. fallback names passed by the caller (from the sign-up form)
    //   3. username (Telegram handle)
    //   4. email local part (last resort — avoids "email shown as name" bug)
    final fname = (json['first_name']?.toString() ?? '').trim();
    final lname = (json['last_name']?.toString() ?? '').trim();

    final resolvedFirst = fname.isNotEmpty ? fname : fallbackFirstName.trim();
    final resolvedLast  = lname.isNotEmpty ? lname : fallbackLastName.trim();

    String displayName = [resolvedFirst, resolvedLast]
        .where((s) => s.isNotEmpty)
        .join(' ');

    if (displayName.isEmpty && username.isNotEmpty) {
      displayName = username;
    }
    if (displayName.isEmpty) {
      // Use the part before @ but only if it looks like a name, not a UUID
      final localPart = email.split('@').first;
      displayName = localPart;
    }

    final avatar  = json['avatar']?.toString();
    final isOwner = _ownerEmails.contains(email) ||
        _ownerUsernames.contains(username.toLowerCase());

    return AppUser(
      id:                userId,
      email:             email,
      displayName:       displayName,
      avatarUrl:         (avatar?.isNotEmpty ?? false) ? avatar : null,
      tier:              _parseTier(subType),
      messagesUsedToday: 0,
      isOwner:           isOwner,
      authProvider:      provider,
      joinedAt:          DateTime.now(),
    );
  }

  /// Re-fetches subscription status from server and merges into stored user.
  Future<AppUser?> syncUserFromServer(AppUser current) async {
    try {
      final uid = int.tryParse(current.id) ?? current.id;
      final res = await _client
          .get(Uri.parse('$_kBaseUrl/api/user/$uid'))
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final data    = jsonDecode(res.body) as Map<String, dynamic>;
        final subType = data['sub_type']?.toString() ?? 'none';
        final tier    = _parseTier(subType);

        // Also update displayName if backend now has first_name
        final fname   = data['first_name']?.toString() ?? '';
        final lname   = data['last_name']?.toString()  ?? '';
        final fullName = [fname, lname].where((s) => s.isNotEmpty).join(' ');
        final updatedName = fullName.isNotEmpty ? fullName : current.displayName;

        final updated = current.copyWith(tier: tier, displayName: updatedName);
        await storage.saveUser(updated);
        return updated;
      }
    } catch (_) {
      // Silently fail — keep cached user
    }
    return null;
  }

  SubscriptionTier _parseTier(String s) {
    switch (s) {
      case 'nova':
      case 'month':
      case 'halfyear': return SubscriptionTier.nova;
      case 'pro':      return SubscriptionTier.pro;
      case 'absolution':
      case 'forever':  return SubscriptionTier.absolution;
      default:         return SubscriptionTier.core;
    }
  }
}
