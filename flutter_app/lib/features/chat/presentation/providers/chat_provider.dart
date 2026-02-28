import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/api/chat_api.dart';
import '../../data/mock_data.dart';
import '../../domain/models.dart';

final tripListProvider = StateNotifierProvider<TripListNotifier, List<Trip>>(
  (ref) => TripListNotifier(),
);

class TripListNotifier extends StateNotifier<List<Trip>> {
  TripListNotifier() : super(MockData.trips);

  void addTrip(Trip trip) {
    state = [trip, ...state];
  }

  void updateLastMessage(String tripId, String message) {
    state = state.map((t) {
      if (t.id == tripId) {
        return Trip(
          id: t.id,
          userId: t.userId,
          title: t.title,
          destination: t.destination,
          startDate: t.startDate,
          endDate: t.endDate,
          travelStyle: t.travelStyle,
          budgetKrw: t.budgetKrw,
          status: t.status,
          createdAt: t.createdAt,
          updatedAt: DateTime.now(),
          lastMessage: message,
        );
      }
      return t;
    }).toList();
  }
}

final selectedTripIdProvider = StateProvider<String?>((ref) => null);

final messagesProvider =
    StateNotifierProvider.family<MessagesNotifier, List<Message>, String>(
  (ref, tripId) => MessagesNotifier(tripId, ref),
);

class MessagesNotifier extends StateNotifier<List<Message>> {
  final String tripId;
  final Ref ref;

  MessagesNotifier(this.tripId, this.ref)
      : super(MockData.messages[tripId] ?? []);

  void addMessage(Message message) {
    state = [...state, message];
  }

  Future<void> sendUserMessage(String content) async {
    // Add user message
    final userMsg = Message(
      id: const Uuid().v4(),
      tripId: tripId,
      role: 'user',
      content: content,
      createdAt: DateTime.now(),
    );
    addMessage(userMsg);

    // Set typing indicator
    ref.read(isTypingProvider(tripId).notifier).state = true;

    try {
      // Build history from recent messages (last 20)
      final recentMessages = state.length > 20
          ? state.sublist(state.length - 20)
          : state;
      final history = recentMessages
          .where((m) => m.messageType == MessageType.text && m.role != 'system')
          .map((m) => {'role': m.role, 'content': m.content})
          .toList();

      // Call API
      final responseText = await ChatApi.sendMessage(
        message: content,
        history: history,
      );

      ref.read(isTypingProvider(tripId).notifier).state = false;

      // Check for itinerary JSON
      final itineraryData = ChatApi.parseItinerary(responseText);
      if (itineraryData != null) {
        final cleanText = ChatApi.cleanText(responseText);
        if (cleanText.isNotEmpty) {
          addMessage(Message(
            id: const Uuid().v4(),
            tripId: tripId,
            role: 'assistant',
            content: cleanText,
            createdAt: DateTime.now(),
          ));
        }
        addMessage(Message(
          id: const Uuid().v4(),
          tripId: tripId,
          role: 'assistant',
          content: '일정을 짜봤어요! 👇',
          messageType: MessageType.itineraryCard,
          metadata: itineraryData,
          createdAt: DateTime.now(),
        ));
        ref.read(tripListProvider.notifier).updateLastMessage(tripId, '일정을 짜봤어요! 🗓️');
        return;
      }

      // Check for packing JSON
      final packingData = ChatApi.parsePacking(responseText);
      if (packingData != null) {
        final cleanText = ChatApi.cleanText(responseText);
        if (cleanText.isNotEmpty) {
          addMessage(Message(
            id: const Uuid().v4(),
            tripId: tripId,
            role: 'assistant',
            content: cleanText,
            createdAt: DateTime.now(),
          ));
        }
        addMessage(Message(
          id: const Uuid().v4(),
          tripId: tripId,
          role: 'assistant',
          content: '준비물 리스트예요! 🎒',
          messageType: MessageType.packingCard,
          metadata: packingData,
          createdAt: DateTime.now(),
        ));
        ref.read(tripListProvider.notifier).updateLastMessage(tripId, '준비물 리스트예요! 🎒');
        return;
      }

      // Plain text response
      addMessage(Message(
        id: const Uuid().v4(),
        tripId: tripId,
        role: 'assistant',
        content: responseText,
        createdAt: DateTime.now(),
      ));
      ref.read(tripListProvider.notifier).updateLastMessage(
        tripId,
        responseText.length > 30 ? '${responseText.substring(0, 30)}...' : responseText,
      );
    } catch (e) {
      ref.read(isTypingProvider(tripId).notifier).state = false;
      addMessage(Message(
        id: const Uuid().v4(),
        tripId: tripId,
        role: 'assistant',
        content: '죄송해요, 오류가 발생했어요 😅\n다시 시도해주세요!\n\n(오류: $e)',
        createdAt: DateTime.now(),
      ));
    }
  }
}

final isTypingProvider = StateProvider.family<bool, String>((ref, tripId) => false);
