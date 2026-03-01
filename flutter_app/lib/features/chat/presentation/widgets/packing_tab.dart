import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/kakao_theme.dart';
import '../../domain/models.dart';
import '../providers/chat_provider.dart';

class PackingTab extends ConsumerStatefulWidget {
  final String tripId;

  const PackingTab({super.key, required this.tripId});

  @override
  ConsumerState<PackingTab> createState() => _PackingTabState();
}

class _PackingTabState extends ConsumerState<PackingTab> {
  final Map<String, Set<int>> _checkedItems = {};

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(messagesProvider(widget.tripId));

    final packingMsg = messages.lastWhere(
      (m) => m.messageType == MessageType.packingCard && m.metadata != null,
      orElse: () => Message(
        id: '',
        tripId: widget.tripId,
        role: 'assistant',
        content: '',
        createdAt: DateTime.now(),
      ),
    );

    if (packingMsg.id.isEmpty || packingMsg.metadata == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.backpack, size: 64, color: KakaoTheme.secondary.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            const Text('아직 준비물이 없어요', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: KakaoTheme.primary)),
            const SizedBox(height: 8),
            const Text(
              '대화 탭에서 준비물을 요청해보세요!\n예: "준비물도 알려줘"',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: KakaoTheme.secondary, height: 1.5),
            ),
          ],
        ),
      );
    }

    final categories = packingMsg.metadata!['categories'] as List? ?? [];
    final totalItems = categories.fold<int>(0, (sum, cat) => sum + ((cat as Map)['items'] as List).length);
    final checkedCount = _checkedItems.values.fold<int>(0, (sum, s) => sum + s.length);

    return Container(
      color: const Color(0xFFF5F7FA),
      child: Column(
        children: [
          // Progress bar
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '준비 현황',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: KakaoTheme.primary),
                    ),
                    Text(
                      '$checkedCount / $totalItems',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF48BB78)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: totalItems > 0 ? checkedCount / totalItems : 0,
                    backgroundColor: const Color(0xFFE8E8E8),
                    valueColor: const AlwaysStoppedAnimation(Color(0xFF48BB78)),
                    minHeight: 8,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Categories
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: categories.length,
              itemBuilder: (context, catIndex) {
                final cat = categories[catIndex] as Map<String, dynamic>;
                final catName = cat['name'] as String;
                final items = cat['items'] as List? ?? [];
                final catChecked = _checkedItems[catName]?.length ?? 0;

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Category header
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: _categoryColor(catName).withValues(alpha: 0.08),
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                        ),
                        child: Row(
                          children: [
                            Text(
                              _categoryIcon(catName),
                              style: const TextStyle(fontSize: 18),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              catName,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: _categoryColor(catName),
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '$catChecked/${items.length}',
                              style: TextStyle(
                                fontSize: 13,
                                color: _categoryColor(catName),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Items
                      ...List.generate(items.length, (itemIndex) {
                        final itemName = items[itemIndex] as String;
                        final isChecked = _checkedItems[catName]?.contains(itemIndex) ?? false;

                        return InkWell(
                          onTap: () {
                            setState(() {
                              _checkedItems.putIfAbsent(catName, () => {});
                              if (isChecked) {
                                _checkedItems[catName]!.remove(itemIndex);
                              } else {
                                _checkedItems[catName]!.add(itemIndex);
                              }
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: itemIndex < items.length - 1
                                    ? BorderSide(color: KakaoTheme.divider.withValues(alpha: 0.3))
                                    : BorderSide.none,
                              ),
                            ),
                            child: Row(
                              children: [
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: isChecked ? const Color(0xFF48BB78) : Colors.transparent,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: isChecked ? const Color(0xFF48BB78) : KakaoTheme.secondary,
                                      width: 2,
                                    ),
                                  ),
                                  child: isChecked
                                      ? const Icon(Icons.check, size: 16, color: Colors.white)
                                      : null,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    itemName,
                                    style: TextStyle(
                                      fontSize: 15,
                                      color: isChecked ? KakaoTheme.secondary : KakaoTheme.primary,
                                      decoration: isChecked ? TextDecoration.lineThrough : null,
                                    ),
                                  ),
                                ),
                                // File attach button (future)
                                IconButton(
                                  icon: Icon(
                                    Icons.attach_file,
                                    size: 18,
                                    color: KakaoTheme.secondary.withValues(alpha: 0.5),
                                  ),
                                  onPressed: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('파일 첨부 기능은 준비 중이에요!')),
                                    );
                                  },
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Color _categoryColor(String name) {
    switch (name) {
      case '서류':
        return const Color(0xFFE53E3E);
      case '전자기기':
        return const Color(0xFF4A90D9);
      case '의류':
        return const Color(0xFF9F7AEA);
      case '세면도구':
        return const Color(0xFF38B2AC);
      case '기타':
        return const Color(0xFFED8936);
      default:
        return const Color(0xFF4A90D9);
    }
  }

  String _categoryIcon(String name) {
    switch (name) {
      case '서류':
        return '📄';
      case '전자기기':
        return '🔌';
      case '의류':
        return '👕';
      case '세면도구':
        return '🧴';
      case '기타':
        return '📦';
      default:
        return '📋';
    }
  }
}
