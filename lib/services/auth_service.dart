import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../models/user_model.dart';
import '../services/storage_service.dart';

const String _kBaseUrl = 'https://elyon-ai-web.vercel.app/api/relay';
const String _kGoogleClientId =
    '468899724697-mct44qubsrdaps8ll6m4npv34k6jeucn.apps.googleusercontent.com';
// Port 0 = let the OS pick any free ephemeral port. Google explicitly allows
// any port number for http://localhost / 127.0.0.1 redirect URIs on Desktop-
// type OAuth clients — no need to pre-register a fixed port. A hardcoded
// port (previously 8765) could permanently fail with SocketException if
// anything else on the device already holds it.

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
    } catch (_) {
      throw const AuthException(AuthErrorType.networkError,
          'Connection failed. Check your internet connection.');
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

  Future<AppUser> signInWithTelegramToken(String token) async {
    http.Response res;
    try {
      res = await _client.post(
        Uri.parse('$_kBaseUrl/api/auth/telegram_token'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'token': token}),
      ).timeout(const Duration(seconds: 20));
    } catch (_) {
      throw const AuthException(AuthErrorType.networkError,
          'Connection failed. Check your internet.');
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

  // ── Google OAuth via local redirect server ────────────────────

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

  Future<AppUser> signInWithGoogle() async {
    cancelGoogleSignIn();

    final completer = Completer<String>();
    _googleCompleter = completer;

    HttpServer? server;
    try {
      try {
        server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      } on SocketException {
        // Some Android OS/device combinations reject binding specifically to
        // the loopback address (127.0.0.1) under certain network security
        // policies, even though binding to all interfaces works fine. The
        // OAuth redirect still targets "localhost", which routes to whatever
        // the server is listening on, loopback or not.
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
        final token = req.requestedUri.queryParameters['access_token'];
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
            <h2>✓ Signed in to Elyon AI</h2>
            <p>You can close this tab and return to the app.</p>
          </div>
          <script>
            const hash = window.location.hash;
            if(hash.includes("access_token")){
              const p = new URLSearchParams(hash.replace("#",""));
              const t = p.get("access_token");
              if(t) fetch("/callback?access_token="+encodeURIComponent(t))
                .then(()=>setTimeout(()=>window.close(),1000));
            } else {
              setTimeout(()=>window.close(),1500);
            }
          </script></body></html>''')
          ..close();
        if (token != null && !completer.isCompleted) {
          completer.complete(token);
        }
      });

      final redirectUri = 'http://localhost:$callbackPort/callback';
      final authUrl = Uri.https('accounts.google.com', '/o/oauth2/v2/auth', {
        'client_id':     _kGoogleClientId,
        'redirect_uri':  redirectUri,
        'response_type': 'token',
        'scope':         'email profile openid',
        'prompt':        'select_account',
      });
      if (!await launchUrl(authUrl, mode: LaunchMode.externalApplication)) {
        throw const AuthException(AuthErrorType.networkError,
            'Could not open browser for Google sign-in.');
      }

      final token = await completer.future
          .timeout(const Duration(minutes: 5), onTimeout: () {
        throw const AuthException(AuthErrorType.cancelled,
            'Google sign-in timed out. Please try again.');
      });

      return await _verifyGoogleToken(token);
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
