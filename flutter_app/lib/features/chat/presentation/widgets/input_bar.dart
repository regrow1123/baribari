import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/kakao_theme.dart';

class InputBar extends StatefulWidget {
  final void Function(String) onSend;
  final void Function(String fileName, String mimeType, int size, Uint8List bytes)? onFilePick;

  const InputBar({super.key, required this.onSend, this.onFilePick});

  @override
  State<InputBar> createState() => _InputBarState();
}

class _InputBarState extends State<InputBar> {
  final _controller = TextEditingController();
  bool _hasText = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    widget.onSend(text);
    _controller.clear();
    setState(() => _hasText = false);
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
      withData: true,
    );

    if (result != null && result.files.isNotEmpty) {
      final file = result.files.first;
      if (file.bytes != null) {
        final mimeType = _getMimeType(file.extension ?? '');
        Uint8List bytes = file.bytes!;

        // Resize images > 1MB to keep upload small
        if (mimeType.startsWith('image/') && bytes.length > 1024 * 1024) {
          debugPrint('[resize] before: ${bytes.length} bytes');
          bytes = await _resizeImage(bytes, maxDim: 1920);
          debugPrint('[resize] after: ${bytes.length} bytes');
        }

        widget.onFilePick?.call(
          file.name,
          mimeType.startsWith('image/') ? 'image/jpeg' : mimeType,
          bytes.length,
          bytes,
        );
      }
    }
  }

  Future<Uint8List> _resizeImage(Uint8List bytes, {int maxDim = 1920}) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final image = frame.image;

    double scale = 1.0;
    if (image.width > maxDim || image.height > maxDim) {
      scale = maxDim / (image.width > image.height ? image.width : image.height);
    }

    final w = (image.width * scale).round();
    final h = (image.height * scale).round();

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()));
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
      Paint()..filterQuality = FilterQuality.high,
    );
    final picture = recorder.endRecording();
    final resized = await picture.toImage(w, h);
    final byteData = await resized.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    resized.dispose();
    return byteData!.buffer.asUint8List();
  }

  String _getMimeType(String ext) {
    switch (ext.toLowerCase()) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'pdf':
        return 'application/pdf';
      default:
        return 'application/octet-stream';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: KakaoTheme.inputBg,
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.add, color: KakaoTheme.secondary),
              onPressed: _pickFile,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              tooltip: '파일 첨부 (JPG, PNG, PDF)',
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Container(
                constraints: const BoxConstraints(maxHeight: 100),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Focus(
                  onKeyEvent: (node, event) {
                    if (event is KeyDownEvent &&
                        event.logicalKey == LogicalKeyboardKey.enter &&
                        HardwareKeyboard.instance.isShiftPressed) {
                      _send();
                      return KeyEventResult.handled;
                    }
                    return KeyEventResult.ignored;
                  },
                  child: TextField(
                    controller: _controller,
                    maxLines: null,
                    textInputAction: TextInputAction.newline,
                    onChanged: (v) => setState(() => _hasText = v.trim().isNotEmpty),
                    decoration: const InputDecoration(
                      hintText: '메시지를 입력하세요 (Shift+Enter 전송)',
                      hintStyle: TextStyle(color: KakaoTheme.secondary, fontSize: 14),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _hasText ? _send : null,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _hasText ? KakaoTheme.myBubble : const Color(0xFFE0E0E0),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.send,
                  size: 18,
                  color: _hasText ? KakaoTheme.primary : KakaoTheme.secondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
