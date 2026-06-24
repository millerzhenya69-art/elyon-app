import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../providers/app_providers.dart';
import '../services/admin_service.dart';

/// Admin panel — mirrors the web app.html #panel-admin functionality.
/// Stats overview + user list + give/remove subscription + API key health.
class AdminPanelScreen extends ConsumerStatefulWidget {
  const AdminPanelScreen({super.key, required this.onBack});
  final VoidCallback onBack;

  @override
  ConsumerState<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends ConsumerState<AdminPanelScreen> {
  final _admin = AdminService();

  AdminStats? _stats;
  List<AdminUserRow>? _users;
  Map<String, List<AdminKeyStatus>>? _keyStatus;

  bool _loadingStats = true;
  bool _loadingUsers = false;
  bool _loadingKeys  = false;
  String? _statsError;

  final _targetCtrl = TextEditingController(text: '');
  final _daysCtrl   = TextEditingController(text: '30');
  String _tier      = 'nova';
  String? _subResultMsg;
  Color  _subResultColor = AppColors.beige2;
  bool   _subBusy = false;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  @override
  void dispose() {
    _admin.dispose();
    _targetCtrl.dispose();
    _daysCtrl.dispose();
    super.dispose();
  }

  String get _adminId => ref.read(userProvider)?.id ?? '';

  Future<void> _loadStats() async {
    setState(() { _loadingStats = true; _statsError = null; });
    try {
      final stats = await _admin.fetchStats();
      if (!mounted) return;
      setState(() { _stats = stats; _loadingStats = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _statsError = e.toString(); _loadingStats = false; });
    }
  }

  Future<void> _loadUsers() async {
    setState(() => _loadingUsers = true);
    try {
      final users = await _admin.fetchUsers();
      if (!mounted) return;
      setState(() { _users = users; _loadingUsers = false; });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingUsers = false);
    }
  }

