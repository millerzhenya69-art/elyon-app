import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../models/user_model.dart';
import '../providers/app_providers.dart';
import '../providers/app_strings.dart';
import '../services/auth_service.dart';
import '../widgets/elyon_logo.dart';
import 'main_screen.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});
  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

enum _AuthTab  { signIn, signUp }
enum _AuthView { form, telegramFlow, verifyEmail }

class _AuthScreenState extends ConsumerState<AuthScreen> {
  _AuthTab  _tab  = _AuthTab.signIn;
  _AuthView _view = _AuthView.form;

  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _fnameCtrl    = TextEditingController();
  final _lnameCtrl    = TextEditingController();

  bool    _loading = false;
  bool    _showPw  = false;
  String? _error;
  String? _verifyEmail;

  @override
  void dispose() {
    _emailCtrl.dispose(); _passwordCtrl.dispose();
    _fnameCtrl.dispose(); _lnameCtrl.dispose();
    super.dispose();
  }

  void _setError(String? e) => setState(() => _error = e);
  void _setLoading(bool v)  => setState(() => _loading = v);

  Future<void> _handleEmailSubmit() async {
    final email    = _emailCtrl.text.trim();
    final password = _passwordCtrl.text.trim();
    final isSignUp = _tab == _AuthTab.signUp;

    if (!email.contains('@') || email.isEmpty) { _setError('Please enter a valid email address.'); return; }
    if (password.length < 8) { _setError('Password must be at least 8 characters.'); return; }
    if (isSignUp && (_fnameCtrl.text.trim().isEmpty || _lnameCtrl.text.trim().isEmpty)) {
      _setError('Please fill in your name.'); return;
    }

    _setError(null); _setLoading(true);
    try {
      final auth = ref.read(authServiceProvider);
      final user = await auth.signInWithEmail(
        email: email, password: password,
        firstName: _fnameCtrl.text.trim(), lastName: _lnameCtrl.text.trim(),
        signUp: isSignUp,
      );
      if (!mounted) return;
      ref.read(userProvider.notifier).setUser(user);
      _goToApp();
    } on AuthException catch (e) {
      if (e.type == AuthErrorType.needsVerification) {
        setState(() { _view = _AuthView.verifyEmail; _verifyEmail = email; });
      } else { _setError(e.message); }
    } catch (_) { _setError('Connection error. Please try again.'); }
    finally { if (mounted) _setLoading(false); }
  }

  Future<void> _handleGoogle() async {
    if (_loading) {
      ref.read(authServiceProvider).cancelGoogleSignIn();
      return;
    }
    _setError(null); _setLoading(true);
    try {
      final auth = ref.read(authServiceProvider);
      final user = await auth.signInWithGoogle();
      if (!mounted) return;
      ref.read(userProvider.notifier).setUser(user);
      _goToApp();
    } on AuthException catch (e) {
      if (mounted) _setError(e.type == AuthErrorType.cancelled ? null : e.message);
    }
    catch (_) { _setError('Google sign-in failed. Please try again.'); }
    finally { if (mounted) _setLoading(false); }
  }

  void _goToApp() {
    Navigator.of(context).pushReplacementNamed('/app');
  }

  @override
  Widget build(BuildContext context) {
    final elyon = context.elyon;
    return Scaffold(
      backgroundColor: elyon.scaffoldBg,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              transitionBuilder: (child, anim) =>
                  FadeTransition(opacity: anim, child: child),
              child: switch (_view) {
                _AuthView.form => _FormView(
                    key: const ValueKey('form'),
                    t: AppStrings.of(ref),
                    tab: _tab, loading: _loading, error: _error, showPw: _showPw,
                    emailCtrl: _emailCtrl, passwordCtrl: _passwordCtrl,
                    fnameCtrl: _fnameCtrl, lnameCtrl: _lnameCtrl,
                    onTabChange: (t) => setState(() { _tab = t; _error = null; }),
                    onSubmit: _handleEmailSubmit, onGoogle: _handleGoogle,
                    onTelegram: () => setState(() { _view = _AuthView.telegramFlow; _error = null; }),
                    onTogglePw: () => setState(() => _showPw = !_showPw),
                  ),
                _AuthView.telegramFlow => _TelegramFlowView(
                    key: const ValueKey('tg'),
                    onSuccess: (AppUser user) {
                      ref.read(userProvider.notifier).setUser(user);
                      _goToApp();
                    },
                    onBack: () => setState(() { _view = _AuthView.form; _error = null; }),
                  ),
                _AuthView.verifyEmail => _VerifyEmailView(
                    key: const ValueKey('verify'),
                    email: _verifyEmail ?? '',
                    onBack: () => setState(() => _view = _AuthView.form),
                  ),
              },
            ),
          ),
        ),
      ),
    );
  }
}

