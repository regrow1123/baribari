import 'package:flutter/material.dart';
import '../../../../core/theme/kakao_theme.dart';

class AssistantBubble extends StatelessWidget {
  final String content;
  final DateTime time;

  const AssistantBubble({super.key, required this.content, required this.time});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 60, top: 4, bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CircleAvatar(
            radius: 18,
            backgroundColor: KakaoTheme.myBubble,
            child: Text('🧳', style: TextStyle(fontSize: 18)),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '바리바리',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: KakaoTheme.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Flexible(
                      child: Container(
                        padding: KakaoTheme.bubblePadding,
                        decoration: BoxDecoration(
                          color: KakaoTheme.otherBubble,
                          borderRadius:
                              BorderRadius.circular(KakaoTheme.bubbleRadius)
                                  .copyWith(topLeft: const Radius.circular(4)),
                        ),
                        child: Text(
                          content,
                          style: const TextStyle(
                            fontSize: 15,
                            color: KakaoTheme.primary,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _formatTime(time),
                      style: const TextStyle(
                          fontSize: 11, color: KakaoTheme.secondary),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour;
    final m = dt.minute.toString().padLeft(2, '0');
    final period = h < 12 ? '오전' : '오후';
    final hour = h > 12 ? h - 12 : (h == 0 ? 12 : h);
    return '$period $hour:$m';
  }
}