  Future<void> _testKeys() async {
    setState(() => _loadingKeys = true);
    try {
      final keys = await _admin.testKeys(_adminId);
      if (!mounted) return;
      setState(() { _keyStatus = keys; _loadingKeys = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingKeys = false);
      _showSnack(e.toString(), isError: true);
    }
  }

  Future<void> _giveSub() async {
    final target = _targetCtrl.text.trim();
    if (target.isEmpty) {
      setState(() { _subResultMsg = 'Enter username or email'; _subResultColor = const Color(0xFFFBBF24); });
      return;
    }
    final days = int.tryParse(_daysCtrl.text.trim()) ?? 30;
    setState(() { _subBusy = true; _subResultMsg = 'Processing...'; _subResultColor = AppColors.beige2; });
    try {
      final until = await _admin.giveSub(
        adminId: _adminId, target: target, tier: _tier, days: days,
      );
      if (!mounted) return;
      setState(() {
        _subResultMsg   = '✅ Done! $target → ${_tier.toUpperCase()} until $until';
        _subResultColor = const Color(0xFF4ADE80);
        _subBusy = false;
      });
      _loadStats();
    } on AdminException catch (e) {
      if (!mounted) return;
      setState(() { _subResultMsg = '❌ ${e.message}'; _subResultColor = const Color(0xFFF87171); _subBusy = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _subResultMsg = '❌ $e'; _subResultColor = const Color(0xFFF87171); _subBusy = false; });
    }
  }

  Future<void> _removeSub() async {
    final target = _targetCtrl.text.trim();
    if (target.isEmpty) {
      setState(() { _subResultMsg = 'Enter username or email'; _subResultColor = const Color(0xFFFBBF24); });
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove subscription?'),
        content: Text('Remove subscription from $target?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true),  child: const Text('Remove')),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() { _subBusy = true; _subResultMsg = 'Processing...'; _subResultColor = AppColors.beige2; });
    try {
      await _admin.removeSub(adminId: _adminId, target: target);
      if (!mounted) return;
      setState(() {
        _subResultMsg   = '✅ Removed from $target';
        _subResultColor = const Color(0xFF4ADE80);
        _subBusy = false;
      });
      _loadStats();
    } on AdminException catch (e) {
      if (!mounted) return;
      setState(() { _subResultMsg = '❌ ${e.message}'; _subResultColor = const Color(0xFFF87171); _subBusy = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _subResultMsg = '❌ $e'; _subResultColor = const Color(0xFFF87171); _subBusy = false; });
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? AppColors.danger : null,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final elyon = context.elyon;

    return Container(
      color: elyon.scaffoldBg,
      child: Column(
        children: [
          _Header(onBack: widget.onBack, onRefresh: _loadStats),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _StatsGrid(stats: _stats, loading: _loadingStats, error: _statsError),
                    const SizedBox(height: 24),

                    _SectionLabel('Actions'),
                    const SizedBox(height: 10),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      _AdminBtn(label: '👥 Users', onTap: _loadUsers, busy: _loadingUsers),
                      _AdminBtn(label: '🔄 Refresh', onTap: _loadStats, busy: _loadingStats),
                      _AdminBtn(label: '🔑 Test Keys', onTap: _testKeys, busy: _loadingKeys),
                    ]),

                    if (_users != null) ...[
                      const SizedBox(height: 20),
                      _UserList(users: _users!),
                    ],

                    const SizedBox(height: 28),
                    _SectionLabel('Give / Remove Subscription'),
                    const SizedBox(height: 10),
                    _SubscriptionManager(
                      targetCtrl: _targetCtrl,
                      daysCtrl:   _daysCtrl,
                      tier:       _tier,
                      onTierChange: (v) => setState(() => _tier = v),
                      onGive:   _giveSub,
                      onRemove: _removeSub,
                      busy:     _subBusy,
                      resultMsg:   _subResultMsg,
                      resultColor: _subResultColor,
                    ),

                    const SizedBox(height: 28),
                    _SectionLabel('API Keys Status'),
                    const SizedBox(height: 10),
                    _KeysStatusPanel(
                      keyStatus: _keyStatus,
                      loading:   _loadingKeys,
                      onTest:    _testKeys,
                    ),
                    const SizedBox(height: 24),
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

// ── Header ──────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({required this.onBack, required this.onRefresh});
  final VoidCallback onBack;
  final VoidCallback onRefresh;
  @override
  Widget build(BuildContext context) {
    final elyon = context.elyon;
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: elyon.borderColor))),
      child: Row(children: [
        GestureDetector(onTap: onBack,
          child: Icon(Icons.arrow_back_rounded, color: elyon.mutedText, size: 20)),
        const SizedBox(width: 12),
        Text('Admin Panel', style: TextStyle(
          fontFamily: 'InstrumentSerif', fontSize: 20, color: elyon.primaryText)),
        const Spacer(),
        GestureDetector(
          onTap: onRefresh,
          child: Icon(Icons.refresh_rounded, color: elyon.mutedText, size: 20),
        ),
      ]),
    );
  }
}

// ── Stats grid ──────────────────────────────────────────────────

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.stats, required this.loading, required this.error});
  final AdminStats? stats;
  final bool loading;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final elyon = context.elyon;
    if (loading) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 28),
        child: Center(child: Text('Loading...', style: TextStyle(
          fontFamily: 'DMSans', fontSize: 13, color: elyon.mutedText))),
      );
    }
    if (error != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 28),
        child: Center(child: Text('Server may be sleeping. Try again.', style: TextStyle(
          fontFamily: 'DMSans', fontSize: 13, color: elyon.mutedText))),
      );
    }
    if (stats == null) return const SizedBox.shrink();

    final items = [
      ('Total users',  stats!.totalUsers),
      ('Active subs',  stats!.activeSubs),
      ('New today',    stats!.newToday),
      ('Messages',     stats!.totalMessages),
      ('Payments',     stats!.totalPayments),
      ('Web users',    stats!.miniappUsers),
    ];

    return Wrap(
      spacing: 9, runSpacing: 9,
      children: items.map((item) => Container(
        width: 140,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: elyon.surfaceBg,
          border: Border.all(color: elyon.borderColor),
          borderRadius: BorderRadius.circular(11),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${item.$2}', style: const TextStyle(
            fontFamily: 'InstrumentSerif', fontSize: 26, color: AppColors.beige, height: 1)),
          const SizedBox(height: 3),
          Text(item.$1.toUpperCase(), style: TextStyle(
            fontFamily: 'DMSans', fontSize: 10, letterSpacing: 0.6, color: elyon.mutedText)),
        ]),
      )).toList(),
    );
  }
}

// ── User list ───────────────────────────────────────────────────

