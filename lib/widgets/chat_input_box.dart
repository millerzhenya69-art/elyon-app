import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../providers/app_providers.dart';
import '../providers/app_strings.dart';

const Map<String, String> _kExtMime = {
  '.py':'text/x-python', '.js':'text/javascript', '.ts':'text/javascript',
  '.cpp':'text/x-c++', '.c':'text/x-c', '.java':'text/x-java',
  '.go':'text/plain', '.rs':'text/plain', '.sh':'text/plain',
  '.md':'text/plain', '.txt':'text/plain', '.sql':'text/plain',
  '.yaml':'text/plain', '.yml':'text/plain',
  '.json':'application/json', '.html':'text/html', '.css':'text/css',
  '.csv':'text/csv', '.xml':'text/xml',
  '.png':'image/png', '.jpg':'image/jpeg', '.jpeg':'image/jpeg',
  '.gif':'image/gif', '.webp':'image/webp',
  '.pdf':'application/pdf',
  '.mp3':'audio/mpeg', '.wav':'audio/wav', '.ogg':'audio/ogg',
  '.mp4':'video/mp4', '.mov':'video/mov', '.webm':'video/webm',
};

String _mimeForFile(String name) {
  final ext = name.contains('.') ? name.substring(name.lastIndexOf('.')).toLowerCase() : '';
  return _kExtMime[ext] ?? 'application/octet-stream';
}

String _fmtSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

String _mimeIcon(String mime) {
  if (mime.startsWith('image/')) return '🖼';
  if (mime.startsWith('video/')) return '🎬';
  if (mime.startsWith('audio/')) return '🎵';
  if (mime == 'application/pdf') return '📕';
  if (mime.contains('python')) return '🐍';
  if (mime.contains('json')) return '{}';
  return '📄';
}

/// Holds a picked-but-not-yet-sent file, mirroring the web app's pendingFile.
class _PendingFile {
  const _PendingFile({
    required this.name,
    required this.mime,
    required this.sizeBytes,
    required this.base64Data,
    this.previewBytes,
  });
  final String name;
  final String mime;
  final int sizeBytes;
  final String base64Data;
  final List<int>? previewBytes; // raw bytes for image preview thumbnail

  bool get isImage => mime.startsWith('image/');
}

/// Bottom input area — auto-growing textarea + send button + file attach.
/// Mirrors the web .input-box + .file-bar components.
class ChatInputBox extends ConsumerStatefulWidget {
  const ChatInputBox({super.key, required this.onSend});

  final void Function(String text) onSend;

  @override
  ConsumerState<ChatInputBox> createState() => _ChatInputBoxState();
}

class _ChatInputBoxState extends ConsumerState<ChatInputBox> {
  final _controller = TextEditingController();
  final _focusNode  = FocusNode();
  bool _hasText = false;
  _PendingFile? _pendingFile;
  bool _pickingFile = false;

  static const int _maxFileBytes = 20 * 1024 * 1024; // 20 MB, matches web app

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final has = _controller.text.trim().isNotEmpty || _pendingFile != null;
      if (has != _hasText) setState(() => _hasText = has);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    if (_pickingFile) return;
    setState(() => _pickingFile = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        withData: true,
        type: FileType.custom,
        allowedExtensions: [
          'jpg','jpeg','png','gif','webp',
          'mp4','mov','webm',
          'mp3','wav','ogg',
          'pdf','txt','py','js','ts','cpp','c','java','go','rs',
          'html','css','json','csv','md','sql','yaml','yml',
        ],
      );
      if (result == null || result.files.isEmpty) return;
      final picked = result.files.single;

      final bytes = picked.bytes ?? (picked.path != null ? await File(picked.path!).readAsBytes() : null);
      if (bytes == null) {
        _showSnack('Could not read file.');
        return;
      }
      if (bytes.length > _maxFileBytes) {
        _showSnack('File too large (max 20 MB).');
        return;
      }

