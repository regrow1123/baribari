import 'package:flutter/material.dart';
import '../../../../core/theme/kakao_theme.dart';

class UserBubble extends StatelessWidget {
  final String content;
  final DateTime time;

  const UserBubble({super.key, required this.content, required this.time});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 60, right: 16, top: 4, bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            _formatTime(time),
            style: const TextStyle(fontSize: 11, color: KakaoTheme.secondary),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Container(
              padding: KakaoTheme.bubblePadding,
              decoration: BoxDecoration(
                color: KakaoTheme.myBubble,
                borderRadius: BorderRadius.circular(KakaoTheme.bubbleRadius)
                    .copyWith(topRight: const Radius.circular(4)),
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