class _UserList extends StatelessWidget {
  const _UserList({required this.users});
  final List<AdminUserRow> users;
  @override
  Widget build(BuildContext context) {
    final elyon = context.elyon;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _SectionLabel('Users (${users.length})'),
      const SizedBox(height: 9),
      Container(
        constraints: const BoxConstraints(maxHeight: 320),
        child: ListView.separated(
          shrinkWrap: true,
          itemCount: users.length,
          separatorBuilder: (_, __) => const SizedBox(height: 5),
          itemBuilder: (ctx, i) {
            final u = users[i];
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
              decoration: BoxDecoration(
                color: elyon.surfaceBg,
                border: Border.all(color: elyon.borderColor),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Row(children: [
                Container(
                  width: 26, height: 26,
                  decoration: BoxDecoration(
                    color: AppColors.beige.withOpacity(0.12), shape: BoxShape.circle),
                  child: Center(child: Text(
                    u.username.isNotEmpty ? u.username[0].toUpperCase() : '?',
                    style: const TextStyle(fontFamily: 'DMSans', fontSize: 11,
                      fontWeight: FontWeight.w600, color: AppColors.beige))),
                ),
                const SizedBox(width: 11),
                Expanded(child: Text(
                  u.username.isNotEmpty ? '@${u.username}' : 'ID:${u.userId}',
                  style: TextStyle(fontFamily: 'DMSans', fontSize: 12, color: elyon.primaryText))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.beige.withOpacity(0.08), borderRadius: BorderRadius.circular(100)),
                  child: Text(u.role, style: const TextStyle(
                    fontFamily: 'DMSans', fontSize: 10, color: AppColors.beige2)),
                ),
                if (u.subType != 'none') ...[
                  const SizedBox(width: 7),
                  Text('⭐ ${u.subType}', style: TextStyle(
                    fontFamily: 'DMSans', fontSize: 10, color: elyon.mutedText)),
                ],
              ]),
            );
          },
        ),
      ),
    ]);
  }
}

// ── Subscription manager ───────────────────────────────────────

class _SubscriptionManager extends StatelessWidget {
  const _SubscriptionManager({
    required this.targetCtrl, required this.daysCtrl, required this.tier,
    required this.onTierChange, required this.onGive, required this.onRemove,
    required this.busy, required this.resultMsg, required this.resultColor,
  });
  final TextEditingController targetCtrl, daysCtrl;
  final String tier;
  final void Function(String) onTierChange;
  final VoidCallback onGive, onRemove;
  final bool busy;
  final String? resultMsg;
  final Color resultColor;

  @override
  Widget build(BuildContext context) {
    final elyon = context.elyon;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: elyon.surfaceBg,
        border: Border.all(color: elyon.borderColor),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: 7, runSpacing: 7, children: [
          SizedBox(
            width: 220,
            child: _SmallField(controller: targetCtrl, hint: '@username or email'),
          ),
          SizedBox(
            width: 130,
            child: _TierDropdown(value: tier, onChange: onTierChange),
          ),
          SizedBox(
            width: 80,
            child: _SmallField(controller: daysCtrl, hint: 'Days', isNumber: true),
          ),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          _SmallBtn(
            label: '✅ Give Sub', color: const Color(0xFF4ADE80),
            onTap: busy ? null : onGive,
          ),
          const SizedBox(width: 7),
          _SmallBtn(
            label: '❌ Remove Sub', color: AppColors.danger,
            onTap: busy ? null : onRemove,
          ),
        ]),
        if (resultMsg != null) ...[
          const SizedBox(height: 8),
          Text(resultMsg!, style: TextStyle(fontFamily: 'DMSans', fontSize: 11, color: resultColor)),
        ],
      ]),
    );
  }
}

class _SmallField extends StatelessWidget {
  const _SmallField({required this.controller, required this.hint, this.isNumber = false});
  final TextEditingController controller;
  final String hint;
  final bool isNumber;
  @override
  Widget build(BuildContext context) {
    final elyon = context.elyon;
    return TextField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      style: TextStyle(fontFamily: 'DMSans', fontSize: 13, color: elyon.primaryText),
      decoration: InputDecoration(
        hintText: hint,
        isDense: true,
        filled: true,
        fillColor: elyon.card2Bg,
        contentPadding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: elyon.border2Color)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: elyon.border2Color)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppColors.beige.withOpacity(0.4))),
        hintStyle: TextStyle(fontFamily: 'DMSans', fontSize: 13, color: elyon.mutedText),
      ),
    );
  }
}

