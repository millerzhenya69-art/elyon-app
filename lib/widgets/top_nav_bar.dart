import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../models/user_model.dart';
import '../providers/app_providers.dart';
import '../providers/app_strings.dart';
import 'elyon_logo.dart';

class TopNavBar extends ConsumerStatefulWidget {
  const TopNavBar({
    super.key,
    required this.sidebarOpen,
    required this.onMenuTap,
    required this.onNewChat,
    required this.onProfileTap,
    required this.onSettingsTap,
    required this.user,
  });
  final bool sidebarOpen;
  final VoidCallback onMenuTap, onNewChat, onProfileTap, onSettingsTap;
  final AppUser? user;

  @override
  ConsumerState<TopNavBar> createState() => _TopNavBarState();
}

class _TopNavBarState extends ConsumerState<TopNavBar> {
  bool _dropdownOpen = false;
  final _layerLink = LayerLink();
  OverlayEntry? _overlay;

  List<_ModelInfo> _models(AppStrings t) => [
    _ModelInfo(label: 'Core',       badge: 'FREE', desc: t.modelCoreDesc,       tier: SubscriptionTier.core),
    _ModelInfo(label: 'Nova',       badge: '91₽',  desc: t.modelNovaDesc,       tier: SubscriptionTier.nova),
    _ModelInfo(label: 'PRO',        badge: '182₽', desc: t.modelProDesc,        tier: SubscriptionTier.pro),
    _ModelInfo(label: 'Absolution', badge: '265₽', desc: t.modelAbsolutionDesc, tier: SubscriptionTier.absolution),
  ];

  SubscriptionTier _selected = SubscriptionTier.core;

  @override
  void didUpdateWidget(TopNavBar old) {
    super.didUpdateWidget(old);
    if (widget.user != null && _selected == SubscriptionTier.core) {
      _selected = widget.user!.tier;
    }
  }

  String get _label => _models(AppStrings.of(ref)).firstWhere((m) => m.tier == _selected).label;

  void _toggle() => _dropdownOpen ? _close() : _open();

  void _open() {
    setState(() => _dropdownOpen = true);
    _overlay = _buildOverlay();
    Overlay.of(context).insert(_overlay!);
  }

  void _close() {
    setState(() => _dropdownOpen = false);
    _overlay?.remove();
    _overlay = null;
  }

  OverlayEntry _buildOverlay() {
    return OverlayEntry(builder: (_) {
      final elyon = context.elyon;
      final t = AppStrings.of(ref);
      final userTier = widget.user?.tier ?? SubscriptionTier.core;
      return GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: _close,
        child: Stack(children: [
          Positioned.fill(child: Container(color: Colors.transparent)),
          CompositedTransformFollower(
            link: _layerLink,
            offset: const Offset(0, 46),
            child: Align(
              alignment: Alignment.topLeft,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: 240,
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: elyon.cardBg,
                    border: Border.all(color: elyon.border2Color),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4),
                        blurRadius: 24, offset: const Offset(0, 4))],
                  ),
                  child: Column(mainAxisSize: MainAxisSize.min,
                    children: _models(t).map((m) {
                      final hasAccess = m.tier.index <= userTier.index;
                      return _ModelOption(
                        model: m, isActive: m.tier == _selected,
                        hasAccess: hasAccess,
                        onTap: () {
                          if (hasAccess) setState(() => _selected = m.tier);
                          _close();
                        },
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),
        ]),
      );
    });
  }

  @override
  void dispose() { _overlay?.remove(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final elyon = context.elyon;
    return Container(
      height: 52,
      // Use scaffoldBg with opacity — same as web rgba(14,14,14,0.88)
      decoration: BoxDecoration(
        color: elyon.scaffoldBg.withOpacity(0.9),
        border: Border(bottom: BorderSide(color: elyon.borderColor)),
      ),
      child: Row(children: [
        const SizedBox(width: 8),
        _IconBtn(icon: Icons.menu_rounded, onTap: widget.onMenuTap, active: widget.sidebarOpen),
        const SizedBox(width: 4),
        // Logo
        const ElyonLogo(size: 28),
        const SizedBox(width: 8),
        Text('Elyon', style: TextStyle(fontFamily: 'InstrumentSerif',
            fontSize: 17, color: elyon.primaryText)),
        const SizedBox(width: 12),
        // Model pill
        CompositedTransformTarget(
          link: _layerLink,
          child: GestureDetector(
            onTap: _toggle,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: elyon.surfaceBg,
                border: Border.all(color: _dropdownOpen ? elyon.border2Color : elyon.borderColor),
                borderRadius: BorderRadius.circular(100),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 6, height: 6,
                    decoration: const BoxDecoration(color: AppColors.beige, shape: BoxShape.circle)),
                const SizedBox(width: 6),
                Text(_label, style: TextStyle(fontFamily: 'DMSans', fontSize: 13,
                    fontWeight: FontWeight.w500, color: elyon.accent2Color)),
                const SizedBox(width: 4),
                Icon(_dropdownOpen ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                    size: 14, color: elyon.mutedText),
              ]),
            ),
          ),
        ),
        const Spacer(),
        _NewChatBtn(onTap: widget.onNewChat),
        const SizedBox(width: 8),
        _AvatarBtn(user: widget.user, onTap: widget.onProfileTap),
        const SizedBox(width: 12),
      ]),
    );
  }
}

