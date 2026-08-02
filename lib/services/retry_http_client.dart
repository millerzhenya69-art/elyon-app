import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'doh_http_client.dart';

/// Wraps an [http.Client] and automatically retries requests that fail with
/// a transient network-level error (SocketException, connection reset, etc).
///
/// Uses a plain system [http.Client] by default — identical to what curl/the
/// desktop builds use, which is known-good (verified directly against the
/// server on 2026-08-02). [DohHttpClient] (custom connectionFactory, raw
/// socket + manual TLS) is kept only as a fallback for a *confirmed* DNS
/// block ("Failed host lookup ... errno = 7", seen on at least one mobile
/// carrier on 2026-07-31) — it is NOT used as the default path any more,
/// because routing every request through it turned out to trigger an
/// unrelated 308 from Vercel that the plain client never produces (root
/// cause not fully understood, likely an ALPN/protocol quirk from manually
/// wrapping the socket in TLS instead of letting HttpClient negotiate it).
class RetryHttpClient extends http.BaseClient {
  RetryHttpClient({http.Client? inner, http.Client? dohFallback, this.maxAttempts = 3})
      : _inner = inner ?? http.Client(),
        _dohFallback = dohFallback ?? DohHttpClient();

  final http.Client _inner;
  final http.Client _dohFallback;
  final int maxAttempts;

  static const _delays = [
    Duration(milliseconds: 300),
    Duration(milliseconds: 800),
    Duration(milliseconds: 1500),
  ];

  static bool _looksLikeDnsBlock(SocketException e) {
    final msg = e.message.toLowerCase();
    return msg.contains('failed host lookup') || msg.contains('no address associated');
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    // A BaseRequest's body stream can only be consumed once, so to retry we
    // rebuild a fresh http.Request from the same method/url/headers/body
    // on each attempt rather than resending the same object.
    List<int>? bodyBytes;
    if (request is http.Request) {
      bodyBytes = request.bodyBytes;
    }

    Object? lastError;
    var useDoh = false;
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      final toSend = _cloneRequest(request, bodyBytes);
      final client = useDoh ? _dohFallback : _inner;
      try {
        return await client.send(toSend);
      } on SocketException catch (e) {
        debugPrint('[ElyonNet] attempt ${attempt + 1}/$maxAttempts '
            '(${useDoh ? "DoH" : "system"} resolver) SocketException: $e');
        if (!useDoh && _looksLikeDnsBlock(e)) {
          useDoh = true; // confirmed DNS-level failure -> switch strategy for remaining attempts
        }
        lastError = e;
      } on http.ClientException catch (e) {
        debugPrint('[ElyonNet] attempt ${attempt + 1}/$maxAttempts '
            '(${useDoh ? "DoH" : "system"} resolver) ClientException: $e');
        lastError = e;
      }
      if (attempt < maxAttempts - 1) {
        await Future.delayed(_delays[attempt.clamp(0, _delays.length - 1)]);
      }
    }
    throw lastError ?? Exception('Request failed after $maxAttempts attempts');
  }

  http.BaseRequest _cloneRequest(http.BaseRequest original, List<int>? bodyBytes) {
    final req = http.Request(original.method, original.url)
      ..followRedirects = original.followRedirects
      ..persistentConnection = original.persistentConnection;
    req.headers.addAll(original.headers);
    if (bodyBytes != null) req.bodyBytes = bodyBytes;
    return req;
  }

  @override
  void close() {
    _inner.close();
    _dohFallback.close();
  }
}