// ── Form view ─────────────────────────────────────────────────────

class _FormView extends StatelessWidget {
  const _FormView({
    super.key, required this.t, required this.tab, required this.loading, required this.error,
    required this.showPw, required this.emailCtrl, required this.passwordCtrl,
    required this.fnameCtrl, required this.lnameCtrl, required this.onTabChange,
    required this.onSubmit, required this.onGoogle, required this.onTelegram,
    required this.onTogglePw,
  });
  final AppStrings t;
  final _AuthTab tab; final bool loading; final String? error; final bool showPw;
  final TextEditingController emailCtrl, passwordCtrl, fnameCtrl, lnameCtrl;
  final void Function(_AuthTab) onTabChange;
  final VoidCallback onSubmit, onGoogle, onTelegram, onTogglePw;

  @override
  Widget build(BuildContext context) {
    final elyon = context.elyon;
    final isSignUp = tab == _AuthTab.signUp;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // ── Logo row: PNG logo (no background) ─────────────────────
      Row(children: [
        const ElyonLogo(size: 32),
        const SizedBox(width: 10),
        Text('Elyon', style: TextStyle(
          fontFamily: 'InstrumentSerif', fontSize: 22, color: elyon.primaryText)),
      ]).animate().fadeIn(duration: 400.ms),
      const SizedBox(height: 36),
      Text(isSignUp ? t.createAccount : t.signIn, style: TextStyle(
        fontFamily: 'InstrumentSerif', fontSize: 30, color: elyon.primaryText,
      )).animate().fadeIn(delay: 50.ms, duration: 400.ms),
      const SizedBox(height: 6),
      Text(
        isSignUp ? t.alreadyHaveAccount : t.newToElyon,
        style: TextStyle(fontSize: 14, fontFamily: 'DMSans',
            color: elyon.mutedText, fontWeight: FontWeight.w300),
      ).animate().fadeIn(delay: 90.ms, duration: 400.ms),
      const SizedBox(height: 28),
      _TabBar(t: t, current: tab, onChange: onTabChange)
          .animate().fadeIn(delay: 120.ms, duration: 400.ms),
      const SizedBox(height: 24),
      // Фикс: кнопка Google — просто большая белая "G", без рамки/кружка/доп. элементов
      _GoogleBtn(loading: loading, onTap: onGoogle),
      const SizedBox(height: 10),
      _SocialBtn(
          icon: Icons.send_rounded,
          label: t.continueWithTelegram, loading: false, onTap: onTelegram),
      const SizedBox(height: 20),
      _OrDivider(t: t),
      const SizedBox(height: 20),
      if (isSignUp) ...[
        Row(children: [
          Expanded(child: _InputField(ctrl: fnameCtrl, hint: t.firstName, label: t.firstName.toUpperCase())),
          const SizedBox(width: 10),
          Expanded(child: _InputField(ctrl: lnameCtrl, hint: t.lastName, label: t.lastName.toUpperCase())),
        ]),
        const SizedBox(height: 14),
      ],
      _InputField(ctrl: emailCtrl, hint: 'you@example.com', label: t.email.toUpperCase(),
          type: TextInputType.emailAddress),
      const SizedBox(height: 14),
      _PasswordField(t: t, ctrl: passwordCtrl, show: showPw, onToggle: onTogglePw),
      const SizedBox(height: 20),
      if (error != null) ...[_ErrorBanner(error!), const SizedBox(height: 12)],
      _SubmitBtn(label: isSignUp ? t.createAccount : t.signIn,
          loading: loading, onTap: onSubmit),
      const SizedBox(height: 20),
      Center(child: Text(
        t.agreeTerms,
        textAlign: TextAlign.center,
        style: TextStyle(fontFamily: 'DMSans', fontSize: 11,
            color: elyon.mutedText, height: 1.6),
      )),
    ]);
  }
}

