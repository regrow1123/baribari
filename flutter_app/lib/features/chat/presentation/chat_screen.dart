import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/kakao_theme.dart';
import '../domain/models.dart';
import 'providers/chat_provider.dart';
import 'package:uuid/uuid.dart';
import 'widgets/assistant_bubble.dart';
import 'widgets/file_bubble.dart';
import 'widgets/input_bar.dart';
import 'widgets/itinerary_card.dart';
import 'widgets/itinerary_tab.dart';
import 'widgets/packing_card.dart';
import 'widgets/packing_tab.dart';
import 'widgets/typing_indicator.dart';
import 'widgets/user_bubble.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String tripId;

  const ChatScreen({super.key, required this.tripId});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> with SingleTickerProviderStateMixin {
  final _scrollController = ScrollController();
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (_tabController.index == 0) _scrollToBottom();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _tabController.dispose();
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
    final trips = ref.watch(tripListProvider);
    final trip = trips.firstWhere((t) => t.id == widget.tripId);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: KakaoTheme.headerBg,
        leading: MediaQuery.of(context).size.width <= 768
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.go('/'),
              )
            : null,
        automaticallyImplyLeading: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(trip.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            if (trip.destination != null)
              Text(trip.destination!, style: const TextStyle(fontSize: 12, color: Colors.white70)),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: KakaoTheme.myBubble,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          tabs: const [
            Tab(text: '💬 대화'),
            Tab(text: '🗓️ 일정'),
            Tab(text: '🎒 준비물'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Chat
          _buildChatTab(),
          // Tab 2: Itinerary
          ItineraryTab(tripId: widget.tripId),
          // Tab 3: Packing
          PackingTab(tripId: widget.tripId),
        ],
      ),
    );
  }

  Widget _buildChatTab() {
    final messages = ref.watch(messagesProvider(widget.tripId));
    final isTyping = ref.watch(isTypingProvider(widget.tripId));

    ref.listen(messagesProvider(widget.tripId), (_, __) => _scrollToBottom());

    return Column(
      children: [
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

                if (msg.role == 'user' && msg.messageType == MessageType.file) {
                  return FileBubble(
                    fileName: msg.fileName ?? '',
                    fileType: msg.fileType ?? '',
                    fileSize: msg.fileSize ?? 0,
                    fileBytes: msg.fileBytes,
                    time: msg.createdAt,
                  );
                }

                if (msg.role == 'user') {
                  return UserBubble(content: msg.content, time: msg.createdAt);
                }

                switch (msg.messageType) {
                  case MessageType.itineraryCard:
                    return GestureDetector(
                      onTap: () => _tabController.animateTo(1),
                      child: Column(
                        children: [
                          ItineraryCard(metadata: msg.metadata!, time: msg.createdAt),
                          Padding(
                            padding: const EdgeInsets.only(left: 60, bottom: 8),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                '👆 탭하면 일정 탭에서 자세히 볼 수 있어요',
                                style: TextStyle(fontSize: 11, color: KakaoTheme.secondary.withValues(alpha: 0.7)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  case MessageType.packingCard:
                    return GestureDetector(
                      onTap: () => _tabController.animateTo(2),
                      child: Column(
                        children: [
                          PackingCard(metadata: msg.metadata!, time: msg.createdAt),
                          Padding(
                            padding: const EdgeInsets.only(left: 60, bottom: 8),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                '👆 탭하면 준비물 탭에서 자세히 볼 수 있어요',
                                style: TextStyle(fontSize: 11, color: KakaoTheme.secondary.withValues(alpha: 0.7)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  default:
                    return AssistantBubble(content: msg.content, time: msg.createdAt);
                }
              },
            ),
          ),
        ),
        InputBar(
          onSend: (text) {
            ref.read(messagesProvider(widget.tripId).notifier).sendUserMessage(text);
          },
          onFilePick: (fileName, mimeType, size, bytes) {
            final msg = Message(
              id: const Uuid().v4(),
              tripId: widget.tripId,
              role: 'user',
              content: '📎 $fileName',
              messageType: MessageType.file,
              fileName: fileName,
              fileType: mimeType,
              fileSize: size,
              fileBytes: bytes,
              createdAt: DateTime.now(),
            );
            ref.read(messagesProvider(widget.tripId).notifier).addMessage(msg);
          },
        ),
      ],
    );
  }
}
