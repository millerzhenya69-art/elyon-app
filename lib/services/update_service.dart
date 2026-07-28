import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'retry_http_client.dart';

const String _kBaseUrl = 'https://elyon-ai-web.vercel.app/api/relay';

/// Bump this on every release — must match the version actually built
/// and uploaded to downloads/. Kept as a plain constant (no package_info_plus
/// dependency) to keep this check dependency-free.
const String kAppVersion = '1.0.0';

class UpdateInfo {
  const UpdateInfo({required this.version, required this.downloadUrl});
  final String version;
  final String downloadUrl;
}

class UpdateService {
  UpdateService({http.Client? client}) : _client = client ?? RetryHttpClient();
  final http.Client _client;

  String get _platformKey {
    if (Platform.isWindows) return 'windows';
    if (Platform.isLinux) return 'linux';
    if (Platform.isMacOS) return 'macos';
    if (Platform.isAndroid) {
      // Best-effort: arm64 is the modern default; the app doesn't currently
      // detect ABI at runtime, so arm64 is assumed. Users on very old
      // devices can still grab arm32 manually from the website.
      return 'android_arm64';
    }
    return 'unknown';
  }

  /// Returns non-null only if a newer version is available.
  Future<UpdateInfo?> checkForUpdate() async {
    try {
      final response = await _client
          .get(Uri.parse('$_kBaseUrl/api/app_version'))
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final latest = data['version'] as String? ?? kAppVersion;
      final urls = data['urls'] as Map<String, dynamic>? ?? {};
      final url = urls[_platformKey] as String?;

      if (url == null || !_isNewer(latest, kAppVersion)) return null;
      return UpdateInfo(version: latest, downloadUrl: url);
    } catch (_) {
      // Silent failure — update checks must never block or crash the app.
      return null;
    }
  }

  /// Simple semver-ish comparison ("1.2.0" > "1.10.0" bugs aside — fine for
  /// our small, manually-bumped version numbers).
  bool _isNewer(String remote, String local) {
    final r = remote.split('.').map((p) => int.tryParse(p) ?? 0).toList();
    final l = local.split('.').map((p) => int.tryParse(p) ?? 0).toList();
    for (var i = 0; i < r.length || i < l.length; i++) {
      final rv = i < r.length ? r[i] : 0;
      final lv = i < l.length ? l[i] : 0;
      if (rv != lv) return rv > lv;
    }
    return false;
  }

  void dispose() => _client.close();
}
