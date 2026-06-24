import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/chat_message.dart';
import '../models/app_settings.dart';
import '../models/user_model.dart';

class StorageService {
  static const _kSessions  = 'elyon_sessions';
  static const _kSettings  = 'elyon_settings';
  static const _kUser      = 'elyon_user';
  static const _kToken     = 'elyon_token';

  late SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // ── Chat sessions ──────────────────────────────────────────────

  Future<List<ChatSession>> loadSessions() async {
    final raw = _prefs.getString(_kSessions);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .map((e) => ChatSession.fromJson(e as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    } catch (_) {
      return [];
    }
  }

  Future<void> saveSessions(List<ChatSession> sessions) async {
    final data = sessions.map((s) => s.toJson()).toList();
    await _prefs.setString(_kSessions, jsonEncode(data));
  }

  Future<void> deleteSession(String id) async {
    final sessions = await loadSessions();
    sessions.removeWhere((s) => s.id == id);
    await saveSessions(sessions);
  }

  Future<void> clearAllSessions() async {
    await _prefs.remove(_kSessions);
  }

  // ── Settings ───────────────────────────────────────────────────

  Future<AppSettings> loadSettings() async {
    final raw = _prefs.getString(_kSettings);
    if (raw == null) return const AppSettings();
    try {
      return AppSettings.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      return const AppSettings();
    }
  }

  Future<void> saveSettings(AppSettings settings) async {
    await _prefs.setString(_kSettings, jsonEncode(settings.toJson()));
  }

  // ── User ───────────────────────────────────────────────────────

  Future<AppUser?> loadUser() async {
    final raw = _prefs.getString(_kUser);
    if (raw == null) return null;
    try {
      return AppUser.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveUser(AppUser user) async {
    await _prefs.setString(_kUser, jsonEncode(user.toJson()));
  }

  Future<void> clearUser() async {
    await _prefs.remove(_kUser);
    await _prefs.remove(_kToken);
  }

  // ── Auth token ─────────────────────────────────────────────────

  Future<String?> loadToken() async => _prefs.getString(_kToken);

  Future<void> saveToken(String token) async =>
      _prefs.setString(_kToken, token);
}
