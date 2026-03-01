import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/kakao_theme.dart';
import '../../chat/domain/models.dart';
import '../../chat/presentation/providers/chat_provider.dart';

class ResponsiveShell extends ConsumerWidget {
  final Widget child;

  const ResponsiveShell({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isWide = MediaQuery.of(context).size.width > 768;

    if (!isWide) return child;

    // Desktop layout: sidebar + content
    final trips = ref.watch(tripListProvider);
    final selectedId = ref.watch(selectedTripIdProvider);

    return Scaffold(
      body: Row(
        children: [
          // Sidebar
          SizedBox(
            width: 320,
            child: Column(
              children: [
                // Sidebar header
                Container(
                  height: 56,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  color: KakaoTheme.headerBg,
                  child: Row(
                    children: [
                      const Text(
                        '바리바리 ✈️',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.add, color: Colors.white),
                        onPressed: () async {
                          final trip = await ref.read(tripListProvider.notifier).createTrip('새 여행 계획 ✨');
                          ref.read(selectedTripIdProvider.notifier).state = trip.id;
                          if (context.mounted) context.go('/chat/${trip.id}');
                        },
                      ),
                    ],
                  ),
                ),
                // Trip list
                Expanded(
                  child: Container(
                    color: Colors.white,
                    child: ListView.separated(
                      itemCount: trips.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, indent: 76),
                      itemBuilder: (context, index) {
                        final trip = trips[index];
                        final isSelected = trip.id == selectedId;
                        return ListTile(
                          selected: isSelected,
                          selectedTileColor: const Color(0xFFF0F4F8),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          leading: CircleAvatar(
                            radius: 22,
                            backgroundColor: KakaoTheme.myBubble,
                            child: Text(_flag(trip.destination), style: const TextStyle(fontSize: 18)),
                          ),
                          title: Text(
                            trip.title,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: trip.lastMessage != null
                              ? Text(
                                  trip.lastMessage!,
                                  style: const TextStyle(fontSize: 12, color: KakaoTheme.secondary),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                )
                              : null,
                          onTap: () {
                            ref.read(selectedTripIdProvider.notifier).state = trip.id;
                            context.go('/chat/${trip.id}');
                          },
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Divider
          Container(width: 1, color: KakaoTheme.divider),
          // Content
          Expanded(child: child),
        ],
      ),
    );
  }

  String _flag(String? destination) {
    if (destination == null) return '✈️';
    if (destination.contains('Japan') || destination.contains('Tokyo')) return '🇯🇵';
    if (destination.contains('Thai') || destination.contains('Bangkok')) return '🇹🇭';
    return '✈️';
  }
}
