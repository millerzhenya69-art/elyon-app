import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

/// Resolves hostnames via DNS-over-HTTPS (Cloudflare 1.1.1.1, hardcoded IP —
/// no DNS lookup needed to reach it) before connecting, instead of relying on
/// the OS/carrier resolver.
///
/// Root cause this works around: on some mobile carriers, `elyon-ai-web.vercel.app`
/// fails to resolve at all — "Failed host lookup ... No address associated
/// with hostname, errno = 7" — confirmed via logcat on a real device (2026-07-31).
/// This is a DNS-level block on the carrier side (Vercel's shared IP ranges
/// are commonly blocked by some RU carriers due to other sites hosted on the
/// same CDN), not a code bug or a flaky/transient failure — the resolver
/// answers immediately with "no address", so retries never help. The same
/// domain resolves fine on Wi-Fi / other ISPs (confirmed working on desktop).
///
/// Cloudflare's 1.1.1.1 cert includes the literal IP as a SAN, so connecting
/// to "https://1.1.1.1/dns-query" needs no DNS itself. If DoH also fails
/// (offline, DoH endpoint blocked too, etc.) this falls back to the normal
/// system resolver, so behaviour is never worse than before.
class DohResolver {
  DohResolver._();

  static final Map<String, _CacheEntry> _cache = {};

  static Future<InternetAddress?> resolve(String host) async {
    final cached = _cache[host];
    if (cached != null && DateTime.now().isBefore(cached.expiresAt)) {
      return cached.address;
    }
    final ip = await _queryCloudflare(host);
    if (ip != null) {
      _cache[host] = _CacheEntry(ip, DateTime.now().add(const Duration(minutes: 10)));
    }
    return ip;
  }

  static Future<InternetAddress?> _queryCloudflare(String host) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
    try {
      final uri = Uri.parse('https://1.1.1.1/dns-query?name=$host&type=A');
      final req = await client.getUrl(uri).timeout(const Duration(seconds: 5));
      req.headers.set('accept', 'application/dns-json');
      final res = await req.close().timeout(const Duration(seconds: 5));
      final body = await res.transform(utf8.decoder).join();
      final json = jsonDecode(body) as Map<String, dynamic>;
      final answers = (json['Answer'] as List<dynamic>?) ?? const [];
      for (final a in answers) {
        final m = a as Map<String, dynamic>;
        if (m['type'] == 1) {
          // type 1 = A record
          return InternetAddress(m['data'] as String);
        }
      }
      return null;
    } catch (e) {
      debugPrint('[ElyonNet] DoH lookup failed for $host: $e');
      return null;
    } finally {
      client.close(force: true);
    }
  }
}

class _CacheEntry {
  _CacheEntry(this.address, this.expiresAt);
  final InternetAddress address;
  final DateTime expiresAt;
}

/// http.Client that resolves via [DohResolver] first, falling back to the
/// normal system resolver if DoH fails for any reason. TLS SNI + the Host
/// header still use the original hostname (dart:io's HttpClient passes
/// `uri.host` — not the resolved IP — into SecureSocket.secure), so this is
/// transparent to the server: Vercel/HF still see the right hostname.
class DohHttpClient extends IOClient {
  DohHttpClient() : super(_buildClient());

  static HttpClient _buildClient() {
    final client = HttpClient();
    client.connectionFactory = (Uri uri, String? proxyHost, int? proxyPort) async {
      InternetAddress target;
      final dohIp = await DohResolver.resolve(uri.host);
      if (dohIp != null) {
        target = dohIp;
      } else {
        final looked = await InternetAddress.lookup(uri.host);
        if (looked.isEmpty) {
          throw SocketException('Failed host lookup (DoH + system both failed): ${uri.host}');
        }
        target = looked.first;
      }
      final socket = await Socket.connect(target, uri.port,
          timeout: const Duration(seconds: 15));
      return ConnectionTask.fromSocket(socket, () => socket.destroy());
    };
    return client;
  }
}
