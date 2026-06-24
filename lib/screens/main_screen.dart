import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import '../models/chat_message.dart';
import '../models/user_model.dart';
import '../providers/app_providers.dart';
import '../services/windows_services.dart';
import '../widgets/welcome_screen.dart';
import '../widgets/messages_list.dart';
import '../widgets/chat_input_box.dart';
import '../widgets/sidebar_drawer.dart';
import '../widgets/top_nav_bar.dart';
import 'settings_screen.dart';
import 'profile_screen.dart';
import 'admin_panel_screen.dart';

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});
  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

enum _MainView { chat, settings, profile, pricing, admin }

class _MainScreenState extends ConsumerState<MainScreen> {
  bool      _sidebarOpen = false;
  _MainView _view        = _MainView.chat;

  @override
  void initState() {
    super.initState();
    if (Platform.isWindows) {
      WindowsServices().setCallbacks(
        onNewChat:  _newChat,
        onFocus:    () => setState(() => _sidebarOpen = false),
        onCopyLast: _copyLastAiMessage,
        onSettings: () => _goTo(_MainView.settings),
      );
      // Синхронизируем заголовок/тултип трея с текущей моделью при старте
      final initialUser = ref.read(userProvider);
      if (initialUser != null) {
        WindowsServices().updateModelLabel('Elyon ${initialUser.tier.displayName}');
      }
    }
  }

  void _newChat() {
    ref.read(activeChatProvider.notifier).clear();
    setState(() { _sidebarOpen = false; _view = _MainView.chat; });
  }

  /// Win+Shift+C — копирует последний ответ AI в буфер обмена
  void _copyLastAiMessage() {
    final chat = ref.read(activeChatProvider);
    if (chat == null || chat.messages.isEmpty) return;
    final lastAi = chat.messages.lastWhere(
      (m) => m.isAssistant,
      orElse: () => chat.messages.last,
    );
    Clipboard.setData(ClipboardData(text: lastAi.content));
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;
    setState(() => _view = _MainView.chat);
    await ref.read(activeChatProvider.notifier).sendMessage(text);
  }

  void _goTo(_MainView v) => setState(() { _view = v; _sidebarOpen = false; });

  void _signOut() {
    ref.read(userProvider.notifier).signOut();
    Navigator.of(context).pushReplacementNamed('/auth');
  }

  @override
  Widget build(BuildContext context) {
    final elyon      = context.elyon;
    final activeChat = ref.watch(activeChatProvider);

    // Держим трей (заголовок + tooltip) в курсе текущего тарифа.
    final user = ref.watch(userProvider);
    ref.listen(userProvider, (prev, next) {
      if (Platform.isWindows && next != null && prev?.tier != next.tier) {
        WindowsServices().updateModelLabel('Elyon ${next.tier.displayName}');
      }
    });

    return Scaffold(
      backgroundColor: elyon.scaffoldBg,
      body: Stack(
        children: [
          // ── Main column ─────────────────────────────────────
          Column(children: [
            TopNavBar(
              sidebarOpen:   _sidebarOpen,
              onMenuTap:     () => setState(() => _sidebarOpen = !_sidebarOpen),
              onNewChat:     _newChat,
              onProfileTap:  () => _goTo(_view == _MainView.profile
                                    ? _MainView.chat : _MainView.profile),
              onSettingsTap: () => _goTo(_view == _MainView.settings
                                    ? _MainView.chat : _MainView.settings),
              user: user,
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (child, anim) =>
                    FadeTransition(opacity: anim, child: child),
                child: switch (_view) {
                  _MainView.chat => _ChatView(
                      key:        const ValueKey('chat'),
                      activeChat: activeChat,
                      onSend:     _sendMessage,
                      onChipTap:  _sendMessage,
                    ),
                  _MainView.settings => SettingsPanel(
                      key:    const ValueKey('settings'),
                      onBack: () => _goTo(_MainView.chat),
                    ),
                  _MainView.profile => ProfilePanel(
                      key:       const ValueKey('profile'),
                      onBack:    () => _goTo(_MainView.chat),
                      onSignOut: _signOut,
                      onUpgrade: () => _goTo(_MainView.pricing),
                    ),
                  _MainView.pricing => PricingPanel(
                      key:    const ValueKey('pricing'),
                      onBack: () => _goTo(_MainView.chat),
                    ),
                  _MainView.admin => AdminPanelScreen(
                      key:    const ValueKey('admin'),
                      onBack: () => _goTo(_MainView.chat),
                    ),
                },
              ),
            ),
          ]),

          // ── Sidebar overlay ─────────────────────────────────
          SidebarDrawer(
            isOpen:         _sidebarOpen,
            onClose:        () => setState(() => _sidebarOpen = false),
            onOpenSettings: () => _goTo(_MainView.settings),
            onOpenPricing:  () => _goTo(_MainView.pricing),
            onOpenProfile:  () => _goTo(_MainView.profile),
            onOpenAdmin:    () => _goTo(_MainView.admin),
          ),
        ],
      ),
    );
  }
}

// ── Chat view ──────────────────────────────────────────────────────

class _ChatView extends ConsumerWidget {
  const _ChatView({
    super.key,
    required this.activeChat,
    required this.onSend,
    required this.onChipTap,
  });
  final ChatSession? activeChat;
  final void Function(String) onSend;
  final void Function(String) onChipTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final elyon       = context.elyon;
    final hasMessages = activeChat != null && activeChat!.messages.isNotEmpty;

    if (!hasMessages) {
      return WelcomeScreen(onSend: onSend, onChipTap: onChipTap);
    }

    return Container(
      color: elyon.scaffoldBg,
      child: Column(children: [
        Expanded(child: MessagesList(messages: activeChat!.messages)),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: ChatInputBox(onSend: onSend),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Elyon can make mistakes. Consider checking important information.',
          style: TextStyle(fontFamily: 'DMSans', fontSize: 11,
              color: elyon.mutedText.withOpacity(0.5)),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
      ]),
    );
  }
}