// ── Model dropdown option ─────────────────────────────────────────

class _ModelOption extends StatefulWidget {
  const _ModelOption({required this.model, required this.isActive,
    required this.hasAccess, required this.onTap});
  final _ModelInfo model; final bool isActive, hasAccess; final VoidCallback onTap;
  @override State<_ModelOption> createState() => _ModelOptionState();
}
class _ModelOptionState extends State<_ModelOption> {
  bool _h = false;
  @override
  Widget build(BuildContext context) {
    final elyon = context.elyon;
    return MouseRegion(
      onEnter: (_) => setState(() => _h = true),
      onExit:  (_) => setState(() => _h = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Opacity(
          opacity: widget.hasAccess ? 1.0 : 0.4,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: widget.isActive ? elyon.surfaceBg
                  : (_h ? elyon.surfaceBg.withOpacity(0.5) : Colors.transparent),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Elyon ${widget.model.label}', style: TextStyle(fontFamily: 'DMSans',
                    fontSize: 13, fontWeight: FontWeight.w500, color: elyon.primaryText)),
                Text(widget.model.desc, style: TextStyle(fontFamily: 'DMSans',
                    fontSize: 11, color: elyon.mutedText)),
              ])),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(100)),
                child: Text(widget.model.badge, style: TextStyle(fontFamily: 'DMSans',
                    fontSize: 10, fontWeight: FontWeight.w600,
                    color: elyon.accent2Color, letterSpacing: 0.04)),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

// ── Small nav atoms ───────────────────────────────────────────────

class _IconBtn extends StatefulWidget {
  const _IconBtn({required this.icon, required this.onTap, this.active = false});
  final IconData icon; final VoidCallback onTap; final bool active;
  @override State<_IconBtn> createState() => _IconBtnState();
}
class _IconBtnState extends State<_IconBtn> {
  bool _h = false;
  @override
  Widget build(BuildContext context) {
    final elyon = context.elyon;
    return MouseRegion(
      onEnter: (_) => setState(() => _h = true),
      onExit:  (_) => setState(() => _h = false),
      child: GestureDetector(onTap: widget.onTap,
        child: AnimatedContainer(duration: const Duration(milliseconds: 120),
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: (_h || widget.active) ? Colors.white.withOpacity(0.07) : Colors.transparent,
            borderRadius: BorderRadius.circular(9)),
          child: Icon(widget.icon, size: 18, color: elyon.primaryText.withOpacity(0.7)))),
    );
  }
}

class _NewChatBtn extends ConsumerStatefulWidget {
  const _NewChatBtn({required this.onTap});
  final VoidCallback onTap;
  @override ConsumerState<_NewChatBtn> createState() => _NewChatBtnState();
}
class _NewChatBtnState extends ConsumerState<_NewChatBtn> {
  bool _h = false;
  @override
  Widget build(BuildContext context) {
    final elyon = context.elyon;
    final t = AppStrings.of(ref);
    return MouseRegion(
      onEnter: (_) => setState(() => _h = true),
      onExit:  (_) => setState(() => _h = false),
      child: GestureDetector(onTap: widget.onTap,
        child: AnimatedContainer(duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            border: Border.all(color: _h ? elyon.border2Color : elyon.borderColor),
            borderRadius: BorderRadius.circular(100)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.add_rounded, size: 16, color: elyon.mutedText),
            const SizedBox(width: 4),
            Text(t.newChat, style: TextStyle(fontFamily: 'DMSans', fontSize: 13,
                color: _h ? elyon.primaryText : elyon.mutedText)),
          ]))),
    );
  }
}

class _AvatarBtn extends StatefulWidget {
  const _AvatarBtn({required this.user, required this.onTap});
  final AppUser? user; final VoidCallback onTap;
  @override State<_AvatarBtn> createState() => _AvatarBtnState();
}
class _AvatarBtnState extends State<_AvatarBtn> {
  bool _h = false;
  @override
  Widget build(BuildContext context) {
    final letter = widget.user?.initials ?? 'U';
    return MouseRegion(
      onEnter: (_) => setState(() => _h = true),
      onExit:  (_) => setState(() => _h = false),
      child: GestureDetector(onTap: widget.onTap,
        child: AnimatedContainer(duration: const Duration(milliseconds: 120),
          width: 36, height: 36,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.beige2, AppColors.beige],
              begin: Alignment.topLeft, end: Alignment.bottomRight),
            shape: BoxShape.circle,
            boxShadow: _h ? [BoxShadow(color: AppColors.beige.withOpacity(0.3),
                blurRadius: 8, spreadRadius: 1)] : []),
          child: Center(child: Text(letter, style: const TextStyle(
            fontFamily: 'DMSans', fontSize: 13,
            fontWeight: FontWeight.w600, color: AppColors.black))))),
    );
  }
}

class _ModelInfo {
  const _ModelInfo({required this.label, required this.badge,
    required this.desc, required this.tier});
  final String label, badge, desc;
  final SubscriptionTier tier;
}
