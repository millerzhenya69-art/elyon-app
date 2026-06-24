import 'package:uuid/uuid.dart';

const _uuid = Uuid();

enum MessageRole { user, assistant }

/// Metadata about a file attached to a user message.
class MessageFileInfo {
  const MessageFileInfo({
    required this.name,
    required this.mimeType,
    required this.sizeBytes,
  });

  final String name;
  final String mimeType;
  final int sizeBytes;

  bool get isImage => mimeType.startsWith('image/');

  Map<String, dynamic> toJson() => {
        'name':      name,
        'mimeType':  mimeType,
        'sizeBytes': sizeBytes,
      };

  factory MessageFileInfo.fromJson(Map<String, dynamic> json) => MessageFileInfo(
        name:      json['name'] as String,
        mimeType:  json['mimeType'] as String,
        sizeBytes: json['sizeBytes'] as int,
      );
}

/// Single chat message (user or AI)
class ChatMessage {
  ChatMessage({
    String? id,
    required this.role,
    required this.content,
    DateTime? timestamp,
    this.isStreaming = false,
    this.fileInfo,
  })  : id = id ?? _uuid.v4(),
        timestamp = timestamp ?? DateTime.now();

  final String id;
  final MessageRole role;
  final String content;
  final DateTime timestamp;
  final bool isStreaming;
  /// Set when this message had a file attached (image, document, etc.)
  final MessageFileInfo? fileInfo;

  bool get isUser      => role == MessageRole.user;
  bool get isAssistant => role == MessageRole.assistant;
  bool get hasFile      => fileInfo != null;

  ChatMessage copyWith({
    String? content,
    bool? isStreaming,
    MessageFileInfo? fileInfo,
  }) =>
      ChatMessage(
        id:          id,
        role:        role,
        content:     content      ?? this.content,
        timestamp:   timestamp,
        isStreaming: isStreaming   ?? this.isStreaming,
        fileInfo:    fileInfo      ?? this.fileInfo,
      );

  Map<String, dynamic> toJson() => {
        'id':        id,
        'role':      role.name,
        'content':   content,
        'timestamp': timestamp.toIso8601String(),
        if (fileInfo != null) 'fileInfo': fileInfo!.toJson(),
      };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        id:        json['id'] as String,
        role:      MessageRole.values.firstWhere((r) => r.name == json['role']),
        content:   json['content'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
        fileInfo:  json['fileInfo'] != null
            ? MessageFileInfo.fromJson(json['fileInfo'] as Map<String, dynamic>)
            : null,
      );
}

/// A conversation / chat session
class ChatSession {
  ChatSession({
    String? id,
    required this.title,
    List<ChatMessage>? messages,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? _uuid.v4(),
        messages   = messages   ?? [],
        createdAt  = createdAt  ?? DateTime.now(),
        updatedAt  = updatedAt  ?? DateTime.now();

  final String id;
  String title;
  final List<ChatMessage> messages;
  final DateTime createdAt;
  DateTime updatedAt;

  /// Auto-generate a title from the first user message
  String get displayTitle =>
      title.isNotEmpty
          ? title
          : messages.firstWhere(
                (m) => m.isUser,
                orElse: () => ChatMessage(
                  role: MessageRole.user,
                  content: 'New Chat',
                ),
              ).content.length > 40
              ? '${messages.first.content.substring(0, 40)}…'
              : messages.isNotEmpty
                  ? messages.first.content
                  : 'New Chat';

  ChatSession copyWith({String? title, List<ChatMessage>? messages}) =>
      ChatSession(
        id:        id,
        title:     title     ?? this.title,
        messages:  messages  ?? this.messages,
        createdAt: createdAt,
        updatedAt: DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'id':        id,
        'title':     title,
        'messages':  messages.map((m) => m.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory ChatSession.fromJson(Map<String, dynamic> json) => ChatSession(
        id:        json['id'] as String,
        title:     json['title'] as String,
        messages:  (json['messages'] as List)
            .map((m) => ChatMessage.fromJson(m as Map<String, dynamic>))
            .toList(),
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
      );
}
