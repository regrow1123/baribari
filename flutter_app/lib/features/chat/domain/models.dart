enum TripStatus { planning, active, completed }

enum MessageType { text, itineraryCard, packingCard, system }

class Trip {
  final String id;
  final String userId;
  final String title;
  final String? destination;
  final DateTime? startDate;
  final DateTime? endDate;
  final List<String>? travelStyle;
  final int? budgetKrw;
  final TripStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? lastMessage;

  const Trip({
    required this.id,
    required this.userId,
    required this.title,
    this.destination,
    this.startDate,
    this.endDate,
    this.travelStyle,
    this.budgetKrw,
    this.status = TripStatus.planning,
    required this.createdAt,
    required this.updatedAt,
    this.lastMessage,
  });
}

class Message {
  final String id;
  final String tripId;
  final String role; // 'user' | 'assistant' | 'system'
  final String content;
  final MessageType messageType;
  final Map<String, dynamic>? metadata;
  final DateTime createdAt;

  const Message({
    required this.id,
    required this.tripId,
    required this.role,
    required this.content,
    this.messageType = MessageType.text,
    this.metadata,
    required this.createdAt,
  });
}

class ItineraryDay {
  final int day;
  final String? date;
  final List<ItineraryItem> items;

  const ItineraryDay({
    required this.day,
    this.date,
    required this.items,
  });
}

class ItineraryItem {
  final String title;
  final String? description;
  final String? location;
  final String? timeSlot;
  final String? transport;
  final int? estimatedCostKrw;
  final String? notes;

  const ItineraryItem({
    required this.title,
    this.description,
    this.location,
    this.timeSlot,
    this.transport,
    this.estimatedCostKrw,
    this.notes,
  });
}

class PackingCategory {
  final String name;
  final List<PackingItem> items;

  const PackingCategory({required this.name, required this.items});
}

class PackingItem {
  final String id;
  final String name;
  final String category;
  bool isChecked;

  PackingItem({
    required this.id,
    required this.name,
    required this.category,
    this.isChecked = false,
  });
}
