import 'package:flutter/material.dart';
import '../../../../core/theme/kakao_theme.dart';

class InputBar extends StatefulWidget {
  final void Function(String) onSend;

  const InputBar({super.key, required this.onSend});

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

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: KakaoTheme.inputBg,
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Attachment button (for file upload - v2)
            IconButton(
              icon: const Icon(Icons.add, color: KakaoTheme.secondary),
              onPressed: () {},
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            ),
            const SizedBox(width: 4),
            // Text input
            Expanded(
              child: Container(
                constraints: const BoxConstraints(maxHeight: 100),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: TextField(
                  controller: _controller,
                  maxLines: null,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _send(),
                  onChanged: (v) => setState(() => _hasText = v.trim().isNotEmpty),
                  decoration: const InputDecoration(
                    hintText: '메시지를 입력하세요',
                    hintStyle: TextStyle(color: KakaoTheme.secondary, fontSize: 14),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Send button
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
