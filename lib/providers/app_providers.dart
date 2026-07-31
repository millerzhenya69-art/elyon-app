import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/app_settings.dart';
import '../models/chat_message.dart';
import '../models/user_model.dart';
import '../services/storage_service.dart';
import '../services/ai_service.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';

// ── Singletons ──────────────────────────────────────────────────

final storageServiceProvider = Provider<StorageService>((ref) {
  throw UnimplementedError('Initialize StorageService before runApp');
});

final aiServiceProvider = Provider<AiService>((ref) {
  final service = AiService();
  ref.onDispose(service.dispose);
  return service;
});

/// AuthService — needs StorageService injected.
final authServiceProvider = Provider<AuthService>((ref) {
  final storage = ref.read(storageServiceProvider);
  return AuthService(storage: storage);
});

// ── Settings ────────────────────────────────────────────────────

class SettingsNotifier extends Notifier<AppSettings> {
  @override
  AppSettings build() => const AppSettings();

  void setTheme(AppThemeMode mode)    { state = state.copyWith(themeMode: mode);     _save(); }
  void setLanguage(AppLanguage lang)  { state = state.copyWith(language: lang);      _save(); }
  void setFontSize(FontSizeOption sz) { state = state.copyWith(fontSize: sz);        _save(); }
  void toggleStreaming()              { state = state.copyWith(streamingEnabled: !state.streamingEnabled); _save(); }
  void load(AppSettings s)            => state = s;

  void _save() => ref.read(storageServiceProvider).saveSettings(state);
}

final settingsProvider = NotifierProvider<SettingsNotifier, AppSettings>(
  SettingsNotifier.new,
);

final themeModeProvider = Provider<AppThemeMode>(
  (ref) => ref.watch(settingsProvider).themeMode,
);

// ── Current user ────────────────────────────────────────────────

class UserNotifier extends Notifier<AppUser?> {
  @override
  AppUser? build() => null;

  void setUser(AppUser user) {
    state = user;
    ref.read(storageServiceProvider).saveUser(user);
  }

  void incrementMessageCount() {
    if (state == null) return;
    state = state!.copyWith(messagesUsedToday: state!.messagesUsedToday + 1);
    ref.read(storageServiceProvider).saveUser(state!);
  }

  Future<void> signOut() async {
    await ref.read(storageServiceProvider).clearUser();
    state = null;
  }
}

final userProvider = NotifierProvider<UserNotifier, AppUser?>(
  UserNotifier.new,
);

final isOwnerProvider = Provider<bool>(
  (ref) => ref.watch(userProvider)?.isOwner ?? false,
);

// ── Chat sessions ────────────────────────────────────────────────

class SessionsNotifier extends Notifier<List<ChatSession>> {
  @override
  List<ChatSession> build() => [];

  void load(List<ChatSession> sessions) => state = sessions;

  ChatSession createSession() {
    final session = ChatSession(title: '');
    state = [session, ...state];
    _save();
    return session;
  }

  void updateSession(ChatSession updated) {
    state = state
        .map((s) => s.id == updated.id ? updated : s)
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    _save();
  }

  void deleteSession(String id) {
    state = state.where((s) => s.id != id).toList();
    ref.read(storageServiceProvider).deleteSession(id);
  }

  void _save() => ref.read(storageServiceProvider).saveSessions(state);
}

final sessionsProvider = NotifierProvider<SessionsNotifier, List<ChatSession>>(
  SessionsNotifier.new,
);

// ── Active chat ──────────────────────────────────────────────────

class ActiveChatNotifier extends Notifier<ChatSession?> {
  @override
  ChatSession? build() => null;

  void setSession(ChatSession session) => state = session;
  void clear() => state = null;

