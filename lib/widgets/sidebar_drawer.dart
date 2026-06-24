import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../providers/app_providers.dart';
import '../providers/app_strings.dart';
import '../models/chat_message.dart';

/// Top-drawer sidebar — slides down from the nav bar.
/// Mirrors the web .sidebar component with the chat grid + nav links.
class SidebarDrawer extends ConsumerWidget {
  const SidebarDrawer({
    super.key,
    required this.isOpen,
    required this.onClose,
    required this.onOpenSettings,
    required this.onOpenPricing,
    required this.onOpenProfile,
    required this.onOpenAdmin,
  });

  final bool isOpen;
  final VoidCallback onClose;
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenPricing;
  final VoidCallback onOpenProfile;
  final VoidCallback onOpenAdmin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final elyon    = context.elyon;
    final t        = AppStrings.of(ref);
    final isOwner  = ref.watch(isOwnerProvider);
    final sessions = ref.watch(sessionsProvider);
    final active   = ref.watch(activeChatProvider);

    return Stack(
      children: [
        // Backdrop
        AnimatedOpacity(
          duration: const Duration(milliseconds: 260),
          opacity: isOpen ? 1.0 : 0.0,
          child: IgnorePointer(
            ignoring: !isOpen,
            child: GestureDetector(
              onTap: onClose,
              child: Container(
                color: const Color(0x73000000),
              ),
            ),
          ),
        ),

        // Panel
        AnimatedSlide(
          offset: isOpen ? Offset.zero : const Offset(0, -1),
          duration: const Duration(milliseconds: 280),
          curve: const Cubic(0.4, 0, 0.2, 1),
          child: Align(
            alignment: Alignment.topCenter,
            child: Material(
              color: elyon.scaffoldBg.withOpacity(0.97),
              child: Container(
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: elyon.border2Color),
                  ),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 900),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── Chat history ───────────────────────
                          Expanded(
                            child: _ChatHistorySection(
                              t:         t,
                              sessions:  sessions,
                              activeId:  active?.id,
                              onSelect:  (s) {
                                ref
                                    .read(activeChatProvider.notifier)
                                    .setSession(s);
                                onClose();
                              },
                              onDelete:  (id) {
                                ref
                                    .read(sessionsProvider.notifier)
                                    .deleteSession(id);
                              },
                              onNewChat: () {
                                ref
                                    .read(activeChatProvider.notifier)
                                    .clear();
                                onClose();
                              },
                            ),
                          ),

                          // Divider
                          Container(
                            width: 1,
                            height: 220,
                            margin: const EdgeInsets.symmetric(horizontal: 20),
                            color: elyon.borderColor,
                          ),

                          // ── Nav links ──────────────────────────
                          SizedBox(
                            width: 210,
                            child: Column(
                              children: [
                                _NavItem(
                                  icon: Icons.person_outline_rounded,
                                  label: t.navProfile,
                                  onTap: () { onClose(); onOpenProfile(); },
                                ),
                                _NavItem(
                                  icon: Icons.credit_card_rounded,
                                  label: t.navPricing,
                                  onTap: () { onClose(); onOpenPricing(); },
                                ),
                                _NavItem(
                                  icon: Icons.settings_outlined,
                                  label: t.navSettings,
                                  onTap: () { onClose(); onOpenSettings(); },
                                ),
                                if (isOwner)
                                  _NavItem(
                                    icon: Icons.admin_panel_settings_outlined,
                                    label: t.navAdmin,
                                    onTap: () { onClose(); onOpenAdmin(); },
                                  ),
                                Container(
                                  margin: const EdgeInsets.symmetric(vertical: 6),
                                  height: 1,
                                  color: elyon.borderColor,
                                ),
                                _NavItem(
                                  icon: Icons.description_outlined,
                                  label: t.navPrivacy,
                                  onTap: () {
                                    onClose();
                                    launchUrl(
                                      Uri.parse('https://elyon-ai-web.vercel.app/privacy.html'),
                                      mode: LaunchMode.externalApplication,
                                    );
                                  },
                                ),
                                _NavItem(
                                  icon: Icons.gavel_outlined,
                                  label: t.navTerms,
                                  onTap: () {
                                    onClose();
                                    launchUrl(
                                      Uri.parse('https://elyon-ai-web.vercel.app/privacy.html?tab=terms'),
                                      mode: LaunchMode.externalApplication,
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _ChatHistorySection extends StatelessWidget {
  const _ChatHistorySection({
    required this.t,
    required this.sessions,
    required this.activeId,
    required this.onSelect,
    required this.onDelete,
    required this.onNewChat,
  });

  final AppStrings t;
  final List<ChatSession> sessions;
  final String? activeId;
  final void Function(ChatSession) onSelect;
  final void Function(String) onDelete;
  final VoidCallback onNewChat;

  @override
  Widget build(BuildContext context) {
    final elyon = context.elyon;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Фикс: динамический цвет вместо AppTextStyles.sectionLabel
        // (статичный AppColors.muted был полупрозрачным белым — невидим на светлой теме)
        Text(
          t.recentChats,
          style: const TextStyle(
            fontFamily: 'DMSans', fontSize: 10, fontWeight: FontWeight.w500,
            letterSpacing: 1.4, color: AppColors.beige2,
          ),
        ),
        const SizedBox(height: 10),

        if (sessions.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Text(
              t.noConversations,
              style: TextStyle(
                fontFamily: 'DMSans', fontSize: 13,
                fontWeight: FontWeight.w300, color: elyon.mutedText,
              ),
            ),
          )
        else
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: sessions
                .take(12)
                .map((s) => _ChatChip(
                      session:  s,
                      isActive: s.id == activeId,
                      onTap:    () => onSelect(s),
                      onDelete: () => onDelete(s.id),
                    ))
                .toList(),
          ),

        const SizedBox(height: 14),
        _NewChatTile(label: t.newChatTile, onTap: onNewChat),
      ],
    );
  }
}

class _ChatChip extends StatefulWidget {
  const _ChatChip({
    required this.session,
    required this.isActive,
    required this.onTap,
    required this.onDelete,
  });

  final ChatSession session;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  State<_ChatChip> createState() => _ChatChipState();
}

class _ChatChipState extends State<_ChatChip> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final elyon = context.elyon;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit:  (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 180,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: widget.isActive
                ? AppColors.beige.withOpacity(0.07)
                : _hover
                    ? elyon.primaryText.withOpacity(0.04)
                    : Colors.transparent,
            border: Border.all(
              color: widget.isActive
                  ? AppColors.beige.withOpacity(0.12)
                  : _hover
                      ? elyon.borderColor
                      : Colors.transparent,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(
                Icons.chat_bubble_outline_rounded,
                size: 13,
                color: elyon.mutedText,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.session.displayTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'DMSans',
                    fontSize: 13,
                    color: widget.isActive || _hover
                        ? elyon.primaryText
                        : elyon.mutedText,
                  ),
                ),
              ),
              if (_hover)
                GestureDetector(
                  onTap: widget.onDelete,
                  child: const Icon(
                    Icons.close_rounded,
                    size: 13,
                    color: AppColors.danger,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NewChatTile extends StatefulWidget {
  const _NewChatTile({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  State<_NewChatTile> createState() => _NewChatTileState();
}

class _NewChatTileState extends State<_NewChatTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final elyon = context.elyon;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit:  (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: _hover
                ? elyon.primaryText.withOpacity(0.03)
                : Colors.transparent,
            border: Border.all(
              color: _hover
                  ? AppColors.beige.withOpacity(0.25)
                  : elyon.primaryText.withOpacity(0.12),
              style: BorderStyle.solid,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(
                Icons.add_rounded,
                size: 14,
                color: _hover ? elyon.primaryText : elyon.mutedText,
              ),
              const SizedBox(width: 8),
              Text(
                widget.label,
                style: TextStyle(
                  fontFamily: 'DMSans',
                  fontSize: 13,
                  color: _hover ? elyon.primaryText : elyon.mutedText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _NavItem extends StatefulWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final elyon = context.elyon;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit:  (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: _hover
                ? elyon.primaryText.withOpacity(0.04)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 20,
                child: Icon(
                  widget.icon,
                  size: 15,
                  color: _hover ? elyon.primaryText : elyon.mutedText,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'DMSans',
                    fontSize: 13,
                    color: _hover ? elyon.primaryText : elyon.mutedText,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
