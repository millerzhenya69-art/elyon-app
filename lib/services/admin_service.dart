import 'dart:convert';
import 'package:http/http.dart' as http;

const String _kBaseUrl = 'https://elyon-bot.onrender.com';

/// Stats shown at the top of the admin panel.
class AdminStats {
  const AdminStats({
    required this.totalUsers,
    required this.activeSubs,
    required this.newToday,
    required this.totalMessages,
    required this.totalPayments,
    required this.miniappUsers,
    required this.freeUsers,
    required this.proUsers,
    required this.roles,
  });

  final int totalUsers;
  final int activeSubs;
  final int newToday;
  final int totalMessages;
  final int totalPayments;
  final int miniappUsers;
  final int freeUsers;
  final int proUsers;
  final Map<String, int> roles;

  factory AdminStats.fromJson(Map<String, dynamic> j) => AdminStats(
        totalUsers:    (j['total_users']    as num?)?.toInt() ?? 0,
        activeSubs:    (j['active_subs']    as num?)?.toInt() ?? 0,
        newToday:      (j['new_today']      as num?)?.toInt() ?? 0,
        totalMessages: (j['total_messages'] as num?)?.toInt() ?? 0,
        totalPayments: (j['total_payments'] as num?)?.toInt() ?? 0,
        miniappUsers:  (j['miniapp_users']  as num?)?.toInt() ?? 0,
        freeUsers:     (j['free_users']     as num?)?.toInt() ?? 0,
        proUsers:      (j['pro_users']      as num?)?.toInt() ?? 0,
        roles: (j['roles'] as Map<String, dynamic>? ?? {})
            .map((k, v) => MapEntry(k, (v as num).toInt())),
      );
}

/// A single user row in the admin user list.
class AdminUserRow {
  const AdminUserRow({
    required this.userId,
    required this.username,
    required this.role,
    required this.subType,
    required this.balance,
  });

  final int userId;
  final String username;
  final String role;
  final String subType;
  final int balance;

  factory AdminUserRow.fromJson(Map<String, dynamic> j) => AdminUserRow(
        userId:   (j['user_id'] as num).toInt(),
        username: j['username']?.toString() ?? '',
        role:     j['role']?.toString() ?? 'default user',
        subType:  j['sub_type']?.toString() ?? 'none',
        balance:  (j['balance'] as num?)?.toInt() ?? 0,
      );
}

/// API key health-check entry.
class AdminKeyStatus {
  const AdminKeyStatus({required this.keyPreview, required this.status});
  final String keyPreview;
  final String status;

  bool get isOk        => status == 'ok';
  bool get isExhausted => status.contains('exhausted') || status.contains('invalid');

  factory AdminKeyStatus.fromJson(Map<String, dynamic> j) => AdminKeyStatus(
        keyPreview: j['key']?.toString() ?? '?',
        status:     j['status']?.toString() ?? 'unknown',
      );
}

class AdminException implements Exception {
  const AdminException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Talks to the bot.py Flask admin endpoints. Every call requires
/// X-Admin-Id header matching OWNER_ID on the backend.
class AdminService {
  AdminService({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;

  Map<String, String> _headers(String adminId) => {
        'Content-Type': 'application/json',
        'X-Admin-Id':   adminId,
      };

  Future<AdminStats> fetchStats() async {
    final res = await _client
        .get(Uri.parse('$_kBaseUrl/api/admin/stats'))
        .timeout(const Duration(seconds: 20));
    if (res.statusCode != 200) {
      throw AdminException('Server error ${res.statusCode}');
    }
    return AdminStats.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<List<AdminUserRow>> fetchUsers() async {
    final res = await _client
        .get(Uri.parse('$_kBaseUrl/api/admin/users'))
        .timeout(const Duration(seconds: 20));
    if (res.statusCode != 200) {
      throw AdminException('Server error ${res.statusCode}');
    }
    final data  = jsonDecode(res.body) as Map<String, dynamic>;
    final users = (data['users'] as List<dynamic>? ?? []);
    return users
        .map((u) => AdminUserRow.fromJson(u as Map<String, dynamic>))
        .toList();
  }

  /// tier: 'nova' | 'pro' | 'absolution'
  Future<String> giveSub({
    required String adminId,
    required String target,
    required String tier,
    required int days,
  }) async {
    final res = await _client
        .post(
          Uri.parse('$_kBaseUrl/api/admin/give_sub'),
          headers: _headers(adminId),
          body: jsonEncode({'target': target, 'tier': tier, 'days': days}),
        )
        .timeout(const Duration(seconds: 20));
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (data['ok'] != true) {
      throw AdminException(data['error']?.toString() ?? 'Failed to give subscription');
    }
    return data['until']?.toString() ?? '';
  }

  Future<void> removeSub({
    required String adminId,
    required String target,
  }) async {
    final res = await _client
        .post(
          Uri.parse('$_kBaseUrl/api/admin/remove_sub'),
          headers: _headers(adminId),
          body: jsonEncode({'target': target}),
        )
        .timeout(const Duration(seconds: 20));
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (data['ok'] != true) {
      throw AdminException(data['error']?.toString() ?? 'Failed to remove subscription');
    }
  }

  Future<Map<String, List<AdminKeyStatus>>> testKeys(String adminId) async {
    final res = await _client
        .get(
          Uri.parse('$_kBaseUrl/api/admin/test_keys'),
          headers: _headers(adminId),
        )
        .timeout(const Duration(seconds: 60));
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (data['ok'] != true) {
      throw AdminException(data['error']?.toString() ?? 'Failed to test keys');
    }
    final keys = data['keys'] as Map<String, dynamic>? ?? {};
    return keys.map((tier, list) => MapEntry(
          tier,
          (list as List<dynamic>)
              .map((k) => AdminKeyStatus.fromJson(k as Map<String, dynamic>))
              .toList(),
        ));
  }

  void dispose() => _client.close();
}