  Future<void> sendMessage(String text) async {
    final ai       = ref.read(aiServiceProvider);
    final user     = ref.read(userProvider);
    final settings = ref.read(settingsProvider);

    if (user == null || !user.canSendMessage) return;

    if (state == null) {
      final session = ref.read(sessionsProvider.notifier).createSession();
      state = session;
    }

    final userMsg = ChatMessage(role: MessageRole.user, content: text);
    _addMessage(userMsg);

    final thinkingMsg = ChatMessage(
      role: MessageRole.assistant, content: '', isStreaming: true,
    );
    _addMessage(thinkingMsg);

    ref.read(userProvider.notifier).incrementMessageCount();

    try {
      final userId = user.id;

      if (settings.streamingEnabled) {
        final historyForApi = state!.messages
            .where((m) => !m.isStreaming)
            .toList();
        String accumulated = '';
        await for (final chunk in ai.streamMessage(
          history: historyForApi,
          tier:    user.tier,
          userId:  userId,
        )) {
          accumulated += chunk;
          _replaceStreaming(thinkingMsg.id, accumulated, stillStreaming: true);
        }
        _replaceStreaming(thinkingMsg.id, accumulated, stillStreaming: false);
      } else {
        final reply = await ai.sendMessage(
          history: state!.messages.where((m) => !m.isStreaming).toList(),
          tier:    user.tier,
          userId:  userId,
        );
        _replaceStreaming(thinkingMsg.id, reply, stillStreaming: false);
      }
    } on AiException catch (e) {
      _replaceStreaming(
        thinkingMsg.id,
        e.type == AiErrorType.rateLimited
            ? '⚠ Daily message limit reached. Upgrade your plan to continue.'
            : '⚠ ${e.message}',
        stillStreaming: false,
      );
    } catch (e, st) {
      debugPrint('[ElyonNet] sendMessage failed: ${e.runtimeType}: $e\n$st');
      _replaceStreaming(
        thinkingMsg.id,
        '⚠ Connection error. Please try again.',
        stillStreaming: false,
      );
    }
  }

  /// Sends a message with an attached file (image/document/etc).
  /// Mirrors the web app's sendMessage() with pendingFile flow.
  Future<void> sendMessageWithFile({
    required String text,
    required String fileName,
    required String mimeType,
    required String base64Data,
    required int fileSizeBytes,
  }) async {
    final ai   = ref.read(aiServiceProvider);
    final user = ref.read(userProvider);

    if (user == null || !user.canSendMessage) return;

    if (state == null) {
      final session = ref.read(sessionsProvider.notifier).createSession();
      state = session;
    }

    final displayText = text.trim().isNotEmpty ? text.trim() : 'Analyze this file: $fileName';
    final userMsg = ChatMessage(
      role: MessageRole.user,
      content: displayText,
      fileInfo: MessageFileInfo(name: fileName, mimeType: mimeType, sizeBytes: fileSizeBytes),
    );
    _addMessage(userMsg);

    final thinkingMsg = ChatMessage(
      role: MessageRole.assistant, content: '', isStreaming: true,
    );
    _addMessage(thinkingMsg);

    ref.read(userProvider.notifier).incrementMessageCount();

    try {
      final reply = await ai.sendFileMessage(
        history:    state!.messages.where((m) => !m.isStreaming).toList(),
        tier:       user.tier,
        userId:     user.id,
        fileName:   fileName,
        mimeType:   mimeType,
        base64Data: base64Data,
        prompt:     text.trim().isNotEmpty ? text.trim() : ' ',
      );
      _replaceStreaming(thinkingMsg.id, reply, stillStreaming: false);
    } on AiException catch (e) {
      _replaceStreaming(
        thinkingMsg.id,
        e.type == AiErrorType.rateLimited
            ? '⚠ Daily message limit reached. Upgrade your plan to continue.'
            : '⚠ ${e.message}',
        stillStreaming: false,
      );
    } catch (e, st) {
      debugPrint('[ElyonNet] sendMessageWithFile failed: ${e.runtimeType}: $e\n$st');
      _replaceStreaming(
        thinkingMsg.id,
        '⚠ Connection error while analyzing the file. Please try again.',
        stillStreaming: false,
      );
    }
  }

  void _addMessage(ChatMessage msg) {
    if (state == null) return;
    final updated = state!.copyWith(messages: [...state!.messages, msg]);
    state = updated;
    ref.read(sessionsProvider.notifier).updateSession(updated);
  }

  void _replaceStreaming(String id, String content,
      {required bool stillStreaming}) {
    if (state == null) return;
    final msgs = state!.messages.map((m) {
      if (m.id != id) return m;
      return m.copyWith(content: content, isStreaming: stillStreaming);
    }).toList();
    final updated = state!.copyWith(messages: msgs);
    state = updated;
    ref.read(sessionsProvider.notifier).updateSession(updated);
  }
}

final activeChatProvider =
    NotifierProvider<ActiveChatNotifier, ChatSession?>(
  ActiveChatNotifier.new,
);
