import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../models/user_model.dart';
import '../models/app_settings.dart';
import '../providers/app_providers.dart';
import '../providers/app_strings.dart';

/// Profile panel — matches web app profile panel.
class ProfilePanel extends ConsumerWidget {
  const ProfilePanel({
    super.key,
    required this.onBack,
    required this.onSignOut,
    required this.onUpgrade,
  });

  final VoidCallback onBack;
  final VoidCallback onSignOut;
  final VoidCallback onUpgrade;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final elyon = context.elyon;
    final t = AppStrings.of(ref);
    final user  = ref.watch(userProvider);

    return Container(
      color: elyon.scaffoldBg,
      child: Column(
        children: [
          // Header
          _PanelHeader(title: t.profileTitle, onBack: onBack),

          // Body
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: user == null
                      ? const _LoadingState()
                      : _ProfileBody(
                          t:         t,
                          user:      user,
                          onSignOut: onSignOut,
                          onUpgrade: onUpgrade,
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Profile body ──────────────────────────────────────────────────

class _ProfileBody extends StatelessWidget {
  const _ProfileBody({
    required this.t,
    required this.user,
    required this.onSignOut,
    required this.onUpgrade,
  });

  final AppStrings t;
  final AppUser user;
  final VoidCallback onSignOut;
  final VoidCallback onUpgrade;

  @override
  Widget build(BuildContext context) {
    final elyon = context.elyon;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 8),

        // Avatar
        Container(
          width: 72, height: 72,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.beige2, AppColors.beige],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              user.initials,
              style: const TextStyle(
                fontFamily: 'DMSans',
                fontSize: 26,
                fontWeight: FontWeight.w600,
                color: AppColors.black,
              ),
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Display name — Фикс: динамический цвет под тему (был AppColors.white жёстко)
        Text(
          user.displayName,
          style: TextStyle(
            fontFamily: 'InstrumentSerif',
            fontSize: 24,
            color: elyon.primaryText,
          ),
        ),

        const SizedBox(height: 4),

        // Email / handle
        Text(
          user.email,
          style: TextStyle(
            fontFamily: 'DMSans',
            fontSize: 13,
            color: elyon.mutedText,
          ),
        ),

        const SizedBox(height: 28),

        // Subscription card
        _InfoCard(
          label: t.currentPlanLabel,
          children: [
            Text(
              'Elyon ${user.tier.displayName}',
              style: TextStyle(
                fontFamily: 'DMSans',
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: elyon.primaryText,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              t.messagesRemaining(user.remainingMessages),
              style: TextStyle(
                fontFamily: 'DMSans', fontSize: 12,
                color: elyon.mutedText,
              ),
            ),
          ],
        ),

        const SizedBox(height: 10),

        // Auth provider card
        _InfoCard(
          label: t.authProvider,
          children: [
            Text(
              user.authProvider,
              style: TextStyle(
                fontFamily: 'DMSans', fontSize: 15,
                fontWeight: FontWeight.w500, color: elyon.primaryText,
              ),
            ),
          ],
        ),

        const SizedBox(height: 10),

        // Member since
        _InfoCard(
          label: t.memberSince,
          children: [
            Text(
              '${_monthName(user.joinedAt.month)} ${user.joinedAt.year}',
              style: TextStyle(
                fontFamily: 'DMSans', fontSize: 15,
                fontWeight: FontWeight.w500, color: elyon.primaryText,
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),

        // Upgrade button (hidden if already on absolution)
        if (user.tier != SubscriptionTier.absolution)
          _ActionBtn(
            label:   t.upgradePlan,
            primary: true,
            onTap:   onUpgrade,
          ),

        const SizedBox(height: 10),

        // Sign out
        _ActionBtn(
          label:   t.signOut,
          primary: false,
          danger:  true,
          onTap:   onSignOut,
        ),
      ],
    );
  }

  String _monthName(int month) {
    final names = t.lang == AppLanguage.russian
        ? const ['', 'Январь', 'Февраль', 'Март', 'Апрель', 'Май', 'Июнь',
            'Июль', 'Август', 'Сентябрь', 'Октябрь', 'Ноябрь', 'Декабрь']
        : const ['', 'January', 'February', 'March', 'April', 'May', 'June',
            'July', 'August', 'September', 'October', 'November', 'December'];
    return names[month];
  }
}

// ── Shared small components ───────────────────────────────────────

class _PanelHeader extends StatelessWidget {
  const _PanelHeader({required this.title, required this.onBack});
  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final elyon = context.elyon;
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: elyon.borderColor)),
      ),
      child: Row(children: [
        GestureDetector(
          onTap: onBack,
          child: Icon(Icons.arrow_back_rounded,
              color: elyon.mutedText, size: 20),
        ),
        const SizedBox(width: 12),
        // Фикс: динамический цвет под тему (был AppTextStyles.panelTitle() — статичный белый)
        Text(
          title,
          style: TextStyle(
            fontFamily: 'InstrumentSerif', fontSize: 20,
            fontWeight: FontWeight.w400, color: elyon.primaryText,
          ),
        ),
      ]),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.label, required this.children});
  final String label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final elyon = context.elyon;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      decoration: BoxDecoration(
        color: elyon.surfaceBg,
        border: Border.all(color: elyon.borderColor),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontFamily: 'DMSans', fontSize: 11, fontWeight: FontWeight.w500,
            letterSpacing: 0.8, color: AppColors.beige2,
          ),
        ),
        const SizedBox(height: 6),
        ...children,
      ]),
    );
  }
}

class _ActionBtn extends StatefulWidget {
  const _ActionBtn({
    required this.label,
    required this.primary,
    this.danger = false,
    required this.onTap,
  });
  final String label;
  final bool primary;
  final bool danger;
  final VoidCallback onTap;

  @override
  State<_ActionBtn> createState() => _ActionBtnState();
}

class _ActionBtnState extends State<_ActionBtn> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final elyon = context.elyon;

    Color bg;
    Color border;
    Color text;

    if (widget.primary) {
      bg     = _hover ? AppColors.white  : AppColors.beige;
      border = Colors.transparent;
      text   = AppColors.black;
    } else if (widget.danger) {
      bg     = _hover ? AppColors.danger.withOpacity(0.12) : Colors.transparent;
      border = _hover ? AppColors.danger.withOpacity(0.5)
                      : AppColors.danger.withOpacity(0.3);
      text   = AppColors.danger;
    } else {
      bg     = _hover ? elyon.surfaceBg : Colors.transparent;
      border = _hover ? elyon.border2Color : elyon.borderColor;
      text   = elyon.primaryText;
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit:  (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(
            color: bg,
            border: Border.all(color: border),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Center(child: Text(widget.label, style: TextStyle(
            fontFamily: 'DMSans', fontSize: 14,
            fontWeight: FontWeight.w500, color: text,
          ))),
        ),
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();
  @override
  Widget build(BuildContext context) =>
      const Center(child: CircularProgressIndicator());
}
