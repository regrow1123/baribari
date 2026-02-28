import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/kakao_theme.dart';

class ItineraryCard extends StatefulWidget {
  final Map<String, dynamic> metadata;
  final DateTime time;

  const ItineraryCard({super.key, required this.metadata, required this.time});

  @override
  State<ItineraryCard> createState() => _ItineraryCardState();
}

class _ItineraryCardState extends State<ItineraryCard> {
  final Set<int> _expandedDays = {0}; // First day expanded by default

  @override
  Widget build(BuildContext context) {
    final days = widget.metadata['days'] as List? ?? [];

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
                        color: const Color(0xFF4A90D9),
                        child: const Row(
                          children: [
                            Text('🗓️', style: TextStyle(fontSize: 16)),
                            SizedBox(width: 8),
                            Text(
                              '여행 일정',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Days
                      ...List.generate(days.length, (index) {
                        final day = days[index] as Map<String, dynamic>;
                        final dayNum = day['day'] ?? index + 1;
                        final date = day['date'] as String?;
                        final items = day['items'] as List? ?? [];
                        final isExpanded = _expandedDays.contains(index);

                        return Column(
                          children: [
                            // Day header (tap to expand)
                            InkWell(
                              onTap: () {
                                setState(() {
                                  if (isExpanded) {
                                    _expandedDays.remove(index);
                                  } else {
                                    _expandedDays.add(index);
                                  }
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(color: KakaoTheme.divider.withValues(alpha: 0.5)),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF4A90D9),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        'Day $dayNum',
                                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    if (date != null) ...[
                                      const SizedBox(width: 8),
                                      Text(date, style: const TextStyle(fontSize: 13, color: KakaoTheme.secondary)),
                                    ],
                                    const Spacer(),
                                    Icon(
                                      isExpanded ? Icons.expand_less : Icons.expand_more,
                                      size: 20,
                                      color: KakaoTheme.secondary,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            // Items
                            if (isExpanded)
                              ...List.generate(items.length, (i) {
                                final item = items[i] as Map<String, dynamic>;
                                return _buildItem(item);
                              }),
                          ],
                        );
                      }),
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

  Widget _buildItem(Map<String, dynamic> item) {
    final costKrw = item['estimatedCostKrw'] as int?;
    final costStr = costKrw != null
        ? NumberFormat.currency(locale: 'ko_KR', symbol: '₩', decimalDigits: 0).format(costKrw)
        : null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: KakaoTheme.divider.withValues(alpha: 0.3))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (item['timeSlot'] != null)
                Text(
                  item['timeSlot'],
                  style: const TextStyle(fontSize: 12, color: Color(0xFF4A90D9), fontWeight: FontWeight.w600),
                ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  item['title'] ?? '',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          if (item['description'] != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                item['description'],
                style: const TextStyle(fontSize: 12, color: KakaoTheme.secondary),
              ),
            ),
          const SizedBox(height: 4),
          Row(
            children: [
              if (item['transport'] != null) ...[
                const Icon(Icons.directions_walk, size: 12, color: KakaoTheme.secondary),
                const SizedBox(width: 2),
                Text(item['transport'], style: const TextStyle(fontSize: 11, color: KakaoTheme.secondary)),
              ],
              const Spacer(),
              if (costStr != null)
                Text(costStr, style: const TextStyle(fontSize: 11, color: Color(0xFF4A90D9), fontWeight: FontWeight.w500)),
            ],
          ),
        ],
      ),
    );
  }
}
