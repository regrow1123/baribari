import 'package:flutter/material.dart';
import '../../../../core/theme/kakao_theme.dart';

class PackingCard extends StatefulWidget {
  final Map<String, dynamic> metadata;
  final DateTime time;

  const PackingCard({super.key, required this.metadata, required this.time});

  @override
  State<PackingCard> createState() => _PackingCardState();
}

class _PackingCardState extends State<PackingCard> {
  final Map<String, Set<int>> _checkedItems = {};

  @override
  Widget build(BuildContext context) {
    final categories = widget.metadata['categories'] as List? ?? [];

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
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: KakaoTheme.primary),
                ),
                const SizedBox(height: 4),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(KakaoTheme.cardRadius),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      // Header
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        color: const Color(0xFF48BB78),
                        child: Row(
                          children: [
                            const Text('🎒', style: TextStyle(fontSize: 16)),
                            const SizedBox(width: 8),
                            const Text(
                              '준비물 체크리스트',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            const Spacer(),
                            Text(
                              '${_totalChecked()}/${_totalItems(categories)}',
                              style: const TextStyle(color: Colors.white70, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      // Categories
                      ...List.generate(categories.length, (catIndex) {
                        final cat = categories[catIndex] as Map<String, dynamic>;
                        final catName = cat['name'] as String;
                        final items = cat['items'] as List? ?? [];

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
                              child: Text(
                                catName,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: KakaoTheme.primary,
                                ),
                              ),
                            ),
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
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  child: Row(
                                    children: [
                                      Icon(
                                        isChecked ? Icons.check_circle : Icons.circle_outlined,
                                        size: 20,
                                        color: isChecked ? const Color(0xFF48BB78) : KakaoTheme.secondary,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        itemName,
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: isChecked ? KakaoTheme.secondary : KakaoTheme.primary,
                                          decoration: isChecked ? TextDecoration.lineThrough : null,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }),
                            if (catIndex < categories.length - 1)
                              Divider(height: 1, color: KakaoTheme.divider.withValues(alpha: 0.5)),
                          ],
                        );
                      }),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  int _totalChecked() {
    int count = 0;
    for (final set in _checkedItems.values) {
      count += set.length;
    }
    return count;
  }

  int _totalItems(List categories) {
    int count = 0;
    for (final cat in categories) {
      count += ((cat as Map)['items'] as List).length;
    }
    return count;
  }
}
