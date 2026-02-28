import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/kakao_theme.dart';
import '../../chat/domain/models.dart';
import '../../chat/presentation/providers/chat_provider.dart';

class TripListScreen extends ConsumerWidget {
  const TripListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trips = ref.watch(tripListProvider);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: KakaoTheme.headerBg,
        title: const Text('바리바리 ✈️', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Container(
        color: Colors.white,
        child: trips.isEmpty
            ? const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('🧳', style: TextStyle(fontSize: 48)),
                    SizedBox(height: 16),
                    Text('아직 여행이 없어요', style: TextStyle(fontSize: 16, color: KakaoTheme.secondary)),
                    Text('새로운 여행을 시작해보세요!', style: TextStyle(fontSize: 14, color: KakaoTheme.secondary)),
                  ],
                ),
              )
            : ListView.separated(
                itemCount: trips.length,
                separatorBuilder: (_, __) => const Divider(height: 1, indent: 76),
                itemBuilder: (context, index) {
                  final trip = trips[index];
                  return _TripTile(trip: trip);
                },
              ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: KakaoTheme.myBubble,
        onPressed: () {
          final newTrip = Trip(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            userId: 'dummy',
            title: '새 여행 계획 ✨',
            status: TripStatus.planning,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            lastMessage: null,
          );
          ref.read(tripListProvider.notifier).addTrip(newTrip);
          context.go('/chat/${newTrip.id}');
        },
        child: const Icon(Icons.add, color: KakaoTheme.primary),
      ),
    );
  }
}

class _TripTile extends StatelessWidget {
  final Trip trip;

  const _TripTile({required this.trip});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: () => context.go('/chat/${trip.id}'),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: CircleAvatar(
        radius: 24,
        backgroundColor: KakaoTheme.myBubble,
        child: Text(
          trip.destination != null ? _flag(trip.destination!) : '✈️',
          style: const TextStyle(fontSize: 20),
        ),
      ),
      title: Text(
        trip.title,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: trip.lastMessage != null
          ? Text(
              trip.lastMessage!,
              style: const TextStyle(fontSize: 13, color: KakaoTheme.secondary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            )
          : null,
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            _formatDate(trip.updatedAt),
            style: const TextStyle(fontSize: 11, color: KakaoTheme.secondary),
          ),
          const SizedBox(height: 4),
          _statusBadge(trip.status),
        ],
      ),
    );
  }

  String _flag(String destination) {
    if (destination.contains('Japan') || destination.contains('Tokyo')) return '🇯🇵';
    if (destination.contains('Thai') || destination.contains('Bangkok')) return '🇹🇭';
    if (destination.contains('Korea')) return '🇰🇷';
    if (destination.contains('USA') || destination.contains('America')) return '🇺🇸';
    return '✈️';
  }

  Widget _statusBadge(TripStatus status) {
    Color color;
    String label;
    switch (status) {
      case TripStatus.planning:
        color = const Color(0xFF4A90D9);
        label = '계획중';
      case TripStatus.active:
        color = const Color(0xFF48BB78);
        label = '진행중';
      case TripStatus.completed:
        color = KakaoTheme.secondary;
        label = '완료';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24) return '${diff.inHours}시간 전';
    if (diff.inDays < 7) return '${diff.inDays}일 전';
    return '${dt.month}/${dt.day}';
  }
}
