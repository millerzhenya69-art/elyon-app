import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/chat_message.dart';
import '../models/user_model.dart';

const String _kBaseUrl = 'https://elyon-ai-web.vercel.app/api/relay';

class AiService {
  AiService({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;

  static String _modelId(SubscriptionTier tier) {
    switch (tier) {
      case SubscriptionTier.core:       return 'gpt';
      case SubscriptionTier.nova:       return 'nova';
      case SubscriptionTier.pro:        return 'pro';
      case SubscriptionTier.absolution: return 'absolution';
    }
  }

  Future<String> sendMessage({
    required List<ChatMessage> history,
    required SubscriptionTier tier,
    required String userId,
  }) async {
    // Backend requires user_id as INTEGER
    final dynamic userIdValue = int.tryParse(userId) ?? userId;

    final response = await _client.post(
      Uri.parse('$_kBaseUrl/api/chat'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'user_id': userIdValue,
        'model':   _modelId(tier),
        'messages': history.map((m) => {
          'role':    m.isUser ? 'user' : 'assistant',
          'content': m.content,
        }).toList(),
      }),
    ).timeout(const Duration(seconds: 90));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data['error'] == 'daily_limit') {
        throw const AiException(AiErrorType.rateLimited, 'Daily message limit reached');
      }
      return data['reply'] as String? ?? '';
    } else if (response.statusCode == 429) {
      throw const AiException(AiErrorType.rateLimited, 'Daily message limit reached');
    } else if (response.statusCode == 403) {
      throw const AiException(AiErrorType.unauthorized,
          'No active subscription for this model. Please upgrade.');
    } else if (response.statusCode == 503) {
      throw const AiException(AiErrorType.serverError,
          'Server is waking up — please wait 30 seconds and try again.');
    } else {
      String detail = 'Server error ${response.statusCode}';
      try {
        final d = jsonDecode(response.body) as Map<String, dynamic>;
        detail = d['error']?.toString() ?? detail;
      } catch (_) {}
      throw AiException(AiErrorType.serverError, detail);
    }
  }

  /// Sends a file (as base64) plus an optional text prompt to the backend's
  /// /api/file_b64 endpoint. Mirrors the web app's handleFile() flow.
  Future<String> sendFileMessage({
    required List<ChatMessage> history,
    required SubscriptionTier tier,
    required String userId,
    required String fileName,
    required String mimeType,
    required String base64Data,
    String prompt = ' ',
  }) async {
    final dynamic userIdValue = int.tryParse(userId) ?? userId;

    final response = await _client.post(
      Uri.parse('$_kBaseUrl/api/file_b64'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'user_id':   userIdValue,
        'model':     _modelId(tier),
        'prompt':    prompt,
        'file_name': fileName,
        'file_type': mimeType,
        'file_data': base64Data,
        'history': history
            .where((m) => !m.isStreaming)
            .map((m) => {
                  'role':    m.isUser ? 'user' : 'assistant',
                  'content': m.content,
                })
            .toList(),
      }),
    ).timeout(const Duration(seconds: 120));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data['error'] != null) {
        throw AiException(AiErrorType.serverError, data['error'].toString());
      }
      return data['reply'] as String? ?? '';
    } else if (response.statusCode == 403) {
      throw const AiException(AiErrorType.unauthorized,
          'No active subscription for this model. Please upgrade.');
    } else if (response.statusCode == 503) {
      throw const AiException(AiErrorType.serverError,
          'Server is waking up — please wait 30 seconds and try again.');
    } else {
      String detail = 'Server error ${response.statusCode}';
      try {
        final d = jsonDecode(response.body) as Map<String, dynamic>;
        detail = d['error']?.toString() ?? detail;
      } catch (_) {}
      throw AiException(AiErrorType.serverError, detail);
    }
  }

  Stream<String> streamMessage({
    required List<ChatMessage> history,
    required SubscriptionTier tier,
    required String userId,
  }) async* {
    final reply = await sendMessage(history: history, tier: tier, userId: userId);
    const chunkSize = 6;
    for (var i = 0; i < reply.length; i += chunkSize) {
      final end = (i + chunkSize).clamp(0, reply.length);
      yield reply.substring(i, end);
      await Future.delayed(const Duration(milliseconds: 12));
    }
  }

  void dispose() => _client.close();
}

enum AiErrorType { rateLimited, unauthorized, serverError, networkError }

class AiException implements Exception {
  const AiException(this.type, this.message);
  final AiErrorType type;
  final String message;
  @override
  String toString() => 'AiException(${type.name}): $message';
}