// ── Telegram flow ─────────────────────────────────────────────────

class _TelegramFlowView extends ConsumerStatefulWidget {
  const _TelegramFlowView({super.key, required this.onSuccess, required this.onBack});
  final void Function(AppUser) onSuccess;
  final VoidCallback onBack;
  @override
  ConsumerState<_TelegramFlowView> createState() => _TelegramFlowViewState();
}

enum _TgStep { intro, waiting, manualPaste }

class _TelegramFlowViewState extends ConsumerState<_TelegramFlowView> {
  _TgStep  _step        = _TgStep.intro;
  bool     _loading     = false;
  String?  _error;
  int      _waitSeconds = 0;
  Timer?   _timer;
  final _tokenCtrl = TextEditingController();

  @override
  void dispose() { _timer?.cancel(); _tokenCtrl.dispose(); super.dispose(); }

  Future<void> _openTelegramAndWait() async {
    setState(() { _step = _TgStep.waiting; _error = null; _waitSeconds = 0; });
    final uri = Uri.parse('https://t.me/Elyon_by_unkony_bot?start=auth');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() => _waitSeconds++);
      if (_waitSeconds >= 30) { t.cancel(); if (mounted) setState(() => _step = _TgStep.manualPaste); }
    });
  }

  Future<void> _submitToken() async {
    final raw = _tokenCtrl.text.trim();
    if (raw.isEmpty) {
      setState(() => _error = AppStrings.of(ref).pleasePasteToken);
      return;
    }
    String token = raw;
    try {
      final uri = Uri.parse(raw);
      if (uri.hasQuery && uri.queryParameters.containsKey('token')) {
        token = uri.queryParameters['token']!;
      }
    } catch (_) {}
    setState(() { _loading = true; _error = null; });
    try {
      final auth = ref.read(authServiceProvider);
      final user = await auth.signInWithTelegramToken(token);
      if (!mounted) return;
      widget.onSuccess(user);
    } on AuthException catch (e) { setState(() => _error = e.message); }
    catch (_) { setState(() => _error = AppStrings.of(ref).connectionErrorRetry); }
    finally { if (mounted) setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    final elyon = context.elyon;
    final t = AppStrings.of(ref);
    return Column(children: [
      const SizedBox(height: 16),
      Container(
        width: 64, height: 64,
        decoration: BoxDecoration(
          color: const Color(0xFF229ED9).withOpacity(0.12),
          border: Border.all(color: const Color(0xFF229ED9).withOpacity(0.25)),
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Center(child: Icon(Icons.send_rounded,
            color: Color(0xFF229ED9), size: 28)),
      ),
      const SizedBox(height: 20),
      Text(t.continueWithTelegramTitle, style: TextStyle(
        fontFamily: 'InstrumentSerif', fontSize: 24, color: elyon.primaryText)),
      const SizedBox(height: 16),
      AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        child: switch (_step) {
          _TgStep.intro       => _TgIntroStep(key: const ValueKey('intro'), t: t, onOpen: _openTelegramAndWait),
          _TgStep.waiting     => _TgWaitingStep(key: const ValueKey('wait'), t: t,
                                    seconds: _waitSeconds,
                                    onManual: () => setState(() => _step = _TgStep.manualPaste)),
          _TgStep.manualPaste => _TgPasteStep(key: const ValueKey('paste'), t: t,
                                    tokenCtrl: _tokenCtrl, loading: _loading, error: _error,
                                    onSubmit: _submitToken, onReopen: _openTelegramAndWait),
        },
      ),
      const SizedBox(height: 24),
      GestureDetector(
        onTap: widget.onBack,
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.arrow_back_rounded, size: 14, color: elyon.mutedText),
          const SizedBox(width: 6),
          Text(t.backToSignIn, style: TextStyle(fontFamily: 'DMSans',
              fontSize: 13, color: elyon.mutedText)),
        ]),
      ),
    ]);
  }
}

class _TgIntroStep extends StatelessWidget {
  const _TgIntroStep({super.key, required this.t, required this.onOpen});
  final AppStrings t;
  final VoidCallback onOpen;
  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.beige.withOpacity(0.04),
          border: Border.all(color: AppColors.beige.withOpacity(0.1)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(children: [
          _Step(n: '1', text: t.tgStep1),
          _Step(n: '2', text: t.tgStep2),
          _Step(n: '3', text: t.tgStep3),
          _Step(n: '4', text: t.tgStep4),
        ]),
      ),
      const SizedBox(height: 20),
      _SubmitBtn(label: t.openTelegramBot, loading: false, onTap: onOpen),
    ]);
  }
}

