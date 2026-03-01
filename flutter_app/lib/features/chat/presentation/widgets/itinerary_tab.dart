import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/kakao_theme.dart';
import '../../domain/models.dart';
import '../providers/chat_provider.dart';

class ItineraryTab extends ConsumerWidget {
  final String tripId;

  const ItineraryTab({super.key, required this.tripId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messages = ref.watch(messagesProvider(tripId));

    // Find the latest itinerary card message
    final itineraryMsg = messages.lastWhere(
      (m) => m.messageType == MessageType.itineraryCard && m.metadata != null,
      orElse: () => Message(
        id: '',
        tripId: tripId,
        role: 'assistant',
        content: '',
        createdAt: DateTime.now(),
      ),
    );

    if (itineraryMsg.id.isEmpty || itineraryMsg.metadata == null) {
      return const _EmptyState(
        icon: Icons.calendar_today,
        title: '아직 일정이 없어요',
        subtitle: '대화 탭에서 여행 일정을 요청해보세요!\n예: "도쿄 3박 4일 일정 짜줘"',
      );
    }

    final days = itineraryMsg.metadata!['days'] as List? ?? [];

    // Also find packing data for linking
    final packingMsg = messages.lastWhere(
      (m) => m.messageType == MessageType.packingCard && m.metadata != null,
      orElse: () => Message(
        id: '',
        tripId: tripId,
        role: 'assistant',
        content: '',
        createdAt: DateTime.now(),
      ),
    );

    return Container(
      color: const Color(0xFFF5F7FA),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: days.length,
        itemBuilder: (context, index) {
          final day = days[index] as Map<String, dynamic>;
          return _DayCard(
            day: day,
            dayIndex: index,
            packingMetadata: packingMsg.metadata,
          );
        },
      ),
    );
  }
}

class _DayCard extends StatelessWidget {
  final Map<String, dynamic> day;
  final int dayIndex;
  final Map<String, dynamic>? packingMetadata;

  const _DayCard({
    required this.day,
    required this.dayIndex,
    this.packingMetadata,
  });

  @override
  Widget build(BuildContext context) {
    final dayNum = day['day'] ?? dayIndex + 1;
    final date = day['date'] as String?;
    final items = day['items'] as List? ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Day header
        Padding(
          padding: EdgeInsets.only(bottom: 8, top: dayIndex > 0 ? 16 : 0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF4A90D9),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Day $dayNum',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              if (date != null) ...[
                const SizedBox(width: 10),
                Text(
                  date,
                  style: const TextStyle(
                    fontSize: 14,
                    color: KakaoTheme.secondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
              const Spacer(),
              _totalCost(items),
            ],
          ),
        ),
        // Items
        ...List.generate(items.length, (i) {
          final item = items[i] as Map<String, dynamic>;
          final isLast = i == items.length - 1;
          return _ItineraryItemTile(
            item: item,
            isLast: isLast,
            packingMetadata: packingMetadata,
          );
        }),
      ],
    );
  }

  Widget _totalCost(List items) {
    int total = 0;
    for (final item in items) {
      final cost = (item as Map<String, dynamic>)['estimatedCostKrw'] as int?;
      if (cost != null) total += cost;
    }
    if (total == 0) return const SizedBox.shrink();
    return Text(
      NumberFormat.currency(locale: 'ko_KR', symbol: '₩', decimalDigits: 0).format(total),
      style: const TextStyle(
        fontSize: 13,
        color: Color(0xFF4A90D9),
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _ItineraryItemTile extends StatelessWidget {
  final Map<String, dynamic> item;
  final bool isLast;
  final Map<String, dynamic>? packingMetadata;

  const _ItineraryItemTile({
    required this.item,
    required this.isLast,
    this.packingMetadata,
  });

  @override
  Widget build(BuildContext context) {
    final costKrw = item['estimatedCostKrw'] as int?;
    final costStr = costKrw != null && costKrw > 0
        ? NumberFormat.currency(locale: 'ko_KR', symbol: '₩', decimalDigits: 0).format(costKrw)
        : null;

    // Find related packing items based on item notes/title
    final relatedPacking = _findRelatedPacking(item);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline indicator
          SizedBox(
            width: 40,
            child: Column(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: const Color(0xFF4A90D9),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF4A90D9).withValues(alpha: 0.3),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: const Color(0xFF4A90D9).withValues(alpha: 0.2),
                    ),
                  ),
              ],
            ),
          ),
          // Content card
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
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
                  // Time + Title row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (item['timeSlot'] != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4A90D9).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            item['timeSlot'],
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF4A90D9),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      Expanded(
                        child: Text(
                          item['title'] ?? '',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: KakaoTheme.primary,
                          ),
                        ),
                      ),
                      if (costStr != null)
                        Text(
                          costStr,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF4A90D9),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                    ],
                  ),
                  // Description
                  if (item['description'] != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      item['description'],
                      style: const TextStyle(
                        fontSize: 13,
                        color: KakaoTheme.secondary,
                        height: 1.4,
                      ),
                    ),
                  ],
                  // Transport
                  if (item['transport'] != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.directions_transit, size: 14, color: KakaoTheme.secondary),
                        const SizedBox(width: 4),
                        Text(
                          item['transport'],
                          style: const TextStyle(fontSize: 12, color: KakaoTheme.secondary),
                        ),
                      ],
                    ),
                  ],
                  // Notes
                  if (item['notes'] != null) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: KakaoTheme.myBubble.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, size: 14, color: KakaoTheme.primary),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              item['notes'],
                              style: const TextStyle(fontSize: 12, color: KakaoTheme.primary),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  // Related packing items
                  if (relatedPacking.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    const Divider(height: 1),
                    const SizedBox(height: 8),
                    const Text(
                      '🎒 관련 준비물',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: KakaoTheme.primary),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: relatedPacking.map((name) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF48BB78).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFF48BB78).withValues(alpha: 0.3),
                            ),
                          ),
                          child: Text(
                            name,
                            style: const TextStyle(fontSize: 11, color: Color(0xFF48BB78)),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<String> _findRelatedPacking(Map<String, dynamic> item) {
    if (packingMetadata == null) return [];
    final categories = packingMetadata!['categories'] as List? ?? [];
    final title = (item['title'] as String? ?? '').toLowerCase();
    final notes = (item['notes'] as String? ?? '').toLowerCase();
    final description = (item['description'] as String? ?? '').toLowerCase();
    final combined = '$title $notes $description';

    // Keyword mapping for automatic linking
    final keywords = <String, List<String>>{
      '온천': ['수건', '세면도구'],
      '등산': ['등산화', '운동화', '물병'],
      '사찰': ['편한 신발'],
      '해산물': ['위장약', '소화제'],
      '시장': ['현금', '엔화'],
      '비행': ['여권', '항공권', '보조배터리'],
      '호텔': ['호텔 바우처', '잠옷'],
      '쇼핑': ['현금', '카드'],
    };

    final related = <String>{};
    for (final entry in keywords.entries) {
      if (combined.contains(entry.key)) {
        for (final packItem in entry.value) {
          // Check if this packing item actually exists in the list
          for (final cat in categories) {
            final items = (cat as Map)['items'] as List? ?? [];
            for (final pi in items) {
              if ((pi as String).contains(packItem)) {
                related.add(pi);
              }
            }
          }
        }
      }
    }
    return related.toList();
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 64, color: KakaoTheme.secondary.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: KakaoTheme.primary)),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: KakaoTheme.secondary, height: 1.5),
          ),
        ],
      ),
    );
  }
}
