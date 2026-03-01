import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../../../core/theme/kakao_theme.dart';

class FileBubble extends StatelessWidget {
  final String fileName;
  final String fileType;
  final int fileSize;
  final Uint8List? fileBytes;
  final DateTime time;
  final String? linkedItem;

  const FileBubble({
    super.key,
    required this.fileName,
    required this.fileType,
    required this.fileSize,
    this.fileBytes,
    required this.time,
    this.linkedItem,
  });

  @override
  Widget build(BuildContext context) {
    final isImage = fileType.startsWith('image/');

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
              constraints: const BoxConstraints(maxWidth: 280),
              decoration: BoxDecoration(
                color: KakaoTheme.myBubble,
                borderRadius: BorderRadius.circular(KakaoTheme.bubbleRadius)
                    .copyWith(topRight: const Radius.circular(4)),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Image preview
                  if (isImage && fileBytes != null)
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 200),
                      child: Image.memory(
                        fileBytes!,
                        fit: BoxFit.cover,
                        width: double.infinity,
                      ),
                    ),
                  // File info
                  Padding(
                    padding: const EdgeInsets.all(10),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: _fileColor(fileType).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(
                              _fileIcon(fileType),
                              style: const TextStyle(fontSize: 20),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                fileName,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: KakaoTheme.primary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                _formatSize(fileSize),
                                style: const TextStyle(fontSize: 11, color: KakaoTheme.secondary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Linked item badge
          if (linkedItem != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF4A90D9).withValues(alpha: 0.1),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(KakaoTheme.bubbleRadius),
                  bottomRight: Radius.circular(4),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.link, size: 12, color: Color(0xFF4A90D9)),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      linkedItem!,
                      style: const TextStyle(fontSize: 11, color: Color(0xFF4A90D9)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _fileIcon(String mimeType) {
    if (mimeType.startsWith('image/')) return '🖼️';
    if (mimeType == 'application/pdf') return '📄';
    return '📎';
  }

  Color _fileColor(String mimeType) {
    if (mimeType.startsWith('image/')) return const Color(0xFF9F7AEA);
    if (mimeType == 'application/pdf') return const Color(0xFFE53E3E);
    return const Color(0xFF4A90D9);
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour;
    final m = dt.minute.toString().padLeft(2, '0');
    final period = h < 12 ? '오전' : '오후';
    final hour = h > 12 ? h - 12 : (h == 0 ? 12 : h);
    return '$period $hour:$m';
  }
}