class _TgWaitingStep extends StatelessWidget {
  const _TgWaitingStep({super.key, required this.t, required this.seconds, required this.onManual});
  final AppStrings t;
  final int seconds;
  final VoidCallback onManual;
  @override
  Widget build(BuildContext context) {
    final elyon = context.elyon;
    return Column(children: [
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.beige.withOpacity(0.05),
          border: Border.all(color: AppColors.beige.withOpacity(0.12)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(children: [
          SizedBox(width: 18, height: 18, child: CircularProgressIndicator(
            strokeWidth: 2, color: AppColors.beige.withOpacity(0.6))),
          const SizedBox(width: 12),
          Expanded(child: Text(
            t.tgWaiting(seconds),
            style: TextStyle(fontFamily: 'DMSans', fontSize: 13,
                color: elyon.primaryText.withOpacity(0.65)),
          )),
        ]),
      ),
      const SizedBox(height: 12),
      GestureDetector(
        onTap: onManual,
        child: Text(t.pasteTokenManually, style: const TextStyle(
          fontFamily: 'DMSans', fontSize: 13, color: AppColors.beige2,
          decoration: TextDecoration.underline, decorationColor: AppColors.beige2,
        )),
      ),
    ]);
  }
}

class _TgPasteStep extends StatelessWidget {
  const _TgPasteStep({super.key, required this.t, required this.tokenCtrl, required this.loading,
    required this.error, required this.onSubmit, required this.onReopen});
  final AppStrings t;
  final TextEditingController tokenCtrl;
  final bool loading; final String? error;
  final VoidCallback onSubmit, onReopen;
  @override
  Widget build(BuildContext context) {
    return Column(children: [
      _InputField(ctrl: tokenCtrl, hint: t.pasteTokenHint, label: t.loginToken),
      const SizedBox(height: 12),
      if (error != null) ...[_ErrorBanner(error!), const SizedBox(height: 12)],
      _SubmitBtn(label: t.verifyToken, loading: loading, onTap: onSubmit),
      const SizedBox(height: 12),
      GestureDetector(
        onTap: onReopen,
        child: const Text('Open bot again', style: TextStyle(
          fontFamily: 'DMSans', fontSize: 13, color: AppColors.beige2,
          decoration: TextDecoration.underline, decorationColor: AppColors.beige2,
        )),
      ),
    ]);
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.n, required this.text});
  final String n, text;
  @override
  Widget build(BuildContext context) {
    final elyon = context.elyon;
    return Padding(padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(width: 20, height: 20,
          decoration: BoxDecoration(color: AppColors.beige.withOpacity(0.12),
              shape: BoxShape.circle),
          child: Center(child: Text(n, style: const TextStyle(
            fontFamily: 'DMSans', fontSize: 11,
            fontWeight: FontWeight.w600, color: AppColors.beige2)))),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: TextStyle(fontFamily: 'DMSans',
            fontSize: 13, height: 1.4, color: elyon.primaryText.withOpacity(0.65)))),
      ]),
    );
  }
}

// ── Verify email view ─────────────────────────────────────────────

class _VerifyEmailView extends ConsumerWidget {
  const _VerifyEmailView({super.key, required this.email, required this.onBack});
  final String email; final VoidCallback onBack;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final elyon = context.elyon;
    final t = AppStrings.of(ref);
    return Column(children: [
      const SizedBox(height: 48),
      Container(width: 64, height: 64,
        decoration: BoxDecoration(color: AppColors.beige.withOpacity(0.07),
          border: Border.all(color: AppColors.beige.withOpacity(0.15)),
          borderRadius: BorderRadius.circular(18)),
        child: const Center(child: Text('✉', style: TextStyle(fontSize: 28)))),
      const SizedBox(height: 24),
      Text(t.checkYourInbox, style: TextStyle(
        fontFamily: 'InstrumentSerif', fontSize: 24, color: elyon.primaryText)),
      const SizedBox(height: 12),
      RichText(textAlign: TextAlign.center, text: TextSpan(children: [
        TextSpan(text: t.verificationLinkSent,
          style: TextStyle(fontFamily: 'DMSans', fontSize: 14,
            color: elyon.mutedText, height: 1.7)),
        TextSpan(text: email, style: const TextStyle(
          fontFamily: 'DMSans', fontSize: 14, color: AppColors.beige, height: 1.7)),
      ])),
      const SizedBox(height: 32),
      GestureDetector(onTap: onBack, child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.arrow_back_rounded, size: 14, color: elyon.mutedText),
        const SizedBox(width: 6),
        Text(t.backToSignIn, style: TextStyle(fontFamily: 'DMSans',
            fontSize: 13, color: elyon.mutedText)),
      ])),
    ]);
  }
}

