import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_theme.dart';
import '../providers/app_strings.dart';
import 'chat_input_box.dart';
import 'elyon_logo.dart';

class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key, required this.onSend, required this.onChipTap});
  final void Function(String) onSend;
  final void Function(String) onChipTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final elyon = context.elyon;
    final t = AppStrings.of(ref);
    final chips = [
      t.chipWhatCanYouDo,
      t.chipShortStory,
      t.chipQuantum,
      t.chipPlanWeek,
      t.chipTranslateRu,
      t.chipDebugCode,
    ];
    return Container(
      // Explicit bg — prevents white flash
      color: elyon.scaffoldBg,
      child: Column(children: [
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                _BouncingLogo()
                    .animate()
                    .fadeIn(duration: 500.ms)
                    .slideY(begin: 0.08, end: 0, duration: 500.ms),
                const SizedBox(height: 24),
                Text.rich(TextSpan(children: [
                  TextSpan(
                    text: t.helloIAm,
                    style: AppTextStyles.heroTitle(fontSize: 40)
                        .copyWith(color: elyon.primaryText),
                  ),
                  TextSpan(
                    text: t.elyonName,
                    style: AppTextStyles.heroTitleItalic(fontSize: 40),
                  ),
                ]), textAlign: TextAlign.center)
                    .animate()
                    .fadeIn(delay: 100.ms, duration: 500.ms)
                    .slideY(begin: 0.06, end: 0, duration: 500.ms),
                const SizedBox(height: 10),
                Text(t.howCanIHelp, style: TextStyle(
                  fontFamily: 'DMSans', fontSize: 14, fontWeight: FontWeight.w300,
                  color: elyon.mutedText),
                  textAlign: TextAlign.center,
                ).animate().fadeIn(delay: 180.ms, duration: 500.ms),
                const SizedBox(height: 40),
                Wrap(
                  spacing: 8, runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: chips.asMap().entries.map((e) =>
                    _Chip(label: e.value, onTap: () => onChipTap(e.value))
                        .animate()
                        .fadeIn(delay: Duration(milliseconds: 250 + e.key * 40),
                            duration: 400.ms),
                  ).toList(),
                ),
              ]),
            ),
          ),
        ),
        // Input pinned at bottom
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: ChatInputBox(onSend: onSend),
          ),
        ),
        const SizedBox(height: 12),
      ]),
    );
  }
}

// ── Bouncing logo (WelcomeScreen) ─────────────────────────────────

class _BouncingLogo extends StatefulWidget {
  @override State<_BouncingLogo> createState() => _BouncingLogoState();
}
class _BouncingLogoState extends State<_BouncingLogo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 4))
        ..repeat(reverse: true);
    _anim = Tween<double>(begin: 0, end: -6)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, child) => Transform.translate(
          offset: Offset(0, _anim.value), child: child),
      child: const ElyonLogo(size: 56),
    );
  }
}

// ── Suggestion chip ───────────────────────────────────────────────

class _Chip extends StatefulWidget {
  const _Chip({required this.label, required this.onTap});
  final String label; final VoidCallback onTap;
  @override State<_Chip> createState() => _ChipState();
}
class _ChipState extends State<_Chip> {
  bool _h = false;
  @override
  Widget build(BuildContext context) {
    final elyon = context.elyon;
    return MouseRegion(
      onEnter: (_) => setState(() => _h = true),
      onExit:  (_) => setState(() => _h = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: BoxDecoration(
            color: _h ? elyon.cardBg : elyon.surfaceBg,
            border: Border.all(
              color: _h ? AppColors.beige.withOpacity(0.22) : elyon.borderColor),
            borderRadius: BorderRadius.circular(100)),
          child: Text(widget.label, style: TextStyle(fontFamily: 'DMSans',
              fontSize: 13, color: _h ? elyon.primaryText : elyon.mutedText)),
        ),
      ),
    );
  }
}
