import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
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
}

final selectedTripIdProvider = StateProvider<String?>((ref) => null);

final messagesProvider =
    StateNotifierProvider.family<MessagesNotifier, List<Message>, String>(
  (ref, tripId) => MessagesNotifier(tripId),
);

class MessagesNotifier extends StateNotifier<List<Message>> {
  final String tripId;

  MessagesNotifier(this.tripId)
      : super(MockData.messages[tripId] ?? []);

  void addMessage(Message message) {
    state = [...state, message];
  }

  void sendUserMessage(String content) {
    final userMsg = Message(
      id: const Uuid().v4(),
      tripId: tripId,
      role: 'user',
      content: content,
      createdAt: DateTime.now(),
    );
    addMessage(userMsg);

    // Simulate assistant typing delay
    Future.delayed(const Duration(seconds: 1), () {
      final assistantMsg = Message(
        id: const Uuid().v4(),
        tripId: tripId,
        role: 'assistant',
        content: '네, 알겠어요! 확인해볼게요 😊',
        createdAt: DateTime.now(),
      );
      addMessage(assistantMsg);
    });
  }

  void togglePackingItem(String messageId, String categoryName, int itemIndex) {
    state = state.map((msg) {
      if (msg.id != messageId || msg.metadata == null) return msg;
      final meta = Map<String, dynamic>.from(msg.metadata!);
      final categories = (meta['categories'] as List).map((c) {
        final cat = Map<String, dynamic>.from(c);
        return cat;
      }).toList();
      return Message(
        id: msg.id,
        tripId: msg.tripId,
        role: msg.role,
        content: msg.content,
        messageType: msg.messageType,
        metadata: meta,
        createdAt: msg.createdAt,
      );
    }).toList();
  }
}

final isTypingProvider = StateProvider.family<bool, String>((ref, tripId) => false);