// ── Shared micro-components ───────────────────────────────────────

class _TabBar extends StatelessWidget {
  const _TabBar({required this.t, required this.current, required this.onChange});
  final AppStrings t;
  final _AuthTab current; final void Function(_AuthTab) onChange;
  @override
  Widget build(BuildContext context) {
    final elyon = context.elyon;
    return Container(padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: elyon.surfaceBg,
        border: Border.all(color: elyon.borderColor), borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        _TabBtn(label: t.signIn, active: current == _AuthTab.signIn,
            onTap: () => onChange(_AuthTab.signIn)),
        const SizedBox(width: 2),
        _TabBtn(label: t.signUp, active: current == _AuthTab.signUp,
            onTap: () => onChange(_AuthTab.signUp)),
      ]));
  }
}

class _TabBtn extends StatelessWidget {
  const _TabBtn({required this.label, required this.active, required this.onTap});
  final String label; final bool active; final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final elyon = context.elyon;
    return Expanded(child: GestureDetector(onTap: onTap,
      child: AnimatedContainer(duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: active ? elyon.card2Bg : Colors.transparent,
          border: Border.all(color: active ? elyon.border2Color : Colors.transparent),
          borderRadius: BorderRadius.circular(8)),
        child: Center(child: Text(label, style: TextStyle(fontFamily: 'DMSans',
          fontSize: 13, fontWeight: FontWeight.w500,
          color: active ? elyon.primaryText : elyon.mutedText))))));
  }
}

class _SocialBtn extends StatefulWidget {
  const _SocialBtn({
    this.icon,
    this.iconWidget,
    required this.label,
    required this.loading,
    required this.onTap,
  });
  final IconData? icon;
  final Widget? iconWidget;
  final String label;
  final bool loading;
  final VoidCallback onTap;
  @override State<_SocialBtn> createState() => _SocialBtnState();
}
class _SocialBtnState extends State<_SocialBtn> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final elyon = context.elyon;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit:  (_) => setState(() => _hover = false),
      child: GestureDetector(onTap: widget.loading ? null : widget.onTap,
        child: AnimatedContainer(duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
          decoration: BoxDecoration(
            color: _hover ? elyon.cardBg : elyon.surfaceBg,
            border: Border.all(color: _hover ? elyon.border2Color : elyon.borderColor),
            borderRadius: BorderRadius.circular(12)),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            widget.loading
                ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(
                    strokeWidth: 2, color: elyon.mutedText))
                : (widget.iconWidget ??
                    Icon(widget.icon, size: 18,
                        color: elyon.primaryText.withOpacity(0.8))),
            const SizedBox(width: 10),
            Text(widget.label, style: TextStyle(fontFamily: 'DMSans',
                fontSize: 14, color: elyon.primaryText.withOpacity(0.9))),
          ]))));
  }
}

// ── Фикс: кнопка Google — только большая белая "G", без рамки/кружка/текста ──

class _GoogleBtn extends StatefulWidget {
  const _GoogleBtn({required this.loading, required this.onTap});
  final bool loading;
  final VoidCallback onTap;
  @override
  State<_GoogleBtn> createState() => _GoogleBtnState();
}