      final mime = _mimeForFile(picked.name);
      setState(() {
        _pendingFile = _PendingFile(
          name: picked.name,
          mime: mime,
          sizeBytes: bytes.length,
          base64Data: base64Encode(bytes),
          previewBytes: mime.startsWith('image/') ? bytes : null,
        );
        _hasText = true;
      });
    } catch (e) {
      _showSnack('Failed to attach file: $e');
    } finally {
      if (mounted) setState(() => _pickingFile = false);
    }
  }

  void _clearFile() {
    setState(() {
      _pendingFile = null;
      _hasText = _controller.text.trim().isNotEmpty;
    });
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _submit() {
    final text = _controller.text.trim();
    final file = _pendingFile;

    if (text.isEmpty && file == null) return;

    if (file != null) {
      ref.read(activeChatProvider.notifier).sendMessageWithFile(
        text: text,
        fileName: file.name,
        mimeType: file.mime,
        base64Data: file.base64Data,
        fileSizeBytes: file.sizeBytes,
      );
      setState(() { _pendingFile = null; _hasText = false; });
      _controller.clear();
    } else {
      widget.onSend(text);
      _controller.clear();
      setState(() => _hasText = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final elyon = context.elyon;
    final t     = AppStrings.of(ref);
    final user  = ref.watch(userProvider);
    final canSend = user?.canSendMessage ?? false;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end:   Alignment.bottomCenter,
          colors: [
            elyon.scaffoldBg.withOpacity(0),
            elyon.scaffoldBg.withOpacity(1),
          ],
          stops: const [0.0, 0.3],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_pendingFile != null) ...[
            _FileBar(file: _pendingFile!, onRemove: _clearFile),
            const SizedBox(height: 7),
          ],

          // Input box
          _InputBox(
            controller: _controller,
            focusNode:  _focusNode,
            hasText:    _hasText && canSend,
            canSend:    canSend,
            onSend:     _submit,
            onAttach:   _pickFile,
            attaching:  _pickingFile,
            hintText:   canSend ? t.messageElyon : t.dailyLimitReached,
          ),

          const SizedBox(height: 10),
          Text(
            canSend
                ? t.enterToSend
                : t.messagesRemaining(user?.remainingMessages ?? 0),
            style: TextStyle(
              fontFamily: 'DMSans',
              fontSize: 11,
              color: elyon.mutedText.withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ── File bar — preview of the attached file before sending ────────

class _FileBar extends StatelessWidget {
  const _FileBar({required this.file, required this.onRemove});
  final _PendingFile file;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final elyon = context.elyon;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: elyon.primaryText.withOpacity(0.05),
        border: Border.all(color: elyon.borderColor),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Row(children: [
        if (file.isImage && file.previewBytes != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Image.memory(
              Uint8List.fromList(file.previewBytes!),
              width: 28, height: 28, fit: BoxFit.cover,
            ),
          )
        else
          Text(_mimeIcon(file.mime), style: const TextStyle(fontSize: 16)),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            file.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontFamily: 'DMSans', fontSize: 12, color: elyon.primaryText),
          ),
        ),
        const SizedBox(width: 8),
        Text(_fmtSize(file.sizeBytes), style: TextStyle(
          fontFamily: 'DMSans', fontSize: 10, color: elyon.mutedText)),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: onRemove,
          child: Icon(Icons.close_rounded, size: 14, color: elyon.mutedText),
        ),
      ]),
    );
  }
}

