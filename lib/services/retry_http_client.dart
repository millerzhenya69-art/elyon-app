import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'doh_http_client.dart';

/// Wraps an [http.Client] and automatically retries requests that fail with
/// a transient network-level error (SocketException, connection reset, etc).
///
/// The inner client defaults to [DohHttpClient], which resolves via DNS-over-
/// HTTPS instead of the carrier/OS resolver — confirmed via on-device logcat
/// (2026-07-31) that some mobile carriers hard-block DNS for this domain
/// ("Failed host lookup ... errno = 7", answered instantly, not a timeout),
/// so retrying alone never helped on those networks. The retry loop here
/// still matters for genuinely transient blips (dropped packet, brief
/// congestion) on networks where DoH itself succeeds.
class RetryHttpClient extends http.BaseClient {
  RetryHttpClient({http.Client? inner, this.maxAttempts = 3})
      : _inner = inner ?? DohHttpClient();

  final http.Client _inner;
  final int maxAttempts;

  static const _delays = [
    Duration(milliseconds: 300),
    Duration(milliseconds: 800),
    Duration(milliseconds: 1500),
  ];

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
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      final toSend = _cloneRequest(request, bodyBytes);
      try {
        return await _inner.send(toSend);
      } on SocketException catch (e) {
        debugPrint('[ElyonNet] attempt ${attempt + 1}/$maxAttempts SocketException: $e');
        lastError = e;
      } on http.ClientException catch (e) {
        debugPrint('[ElyonNet] attempt ${attempt + 1}/$maxAttempts ClientException: $e');
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
  void close() => _inner.close();
}
