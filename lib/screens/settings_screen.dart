import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../providers/app_providers.dart';
import '../providers/app_strings.dart';
import '../models/app_settings.dart';
import '../models/user_model.dart';

// ── DonatePay / Telegram links ────────────────────────────────────
// Фикс: рабочая ссылка на виджет DonatePay (new.donatepay.ru/@1383607)
// вместо устаревшего widget.donatepay.ru/widgets/page/... (давал 404).

const _kDonatePayProfile = 'https://new.donatepay.ru/@1383607';
const _kTgBot = 'Elyon_by_unkony_bot';

String _donatePayUrl(SubscriptionTier tier) {
  final amount = switch (tier) {
    SubscriptionTier.nova       => '91',
    SubscriptionTier.pro        => '182',
    SubscriptionTier.absolution => '265',
    _                           => '0',
  };
  // new.donatepay.ru поддерживает префилл суммы через query-параметр amount
  return '$_kDonatePayProfile?amount=$amount';
}

String _tgStarsUrl(SubscriptionTier tier) {
  final param = switch (tier) {
    SubscriptionTier.nova       => 'pay_nova',
    SubscriptionTier.pro        => 'pay_pro',
    SubscriptionTier.absolution => 'pay_abs',
    _                           => 'pay_nova',
  };
  return 'https://t.me/$_kTgBot?start=$param';
}

Future<void> _openUrl(String url) async {
  final uri = Uri.parse(url);
  if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
    debugPrint('Could not launch $url');
  }
}

// ═════════════════════════════════════════════════════════════════
// SettingsPanel
// ═════════════════════════════════════════════════════════════════