class _GoogleBtnState extends State<_GoogleBtn> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final elyon = context.elyon;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit:  (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.loading ? null : widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(
            color: _hover ? elyon.cardBg : elyon.surfaceBg,
            border: Border.all(color: _hover ? elyon.border2Color : elyon.borderColor),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: widget.loading
                ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(
                    strokeWidth: 2, color: elyon.mutedText))
                : const Text(
                    'G',
                    style: TextStyle(
                      fontFamily: 'DMSans',
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      height: 1,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _OrDivider extends StatelessWidget {
  const _OrDivider({required this.t});
  final AppStrings t;
  @override
  Widget build(BuildContext context) {
    final elyon = context.elyon;
    return Row(children: [
      Expanded(child: Divider(color: elyon.borderColor, thickness: 1)),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Text(t.orContinueWithEmail, style: TextStyle(fontFamily: 'DMSans',
            fontSize: 12, color: elyon.primaryText.withOpacity(0.35)))),
      Expanded(child: Divider(color: elyon.borderColor, thickness: 1)),
    ]);
  }
}

class _InputField extends StatelessWidget {
  const _InputField({required this.ctrl, required this.hint, required this.label, this.type});
  final TextEditingController ctrl; final String hint, label; final TextInputType? type;
  @override
  Widget build(BuildContext context) {
    final elyon = context.elyon;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label.toUpperCase(), style: const TextStyle(fontFamily: 'DMSans',
        fontSize: 11, fontWeight: FontWeight.w500, letterSpacing: 0.5, color: AppColors.beige2)),
      const SizedBox(height: 7),
      TextField(controller: ctrl, keyboardType: type,
        style: TextStyle(fontFamily: 'DMSans', fontSize: 14, color: elyon.primaryText),
        decoration: InputDecoration(hintText: hint, filled: true, fillColor: elyon.surfaceBg,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: elyon.borderColor)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: elyon.border2Color)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: AppColors.beige.withOpacity(0.35))),
          hintStyle: TextStyle(fontFamily: 'DMSans', fontSize: 14,
              color: elyon.primaryText.withOpacity(0.25)))),
    ]);
  }
}

class _PasswordField extends StatelessWidget {
  const _PasswordField({required this.t, required this.ctrl, required this.show, required this.onToggle});
  final AppStrings t;
  final TextEditingController ctrl; final bool show; final VoidCallback onToggle;
  @override
  Widget build(BuildContext context) {
    final elyon = context.elyon;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(t.password.toUpperCase(), style: const TextStyle(fontFamily: 'DMSans', fontSize: 11,
        fontWeight: FontWeight.w500, letterSpacing: 0.5, color: AppColors.beige2)),
      const SizedBox(height: 7),
      TextField(controller: ctrl, obscureText: !show,
        style: TextStyle(fontFamily: 'DMSans', fontSize: 14, color: elyon.primaryText),
        decoration: InputDecoration(hintText: '••••••••', filled: true, fillColor: elyon.surfaceBg,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: elyon.borderColor)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: elyon.border2Color)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: AppColors.beige.withOpacity(0.35))),
          hintStyle: TextStyle(fontFamily: 'DMSans', fontSize: 14,
              color: elyon.primaryText.withOpacity(0.25)),
          suffixIcon: GestureDetector(onTap: onToggle,
            child: Icon(show ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                size: 18, color: elyon.primaryText.withOpacity(0.4))))),
    ]);
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner(this.message);
  final String message;
  @override
  Widget build(BuildContext context) {
    return Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: AppColors.danger.withOpacity(0.08),
        border: Border.all(color: AppColors.danger.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(10)),
      child: Row(children: [
        const Icon(Icons.error_outline_rounded, size: 15, color: AppColors.danger),
        const SizedBox(width: 8),
        Expanded(child: Text(message, style: const TextStyle(
          fontFamily: 'DMSans', fontSize: 13, color: AppColors.danger))),
      ]));
  }
}

class _SubmitBtn extends StatefulWidget {
  const _SubmitBtn({required this.label, required this.loading, required this.onTap});
  final String label; final bool loading; final VoidCallback onTap;
  @override State<_SubmitBtn> createState() => _SubmitBtnState();
}
class _SubmitBtnState extends State<_SubmitBtn> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    return SizedBox(width: double.infinity,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit:  (_) => setState(() => _hover = false),
        child: GestureDetector(onTap: widget.loading ? null : widget.onTap,
          child: AnimatedContainer(duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: widget.loading ? AppColors.beige.withOpacity(0.5)
                  : (_hover ? AppColors.white : AppColors.beige),
              borderRadius: BorderRadius.circular(12)),
            child: Center(child: widget.loading
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppColors.black))
              : Text(widget.label, style: const TextStyle(fontFamily: 'DMSans',
                  fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.black)))))));
  }
}