class _InputBox extends StatefulWidget {
  const _InputBox({
    required this.controller,
    required this.focusNode,
    required this.hasText,
    required this.canSend,
    required this.onSend,
    required this.onAttach,
    required this.attaching,
    required this.hintText,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool hasText;
  final bool canSend;
  final VoidCallback onSend;
  final VoidCallback onAttach;
  final bool attaching;
  final String hintText;

  @override
  State<_InputBox> createState() => _InputBoxState();
}

class _InputBoxState extends State<_InputBox> {
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(() {
      setState(() => _focused = widget.focusNode.hasFocus);
    });
  }

  @override
  Widget build(BuildContext context) {
    final elyon = context.elyon;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: elyon.surfaceBg,
        border: Border.all(
          color: _focused
              ? AppColors.beige.withOpacity(0.28)
              : elyon.border2Color,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(_focused ? 0.4 : 0.3),
            blurRadius: _focused ? 32 : 24,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 12, 12, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Textarea
            Expanded(
              child: KeyboardListener(
                focusNode: FocusNode(),
                onKeyEvent: (event) {
                  if (event is KeyDownEvent &&
                      event.logicalKey == LogicalKeyboardKey.enter &&
                      !HardwareKeyboard.instance.isShiftPressed) {
                    widget.onSend();
                  }
                },
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minHeight: 24,
                    maxHeight: 160,
                  ),
                  child: TextField(
                    controller:  widget.controller,
                    focusNode:   widget.focusNode,
                    enabled:     widget.canSend,
                    maxLines:    null,
                    style: TextStyle(
                      fontFamily: 'DMSans',
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                      height: 1.55,
                      color: elyon.primaryText,
                    ),
                    decoration: InputDecoration(
                      border:          InputBorder.none,
                      focusedBorder:   InputBorder.none,
                      enabledBorder:   InputBorder.none,
                      isDense:         true,
                      contentPadding:  EdgeInsets.zero,
                      hintText: widget.hintText,
                      hintStyle: TextStyle(
                        fontFamily: 'DMSans',
                        fontSize: 15,
                        color: elyon.mutedText.withOpacity(0.7),
                      ),
                      filled:      false,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(width: 10),

            // Action buttons row
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Attach — теперь реально открывает file picker
                _IconBtn(
                  icon: Icons.attach_file_rounded,
                  onTap: widget.canSend ? widget.onAttach : null,
                  busy: widget.attaching,
                ),
                const SizedBox(width: 4),

                // Send button
                _SendBtn(
                  active: widget.hasText,
                  onTap:  widget.onSend,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _IconBtn extends StatefulWidget {
  const _IconBtn({required this.icon, required this.onTap, this.busy = false});
  final IconData icon;
  final VoidCallback? onTap;
  final bool busy;

  @override
  State<_IconBtn> createState() => _IconBtnState();
}

class _IconBtnState extends State<_IconBtn> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final elyon = context.elyon;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit:  (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: _hover
                ? elyon.primaryText.withOpacity(0.06)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: widget.busy
              ? Padding(
                  padding: const EdgeInsets.all(9),
                  child: CircularProgressIndicator(strokeWidth: 2, color: elyon.mutedText),
                )
              : Icon(
                  widget.icon,
                  size: 16,
                  color: widget.onTap == null
                      ? elyon.mutedText.withOpacity(0.4)
                      : (_hover ? elyon.primaryText : elyon.mutedText),
                ),
        ),
      ),
    );
  }
}

class _SendBtn extends StatefulWidget {
  const _SendBtn({required this.active, required this.onTap});
  final bool active;
  final VoidCallback onTap;

  @override
  State<_SendBtn> createState() => _SendBtnState();
}

class _SendBtnState extends State<_SendBtn> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit:  (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.active ? widget.onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: widget.active
                ? (_hover ? AppColors.white : AppColors.beige)
                : AppColors.beige.withOpacity(0.35),
            borderRadius: BorderRadius.circular(10),
          ),
          child: AnimatedScale(
            scale: (_hover && widget.active) ? 1.05 : 1.0,
            duration: const Duration(milliseconds: 150),
            child: const Icon(
              Icons.arrow_upward_rounded,
              size: 16,
              color: AppColors.black,
            ),
          ),
        ),
      ),
    );
  }
}