class SettingsPanel extends ConsumerWidget {
  const SettingsPanel({super.key, required this.onBack});
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final elyon    = context.elyon;
    final t        = AppStrings.of(ref);
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return Container(
      color: elyon.scaffoldBg,
      child: Column(
        children: [
          _PanelHeader(title: t.settingsTitle, onBack: onBack),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Appearance ─────────────────────────────
                    _SectionLabel(t.appearance),

                    _SettingsRow(
                      label: t.theme,
                      child: _ThemeSegment(
                        t: t,
                        current: settings.themeMode,
                        onChange: notifier.setTheme,
                      ),
                    ),

                    _SettingsRow(
                      label: t.fontSize,
                      child: _FontSizeSegment(
                        t: t,
                        current: settings.fontSize,
                        onChange: notifier.setFontSize,
                      ),
                    ),

                    const SizedBox(height: 32),

                    // ── Language ───────────────────────────────
                    _SectionLabel(t.language),

                    _SettingsRow(
                      label: t.interfaceLanguage,
                      child: _LangSegment(
                        current: settings.language,
                        onChange: notifier.setLanguage,
                      ),
                    ),

                    const SizedBox(height: 32),

                    // ── Chat ───────────────────────────────────
                    _SectionLabel(t.chatSection),

                    _SettingsRow(
                      label:    t.streamingResponses,
                      sublabel: t.streamingSub,
                      child: _ElyonToggle(
                        value:    settings.streamingEnabled,
                        onToggle: notifier.toggleStreaming,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════
// PricingPanel
// ═════════════════════════════════════════════════════════════════

class PricingPanel extends ConsumerWidget {
  const PricingPanel({super.key, required this.onBack});
  final VoidCallback onBack;

  static const _tiers = [
    (tier: SubscriptionTier.core,       featured: false),
    (tier: SubscriptionTier.nova,       featured: false),
    (tier: SubscriptionTier.pro,        featured: true),
    (tier: SubscriptionTier.absolution, featured: false),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final elyon = context.elyon;
    final t     = AppStrings.of(ref);
    final user  = ref.watch(userProvider);

    return Container(
      color: elyon.scaffoldBg,
      child: Column(
        children: [
          _PanelHeader(title: t.pricingTitle, onBack: onBack),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: Column(
                  children: _tiers
                      .map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _PricingCard(
                            t:        t,
                            tier:     item.tier,
                            featured: item.featured,
                            isActive: user?.tier == item.tier,
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Pricing card ─────────────────────────────────────────────────

class _PricingCard extends StatefulWidget {
  const _PricingCard({
    required this.t,
    required this.tier,
    required this.featured,
    required this.isActive,
  });

  final AppStrings        t;
  final SubscriptionTier  tier;
  final bool              featured;
  final bool              isActive;

  @override
  State<_PricingCard> createState() => _PricingCardState();
}

class _PricingCardState extends State<_PricingCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final elyon = context.elyon;
    final tier  = widget.tier;

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit:  (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: widget.featured ? elyon.cardBg : elyon.surfaceBg,
          border: Border.all(
            color: widget.featured || _hover
                ? AppColors.beige.withOpacity(0.25)
                : elyon.borderColor,
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Featured top accent line
            if (widget.featured)
              Container(
                height: 2,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: const BoxDecoration(
                  gradient: AppColors.topLineGradient,
                  borderRadius: BorderRadius.all(Radius.circular(1)),
                ),
              ),

            // Tier label
            Text(
              tier.displayName.toUpperCase(),
              style: const TextStyle(
                fontFamily: 'DMSans', fontSize: 11,
                fontWeight: FontWeight.w600, letterSpacing: 1.2,
                color: AppColors.beige2,
              ),
            ),
            const SizedBox(height: 8),

            // Tier name — динамический цвет под тему
            Text(
              'Elyon ${tier.displayName}',
              style: TextStyle(
                fontFamily: 'InstrumentSerif', fontSize: 22,
                fontWeight: FontWeight.w400, color: elyon.primaryText,
              ),
            ),
            const SizedBox(height: 4),

            // Price — динамический цвет под тему
            RichText(
              text: TextSpan(children: [
                TextSpan(
                  text: tier.isFree ? widget.t.free : '${tier.priceRub} ₽',
                  style: TextStyle(
                    fontFamily: 'DMSans', fontSize: 28,
                    fontWeight: FontWeight.w300, color: elyon.primaryText,
                  ),
                ),
                if (!tier.isFree)
                  TextSpan(
                    text: widget.t.perMonth,
                    style: TextStyle(
                      fontFamily: 'DMSans', fontSize: 14,
                      color: elyon.mutedText,
                    ),
                  ),
              ]),
            ),
            const SizedBox(height: 12),

            // Description
            Text(
              widget.t.tierDescription(tier),
              style: TextStyle(
                fontFamily: 'DMSans', fontSize: 13, height: 1.6,
                color: elyon.mutedText,
              ),
            ),
            const SizedBox(height: 12),

            // Daily limit badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.beige.withOpacity(0.07),
                borderRadius: BorderRadius.circular(100),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.bolt_rounded, size: 12, color: AppColors.beige2),
                const SizedBox(width: 4),
                Text(
                  '${tier.dailyLimit} ${widget.t.messagesPerDay}',
                  style: const TextStyle(
                    fontFamily: 'DMSans', fontSize: 12, color: AppColors.beige2),
                ),
              ]),
            ),
            const SizedBox(height: 16),

            // ── CTA кнопки ──────────────────────────────────────

            if (tier.isFree || widget.isActive) ...[
              SizedBox(
                width: double.infinity,
                child: _PricingButton(
                  label:    widget.isActive ? widget.t.currentPlan : widget.t.getStarted,
                  featured: widget.featured,
                  disabled: true,
                  onTap:    () {},
                ),
              ),
            ] else ...[
              // Оплата картой / СБП через DonatePay (фикс: рабочая ссылка)
              SizedBox(
                width: double.infinity,
                child: _PricingButton(
                  label:    '💳 ${tier.priceRub} ₽  —  карта / СБП',
                  featured: widget.featured,
                  disabled: false,
                  onTap:    () => _openUrl(_donatePayUrl(tier)),
                ),
              ),
              const SizedBox(height: 8),
              // Telegram Stars
              SizedBox(
                width: double.infinity,
                child: _TgStarsButton(
                  tier: tier,
                  onTap: () => _openUrl(_tgStarsUrl(tier)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Telegram Stars button ─────────────────────────────────────────

class _TgStarsButton extends StatefulWidget {
  const _TgStarsButton({required this.tier, required this.onTap});
  final SubscriptionTier tier;
  final VoidCallback onTap;
  @override
  State<_TgStarsButton> createState() => _TgStarsButtonState();
}

class _TgStarsButtonState extends State<_TgStarsButton> {
  bool _h = false;

  int get _stars => switch (widget.tier) {
    SubscriptionTier.nova       => 50,
    SubscriptionTier.pro        => 100,
    SubscriptionTier.absolution => 150,
    _                           => 0,
  };

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
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: _h
                ? const Color(0xFFFFA500).withOpacity(0.12)
                : const Color(0xFFFFA500).withOpacity(0.06),
            border: Border.all(
              color: const Color(0xFFFFA500).withOpacity(_h ? 0.5 : 0.25),
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(
              '⭐  $_stars Stars  —  Telegram',
              style: TextStyle(
                fontFamily: 'DMSans', fontSize: 13,
                fontWeight: FontWeight.w500,
                color: elyon.primaryText,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Pricing main button ───────────────────────────────────────────

class _PricingButton extends StatefulWidget {
  const _PricingButton({
    required this.label, required this.featured,
    required this.disabled, required this.onTap,
  });
  final String label; final bool featured, disabled;
  final VoidCallback onTap;
  @override
  State<_PricingButton> createState() => _PricingButtonState();
}

class _PricingButtonState extends State<_PricingButton> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final elyon = context.elyon;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit:  (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.disabled ? null : widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: widget.featured
                ? (_hover ? AppColors.white : AppColors.beige)
                : (_hover
                    ? elyon.primaryText.withOpacity(0.05)
                    : Colors.transparent),
            border: Border.all(
              color: widget.featured
                  ? Colors.transparent
                  : (_hover ? elyon.border2Color : elyon.borderColor),
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(
              widget.label,
              style: TextStyle(
                fontFamily: 'DMSans', fontSize: 13,
                fontWeight: FontWeight.w500,
                color: widget.featured ? AppColors.black : elyon.primaryText,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════
// Shared panel components — Фикс контраста на светлой теме:
// все цвета берутся из context.elyon вместо статичных AppTextStyles.*
// ═════════════════════════════════════════════════════════════════

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
        border: Border(bottom: BorderSide(color: elyon.borderColor))),
      child: Row(children: [
        GestureDetector(
          onTap: onBack,
          child: Icon(Icons.arrow_back_rounded, color: elyon.mutedText, size: 20)),
        const SizedBox(width: 12),
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

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontFamily: 'DMSans', fontSize: 11, fontWeight: FontWeight.w500,
          letterSpacing: 1.2, color: AppColors.beige2),
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({required this.label, this.sublabel, required this.child});
  final String label; final String? sublabel; final Widget child;
  @override
  Widget build(BuildContext context) {
    final elyon = context.elyon;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: elyon.borderColor))),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Фикс: динамический цвет вместо AppTextStyles.settingsRow (AppColors.white жёстко)
          Text(
            label,
            style: TextStyle(
              fontFamily: 'DMSans', fontSize: 14,
              fontWeight: FontWeight.w400, color: elyon.primaryText,
            ),
          ),
          if (sublabel != null) ...[
            const SizedBox(height: 2),
            Text(
              sublabel!,
              style: TextStyle(
                fontFamily: 'DMSans', fontSize: 12,
                fontWeight: FontWeight.w300, color: elyon.mutedText,
              ),
            ),
          ],
        ])),
        child,
      ]),
    );
  }
}

// ── Segment controls ──────────────────────────────────────────────

class _ThemeSegment extends StatelessWidget {
  const _ThemeSegment({required this.t, required this.current, required this.onChange});
  final AppStrings t; final AppThemeMode current;
  final void Function(AppThemeMode) onChange;
  @override
  Widget build(BuildContext context) {
    String label(AppThemeMode v) => switch (v) {
      AppThemeMode.dark   => t.themeDark,
      AppThemeMode.amoled => t.themeAmoled,
      AppThemeMode.light  => t.themeLight,
    };
    return _Segment<AppThemeMode>(
        values: AppThemeMode.values, current: current,
        label: label, onSelect: onChange);
  }
}

class _FontSizeSegment extends StatelessWidget {
  const _FontSizeSegment({required this.t, required this.current, required this.onChange});
  final AppStrings t; final FontSizeOption current;
  final void Function(FontSizeOption) onChange;
  @override
  Widget build(BuildContext context) {
    String label(FontSizeOption v) => switch (v) {
      FontSizeOption.small  => t.fontSmall,
      FontSizeOption.medium => t.fontMedium,
      FontSizeOption.large  => t.fontLarge,
    };
    return _Segment<FontSizeOption>(
        values: FontSizeOption.values, current: current,
        label: label, onSelect: onChange);
  }
}

class _LangSegment extends StatelessWidget {
  const _LangSegment({required this.current, required this.onChange});
  final AppLanguage current; final void Function(AppLanguage) onChange;
  @override
  Widget build(BuildContext context) {
    return _Segment<AppLanguage>(
        values: AppLanguage.values, current: current,
        label: (v) => v.label, onSelect: onChange);
  }
}

class _Segment<T> extends StatelessWidget {
  const _Segment({required this.values, required this.current,
    required this.label, required this.onSelect});
  final List<T> values; final T current;
  final String Function(T) label; final void Function(T) onSelect;
  @override
  Widget build(BuildContext context) {
    final elyon = context.elyon;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: elyon.surfaceBg,
        border: Border.all(color: elyon.borderColor),
        borderRadius: BorderRadius.circular(10)),
      child: Row(mainAxisSize: MainAxisSize.min, children: values.map((v) {
        final active = v == current;
        return GestureDetector(
          onTap: () => onSelect(v),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: active ? elyon.card2Bg : Colors.transparent,
              borderRadius: BorderRadius.circular(7)),
            child: Text(label(v), style: TextStyle(
              fontFamily: 'DMSans', fontSize: 13,
              color: active ? elyon.primaryText : elyon.mutedText)),
          ),
        );
      }).toList()),
    );
  }
}

// ── Toggle ────────────────────────────────────────────────────────

class _ElyonToggle extends StatelessWidget {
  const _ElyonToggle({required this.value, required this.onToggle});
  final bool value; final VoidCallback onToggle;
  @override
  Widget build(BuildContext context) {
    final elyon = context.elyon;
    return GestureDetector(
      onTap: onToggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 42, height: 24,
        decoration: BoxDecoration(
          color: value ? AppColors.beige : elyon.surfaceBg,
          border: Border.all(
              color: value ? AppColors.beige : elyon.border2Color),
          borderRadius: BorderRadius.circular(100)),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 200),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.all(3),
            width: 16, height: 16,
            decoration: BoxDecoration(
              color: value ? AppColors.black : elyon.mutedText,
              shape: BoxShape.circle),
          ),
        ),
      ),
    );
  }
}
