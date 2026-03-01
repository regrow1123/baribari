import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/api/chat_api.dart';
import '../../../../core/api/trips_api.dart';
import '../../domain/models.dart';

// ── Trip list ──
final tripListProvider = StateNotifierProvider<TripListNotifier, List<Trip>>(
  (ref) => TripListNotifier()..loadTrips(),
);

class TripListNotifier extends StateNotifier<List<Trip>> {
  TripListNotifier() : super([]);

  Future<void> loadTrips() async {
    try {
      final data = await TripsApi.listTrips();
      state = data.map((d) => Trip(
        id: d['id'],
        userId: d['user_id'] ?? 'dummy',
        title: d['title'] ?? '',
        destination: d['destination'],
        startDate: d['start_date'] != null ? DateTime.tryParse(d['start_date']) : null,
        endDate: d['end_date'] != null ? DateTime.tryParse(d['end_date']) : null,
        status: _parseStatus(d['status']),
        createdAt: DateTime.parse(d['created_at']),
        updatedAt: DateTime.parse(d['updated_at']),
      )).toList();
    } catch (e) {
      // If API fails, start with empty list
      state = [];
    }
  }

  Future<Trip> createTrip(String title, {String? destination}) async {
    try {
      final data = await TripsApi.createTrip(title: title, destination: destination);
      final trip = Trip(
        id: data['id'],
        userId: 'dummy',
        title: data['title'],
        destination: data['destination'],
        status: TripStatus.planning,
        createdAt: DateTime.parse(data['created_at']),
        updatedAt: DateTime.parse(data['updated_at']),
      );
      state = [trip, ...state];
      return trip;
    } catch (e) {
      // Fallback to local-only trip
      final trip = Trip(
        id: const Uuid().v4(),
        userId: 'dummy',
        title: title,
        destination: destination,
        status: TripStatus.planning,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      state = [trip, ...state];
      return trip;
    }
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

TripStatus _parseStatus(String? s) {
  switch (s) {
    case 'active': return TripStatus.active;
    case 'completed': return TripStatus.completed;
    default: return TripStatus.planning;
  }
}

final selectedTripIdProvider = StateProvider<String?>((ref) => null);

// ── Messages ──
final messagesProvider =
    StateNotifierProvider.family<MessagesNotifier, List<Message>, String>(
  (ref, tripId) => MessagesNotifier(tripId, ref)..loadMessages(),
);

class MessagesNotifier extends StateNotifier<List<Message>> {
  final String tripId;
  final Ref ref;

  MessagesNotifier(this.tripId, this.ref) : super([]);

  Future<void> loadMessages() async {
    try {
      final data = await TripsApi.listMessages(tripId);
      state = data.map((d) {
        final msgType = _parseMessageType(d['message_type']);
        return Message(
          id: d['id'],
          tripId: tripId,
          role: d['role'],
          content: d['content'] ?? '',
          messageType: msgType,
          metadata: d['metadata'] != null ? Map<String, dynamic>.from(d['metadata']) : null,
          createdAt: DateTime.parse(d['created_at']),
        );
      }).toList();
    } catch (e) {
      // Start with empty messages
    }
  }

  MessageType _parseMessageType(String? type) {
    switch (type) {
      case 'itinerary_card': return MessageType.itineraryCard;
      case 'packing_card': return MessageType.packingCard;
      case 'system': return MessageType.system;
      case 'file': return MessageType.file;
      default: return MessageType.text;
    }
  }

  void addMessage(Message message) {
    state = [...state, message];
  }

  Future<void> sendUserMessage(String content) async {
    final userMsg = Message(
      id: const Uuid().v4(),
      tripId: tripId,
      role: 'user',
      content: content,
      createdAt: DateTime.now(),
    );
    addMessage(userMsg);

    ref.read(isTypingProvider(tripId).notifier).state = true;

    try {
      final recentMessages = state.length > 20
          ? state.sublist(state.length - 20)
          : state;
      final history = recentMessages
          .where((m) => m.messageType == MessageType.text && m.role != 'system')
          .map((m) => {'role': m.role, 'content': m.content})
          .toList();

      final responseText = await ChatApi.sendMessage(
        message: content,
        history: history,
        tripId: tripId,
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

      // Plain text
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
