import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Wraps an [http.Client] and automatically retries requests that fail with
/// a transient network-level error (SocketException, connection reset, etc).
///
/// Works around DNS/socket flakiness observed on some (older/budget)
/// Android devices where the OS resolver intermittently fails for Dart's
/// own `dart:io` socket layer — "Failed host lookup" — even though the same
/// domain resolves fine in the system browser at the same moment, and even
/// after trying different DNS providers with/without VPN. Most of these
/// failures are transient and succeed on a near-immediate retry.
///
/// This does NOT fix the underlying device/OS issue (out of our control),
/// it just masks single transient blips so the user isn't shown an error
/// for something that would have worked half a second later.
class RetryHttpClient extends http.BaseClient {
  RetryHttpClient({http.Client? inner, this.maxAttempts = 3})
      : _inner = inner ?? http.Client();

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