class _TierDropdown extends StatelessWidget {
  const _TierDropdown({required this.value, required this.onChange});
  final String value;
  final void Function(String) onChange;
  @override
  Widget build(BuildContext context) {
    final elyon = context.elyon;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11),
      decoration: BoxDecoration(
        color: elyon.card2Bg,
        border: Border.all(color: elyon.border2Color),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isDense: true,
          isExpanded: true,
          dropdownColor: elyon.cardBg,
          style: TextStyle(fontFamily: 'DMSans', fontSize: 13, color: elyon.primaryText),
          items: const [
            DropdownMenuItem(value: 'nova',       child: Text('Nova')),
            DropdownMenuItem(value: 'pro',        child: Text('PRO')),
            DropdownMenuItem(value: 'absolution', child: Text('Absolution')),
          ],
          onChanged: (v) { if (v != null) onChange(v); },
        ),
      ),
    );
  }
}

class _SmallBtn extends StatefulWidget {
  const _SmallBtn({required this.label, required this.color, required this.onTap});
  final String label; final Color color; final VoidCallback? onTap;
  @override
  State<_SmallBtn> createState() => _SmallBtnState();
}
class _SmallBtnState extends State<_SmallBtn> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit:  (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
          decoration: BoxDecoration(
            color: widget.color.withOpacity(_hover ? 0.16 : 0.10),
            border: Border.all(color: widget.color.withOpacity(0.3)),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Text(widget.label, style: TextStyle(
            fontFamily: 'DMSans', fontSize: 12, color: widget.color)),
        ),
      ),
    );
  }
}

// ── Keys status panel ──────────────────────────────────────────

class _KeysStatusPanel extends StatelessWidget {
  const _KeysStatusPanel({required this.keyStatus, required this.loading, required this.onTest});
  final Map<String, List<AdminKeyStatus>>? keyStatus;
  final bool loading;
  final VoidCallback onTest;

  static const _labels = {
    'core_flash': 'Core', 'nova_flash': 'Nova', 'pro': 'PRO', 'absolution': 'Absolution',
  };

  @override
  Widget build(BuildContext context) {
    final elyon = context.elyon;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: elyon.surfaceBg,
        border: Border.all(color: elyon.borderColor),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _AdminBtn(label: '🔑 Test All Keys', onTap: onTest, busy: loading),
        if (keyStatus != null) ...[
          const SizedBox(height: 10),
          ...keyStatus!.entries.map((e) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_labels[e.key] ?? e.key, style: TextStyle(
                fontFamily: 'DMSans', fontSize: 12, fontWeight: FontWeight.w600,
                color: elyon.primaryText)),
              const SizedBox(height: 4),
              ...e.value.map((k) => Padding(
                padding: const EdgeInsets.only(left: 8, bottom: 2),
                child: Text(
                  '${k.isOk ? "✅" : k.isExhausted ? "🔴" : "⚠️"} ${k.keyPreview} — ${k.status}',
                  style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: elyon.mutedText),
                ),
              )),
            ]),
          )),
        ],
      ]),
    );
  }
}

// ── Shared ──────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: const TextStyle(fontFamily: 'DMSans', fontSize: 11, fontWeight: FontWeight.w500,
      letterSpacing: 1.2, color: AppColors.beige2),
  );
}

class _AdminBtn extends StatefulWidget {
  const _AdminBtn({required this.label, required this.onTap, this.busy = false});
  final String label; final VoidCallback onTap; final bool busy;
  @override
  State<_AdminBtn> createState() => _AdminBtnState();
}
class _AdminBtnState extends State<_AdminBtn> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final elyon = context.elyon;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit:  (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.busy ? null : widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: _hover ? elyon.card2Bg : Colors.transparent,
            border: Border.all(color: elyon.border2Color),
            borderRadius: BorderRadius.circular(9),
          ),
          child: widget.busy
            ? SizedBox(width: 14, height: 14, child: CircularProgressIndicator(
                strokeWidth: 2, color: elyon.mutedText))
            : Text(widget.label, style: TextStyle(
                fontFamily: 'DMSans', fontSize: 12, color: elyon.primaryText)),
        ),
      ),
    );
  }
}
