import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/kakao_theme.dart';
import '../domain/models.dart';
import 'providers/chat_provider.dart';
import 'widgets/assistant_bubble.dart';
import 'widgets/input_bar.dart';
import 'widgets/itinerary_card.dart';
import 'widgets/packing_card.dart';
import 'widgets/typing_indicator.dart';
import 'widgets/user_bubble.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String tripId;

  const ChatScreen({super.key, required this.tripId});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(messagesProvider(widget.tripId));
    final isTyping = ref.watch(isTypingProvider(widget.tripId));
    final trips = ref.watch(tripListProvider);
    final trip = trips.firstWhere((t) => t.id == widget.tripId);

    ref.listen(messagesProvider(widget.tripId), (_, __) => _scrollToBottom());

    return Scaffold(
      appBar: AppBar(
        backgroundColor: KakaoTheme.headerBg,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(trip.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            if (trip.destination != null)
              Text(trip.destination!, style: const TextStyle(fontSize: 12, color: Colors.white70)),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.search), onPressed: () {}),
          IconButton(icon: const Icon(Icons.menu), onPressed: () {}),
        ],
      ),
      body: Column(
        children: [
          // Messages
          Expanded(
            child: Container(
              color: KakaoTheme.background,
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(vertical: 16),
                itemCount: messages.length + (isTyping ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == messages.length && isTyping) {
                    return const TypingIndicator();
                  }

                  final msg = messages[index];

                  // System message
                  if (msg.messageType == MessageType.system) {
                    return Center(
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          msg.content,
                          style: const TextStyle(fontSize: 12, color: Colors.white),
                        ),
                      ),
                    );
                  }

                  // User message
                  if (msg.role == 'user') {
                    return UserBubble(content: msg.content, time: msg.createdAt);
                  }

                  // Assistant messages
                  switch (msg.messageType) {
                    case MessageType.itineraryCard:
                      return ItineraryCard(metadata: msg.metadata!, time: msg.createdAt);
                    case MessageType.packingCard:
                      return PackingCard(metadata: msg.metadata!, time: msg.createdAt);
                    default:
                      return AssistantBubble(content: msg.content, time: msg.createdAt);
                  }
                },
              ),
            ),
          ),
          // Input
          InputBar(
            onSend: (text) {
              ref.read(messagesProvider(widget.tripId).notifier).sendUserMessage(text);
            },
          ),
        ],
      ),
    );
  }
}
