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

  Future<String?> _showLinkSheet(BuildContext context, Map<String, dynamic> metadata) async {
    final days = metadata['days'] as List? ?? [];
    final items = <Map<String, String>>[];

    for (final day in days) {
      final d = day as Map<String, dynamic>;
      final dayNum = d['day'] ?? 0;
      for (final item in (d['items'] as List? ?? [])) {
        final i = item as Map<String, dynamic>;
        items.add({
          'label': 'Day $dayNum - ${i['title'] ?? ''}',
          'timeSlot': i['timeSlot'] ?? '',
        });
      }
    }

    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  '📎 어떤 일정에 연결할까요?',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              const Divider(height: 1),
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.4),
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    ListTile(
                      leading: const Icon(Icons.link_off, color: Colors.grey),
                      title: const Text('연결 안함'),
                      onTap: () => Navigator.pop(ctx, null),
                    ),
                    ...items.map((item) => ListTile(
                      leading: const Icon(Icons.event, color: Color(0xFF4A90D9)),
                      title: Text(item['label']!),
                      subtitle: item['timeSlot']!.isNotEmpty ? Text(item['timeSlot']!) : null,
                      onTap: () => Navigator.pop(ctx, item['label']),
                    )),
                  ],
                ),
              ),
            ],
          ),
        );
      },
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
                    linkedItem: msg.metadata?['linkedItem'],
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
          onFilePick: (fileName, mimeType, size, bytes) async {
            // Get current itinerary items for linking
            final messages = ref.read(messagesProvider(widget.tripId));
            final itineraryMsg = messages.lastWhere(
              (m) => m.messageType == MessageType.itineraryCard && m.metadata != null,
              orElse: () => Message(id: '', tripId: '', role: '', content: '', createdAt: DateTime.now()),
            );

            String? linkedItem;
            if (itineraryMsg.id.isNotEmpty && itineraryMsg.metadata != null) {
              linkedItem = await _showLinkSheet(context, itineraryMsg.metadata!);
            }

            final msg = Message(
              id: const Uuid().v4(),
              tripId: widget.tripId,
              role: 'user',
              content: linkedItem != null ? '📎 $fileName → $linkedItem' : '📎 $fileName',
              messageType: MessageType.file,
              fileName: fileName,
              fileType: mimeType,
              fileSize: size,
              fileBytes: bytes,
              metadata: linkedItem != null ? {'linkedItem': linkedItem} : null,
              createdAt: DateTime.now(),
            );
            ref.read(messagesProvider(widget.tripId).notifier).addMessage(msg);
          },
        ),
      ],
    );
  }
}
