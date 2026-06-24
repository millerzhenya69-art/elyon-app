import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_theme.dart';
import '../models/chat_message.dart';
import 'elyon_logo.dart';

/// Scrollable messages list.
/// Mirrors the web .messages component with:
///   - user bubble (right-aligned, card2 background)
///   - AI response (left-aligned with avatar, markdown support)
///   - spinning logo typing indicator
class MessagesList extends StatefulWidget {
  const MessagesList({
    super.key,
    required this.messages,
  });

  final List<ChatMessage> messages;

  @override
  State<MessagesList> createState() => _MessagesListState();
}

class _MessagesListState extends State<MessagesList> {
  final _scroll = ScrollController();

  @override
  void didUpdateWidget(MessagesList oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Auto-scroll when new messages arrive
    if (widget.messages.length != oldWidget.messages.length ||
        (widget.messages.isNotEmpty &&
            oldWidget.messages.isNotEmpty &&
            widget.messages.last.content != oldWidget.messages.last.content)) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }
  }

  void _scrollToBottom() {
    if (_scroll.hasClients) {
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(0, 24, 0, 8),
      itemCount: widget.messages.length,
      itemBuilder: (context, index) {
        final msg = widget.messages[index];
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
              child: msg.isUser
                  ? _UserMessage(message: msg)
                  : _AiMessage(message: msg),
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _UserMessage extends StatelessWidget {
  const _UserMessage({required this.message});
  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final elyon = context.elyon;
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.72,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: elyon.card2Bg,
          border: Border.all(color: elyon.borderColor),
          borderRadius: const BorderRadius.only(
            topLeft:     Radius.circular(18),
            topRight:    Radius.circular(18),
            bottomLeft:  Radius.circular(18),
            bottomRight: Radius.circular(4),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (message.hasFile) ...[
              _FileAttachmentChip(fileInfo: message.fileInfo!),
              if (message.content.isNotEmpty) const SizedBox(height: 8),
            ],
            if (message.content.isNotEmpty)
              Text(
                message.content,
                style: AppTextStyles.messageBody(
                  fontSize: 14,
                  color: elyon.primaryText,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Shows a sent file as a small card — mirrors the web app's .msg-file
/// (non-image files) since we don't keep raw bytes around after sending.
class _FileAttachmentChip extends StatelessWidget {
  const _FileAttachmentChip({required this.fileInfo});
  final MessageFileInfo fileInfo;

  String _mimeIcon(String mime) {
    if (mime.startsWith('image/')) return '🖼';
    if (mime.startsWith('video/')) return '🎬';
    if (mime.startsWith('audio/')) return '🎵';
    if (mime == 'application/pdf') return '📕';
    if (mime.contains('python')) return '🐍';
    if (mime.contains('json')) return '{}';
    return '📄';
  }

  String _fmtSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final elyon = context.elyon;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: elyon.primaryText.withOpacity(0.06),
        border: Border.all(color: elyon.primaryText.withOpacity(0.1)),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 30, height: 30,
          decoration: BoxDecoration(
            color: elyon.primaryText.withOpacity(0.08),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Center(child: Text(_mimeIcon(fileInfo.mimeType), style: const TextStyle(fontSize: 14))),
        ),
        const SizedBox(width: 9),
        Flexible(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(fileInfo.name, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontFamily: 'DMSans', fontSize: 12, fontWeight: FontWeight.w500, color: elyon.primaryText)),
            Text(_fmtSize(fileInfo.sizeBytes),
              style: TextStyle(fontFamily: 'DMSans', fontSize: 10, color: elyon.mutedText)),
          ]),
        ),
        const SizedBox(width: 8),
        const Text('✓', style: TextStyle(color: Color(0xFF4ADE80), fontSize: 13)),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _AiMessage extends StatelessWidget {
  const _AiMessage({required this.message});
  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final elyon = context.elyon;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Avatar
        _AiAvatar(spinning: message.isStreaming),
        const SizedBox(width: 12),

        // Content
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: message.isStreaming && message.content.isEmpty
                ? _TypingDots()  // Still waiting for first chunk
                : _AiContent(
                    content:    message.content,
                    streaming:  message.isStreaming,
                    textColor:  elyon.primaryText.withOpacity(0.88),
                  ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _AiAvatar extends StatefulWidget {
  const _AiAvatar({required this.spinning});
  final bool spinning;

  @override
  State<_AiAvatar> createState() => _AiAvatarState();
}

class _AiAvatarState extends State<_AiAvatar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
    if (widget.spinning) _ctrl.repeat();
  }

  @override
  void didUpdateWidget(_AiAvatar old) {
    super.didUpdateWidget(old);
    if (widget.spinning && !_ctrl.isAnimating) {
      _ctrl.repeat();
    } else if (!widget.spinning && _ctrl.isAnimating) {
      _ctrl.stop();
      _ctrl.reset();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ElyonLogo(
      size: 28,
      spin: widget.spinning,
      controller: widget.spinning ? _ctrl : null,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

/// Markdown-rendered AI response content
class _AiContent extends StatelessWidget {
  const _AiContent({
    required this.content,
    required this.streaming,
    required this.textColor,
  });

  final String content;
  final bool streaming;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return MarkdownBody(
      data:            content,
      selectable:      true,
      styleSheet: MarkdownStyleSheet(
        p: TextStyle(
          fontFamily: 'DMSans',
          fontSize: 14,
          height: 1.75,
          color: textColor,
        ),
        code: TextStyle(
          fontFamily: 'monospace',
          fontSize: 13,
          color: AppColors.beige2,
          backgroundColor: AppColors.card,
        ),
        codeblockDecoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        blockquoteDecoration: BoxDecoration(
          border: Border(
            left: BorderSide(color: AppColors.beige2, width: 3),
          ),
        ),
        strong: TextStyle(
          fontFamily: 'DMSans',
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
        em: TextStyle(
          fontFamily: 'DMSans',
          fontStyle: FontStyle.italic,
          color: textColor,
        ),
        h1: TextStyle(
          fontFamily: 'InstrumentSerif',
          fontSize: 24,
          color: textColor,
        ),
        h2: TextStyle(
          fontFamily: 'InstrumentSerif',
          fontSize: 20,
          color: textColor,
        ),
        h3: TextStyle(
          fontFamily: 'DMSans',
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
        listBullet: TextStyle(color: textColor),
        tableBody: TextStyle(color: textColor, fontSize: 13),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

/// Bouncing dots shown while waiting for the first streaming chunk
class _TypingDots extends StatefulWidget {
  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with TickerProviderStateMixin {
  late final List<AnimationController> _ctrls;
  late final List<Animation<double>> _anims;

  @override
  void initState() {
    super.initState();
    _ctrls = List.generate(
      3,
      (i) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1200),
      )..repeat(reverse: false),
    );

    _anims = _ctrls.asMap().entries.map((e) {
      final offset = e.key * 0.15;
      return TweenSequence([
        TweenSequenceItem(tween: Tween(begin: 0.4, end: 1.0), weight: 40),
        TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.4), weight: 40),
        TweenSequenceItem(tween: ConstantTween(0.4), weight: 20),
      ]).animate(
        CurvedAnimation(
          parent: _ctrls[e.key],
          curve: Interval(offset, 1.0, curve: Curves.easeInOut),
        ),
      );
    }).toList();

    for (var i = 0; i < _ctrls.length; i++) {
      Future.delayed(Duration(milliseconds: i * 150), () {
        if (mounted) _ctrls[i].repeat();
      });
    }
  }

  @override
  void dispose() {
    for (final c in _ctrls) c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: List.generate(3, (i) {
          return AnimatedBuilder(
            animation: _ctrls[i],
            builder: (_, __) => Container(
              margin: const EdgeInsets.only(right: 5),
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: AppColors.beige2.withOpacity(_anims[i].value),
                shape: BoxShape.circle,
              ),
            ),
          );
        }),
      ),
    );
  }
}
