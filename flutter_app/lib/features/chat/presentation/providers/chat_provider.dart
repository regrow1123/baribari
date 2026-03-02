import 'dart:convert';
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

  Future<void> deleteTrip(String tripId) async {
    try {
      await TripsApi.deleteTrip(tripId);
    } catch (_) {}
    state = state.where((t) => t.id != tripId).toList();
  }

  Future<void> updateTitle(String tripId, String title) async {
    try {
      await TripsApi.updateTrip(tripId, title: title);
    } catch (_) {}
    state = state.map((t) {
      if (t.id == tripId) {
        return Trip(
          id: t.id, userId: t.userId, title: title,
          destination: t.destination, startDate: t.startDate, endDate: t.endDate,
          travelStyle: t.travelStyle, budgetKrw: t.budgetKrw, status: t.status,
          createdAt: t.createdAt, updatedAt: DateTime.now(), lastMessage: t.lastMessage,
        );
      }
      return t;
    }).toList();
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
      // Load attachments to get URLs for file messages
      Map<String, String> fileUrlMap = {};
      try {
        final attachments = await TripsApi.listAttachments(tripId);
        for (final att in attachments) {
          final name = att['file_name'] as String?;
          final url = att['url'] as String?;
          if (name != null && url != null) {
            fileUrlMap[name] = url;
          }
        }
      } catch (_) {}

      state = data.map((d) {
        final msgType = _parseMessageType(d['message_type']);
        final meta = d['metadata'] != null ? Map<String, dynamic>.from(d['metadata']) : null;
        final fileName = msgType == MessageType.file ? (meta?['fileName'] as String?) : null;
        return Message(
          id: d['id'],
          tripId: tripId,
          role: d['role'],
          content: d['content'] ?? '',
          messageType: msgType,
          fileName: fileName,
          fileType: msgType == MessageType.file ? (meta?['fileType'] as String?) : null,
          fileSize: msgType == MessageType.file ? (meta?['fileSize'] as int?) : null,
          fileUrl: fileName != null ? fileUrlMap[fileName] : null,
          metadata: meta,
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

    // Check if this is the first user message (for auto-title)
    final isFirstMessage = state.where((m) => m.role == 'user').length <= 1;

    ref.read(isTypingProvider(tripId).notifier).state = true;

    try {
      final recentMessages = state.length > 20
          ? state.sublist(state.length - 20)
          : state;
      final history = recentMessages
          .where((m) => m.role != 'system' && m.messageType != MessageType.file)
          .map((m) {
            // For itinerary/packing cards, include the JSON in history so LLM knows the plan
            if (m.metadata != null && (m.messageType == MessageType.itineraryCard || m.messageType == MessageType.packingCard)) {
              final tag = m.messageType == MessageType.itineraryCard ? 'itinerary' : 'packing';
              final json = const JsonEncoder.withIndent(null).convert(m.metadata);
              return {'role': m.role, 'content': '${m.content}\n\`\`\`json:$tag\n$json\n\`\`\`'};
            }
            return {'role': m.role, 'content': m.content};
          })
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

      // Auto-generate title after first message
      if (isFirstMessage) {
        _autoGenerateTitle(content, responseText);
      }
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

  Future<void> _autoGenerateTitle(String userMessage, String assistantMessage) async {
    try {
      final title = await TripsApi.autoTitle(tripId, userMessage, assistantMessage);
      ref.read(tripListProvider.notifier).updateTitle(tripId, title);
    } catch (_) {}
  }
}

// ── Attachments from DB ──
final attachmentsProvider =
    StateNotifierProvider.family<AttachmentsNotifier, List<Map<String, dynamic>>, String>(
  (ref, tripId) => AttachmentsNotifier(tripId)..load(),
);

class AttachmentsNotifier extends StateNotifier<List<Map<String, dynamic>>> {
  final String tripId;
  AttachmentsNotifier(this.tripId) : super([]);

  Future<void> load() async {
    try {
      state = await TripsApi.listAttachments(tripId);
    } catch (_) {}
  }

  void addLocal(Map<String, dynamic> att) {
    state = [...state, att];
  }
}

// ── Expenses ──
final expensesProvider =
    StateNotifierProvider.family<ExpensesNotifier, List<Map<String, dynamic>>, String>(
  (ref, tripId) => ExpensesNotifier(tripId)..load(),
);

class ExpensesNotifier extends StateNotifier<List<Map<String, dynamic>>> {
  final String tripId;
  ExpensesNotifier(this.tripId) : super([]);

  Future<void> load() async {
    try {
      state = await TripsApi.listExpenses(tripId);
    } catch (_) {}
  }

  Future<void> add({required int amount, required String category, String? memo, int? dayNumber, String? linkedItem}) async {
    try {
      final data = await TripsApi.addExpense(tripId: tripId, amount: amount, category: category, memo: memo, dayNumber: dayNumber, linkedItem: linkedItem);
      state = [data, ...state];
    } catch (_) {}
  }

  Future<void> remove(String expenseId) async {
    try {
      await TripsApi.deleteExpense(tripId, expenseId);
      state = state.where((e) => e['id'] != expenseId).toList();
    } catch (_) {}
  }
}

final isTypingProvider = StateProvider.family<bool, String>((ref, tripId) => false);
