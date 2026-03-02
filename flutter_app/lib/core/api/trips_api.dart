import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class TripsApi {
  static const _baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  static String get _apiBase {
    if (_baseUrl.isNotEmpty) return _baseUrl;
    // Use relative URL (same origin) in production
    return '';
  }

  static Future<List<Map<String, dynamic>>> listTrips() async {
    final res = await http.get(Uri.parse('$_apiBase/api/trips'));
    if (res.statusCode != 200) throw Exception('Failed to load trips');
    return List<Map<String, dynamic>>.from(jsonDecode(res.body));
  }

  static Future<Map<String, dynamic>> createTrip({
    required String title,
    String? destination,
  }) async {
    final res = await http.post(
      Uri.parse('$_apiBase/api/trips'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'title': title,
        'destination': destination,
      }),
    );
    if (res.statusCode != 201) throw Exception('Failed to create trip');
    return Map<String, dynamic>.from(jsonDecode(res.body));
  }

  static Future<Map<String, dynamic>> updateTrip(String id, {String? title, String? destination}) async {
    final res = await http.put(
      Uri.parse('$_apiBase/api/trips?id=$id'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        if (title != null) 'title': title,
        if (destination != null) 'destination': destination,
      }),
    );
    if (res.statusCode != 200) throw Exception('Failed to update trip');
    return Map<String, dynamic>.from(jsonDecode(res.body));
  }

  static Future<String> autoTitle(String tripId, String userMessage, String? assistantMessage) async {
    final res = await http.post(
      Uri.parse('$_apiBase/api/auto-title'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'tripId': tripId,
        'userMessage': userMessage,
        'assistantMessage': assistantMessage,
      }),
    );
    if (res.statusCode != 200) throw Exception('Failed to generate title');
    return (jsonDecode(res.body) as Map)['title'] as String;
  }

  static Future<void> deleteTrip(String id) async {
    await http.delete(Uri.parse('$_apiBase/api/trips?id=$id'));
  }

  static Future<Map<String, dynamic>> uploadFile({
    required String tripId,
    required String fileName,
    required String mimeType,
    required Uint8List bytes,
    String? linkedItem,
    String? category,
  }) async {
    debugPrint('[uploadFile] starting: $fileName ($mimeType, ${bytes.length} bytes) trip=$tripId linked=$linkedItem cat=$category');
    try {
      final uri = Uri.parse('$_apiBase/api/upload-json');
      final res = await http.post(uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'tripId': tripId,
          'fileName': fileName,
          'mimeType': mimeType,
          'data': base64Encode(bytes),
          if (linkedItem != null) 'linkedItem': linkedItem,
          if (category != null) 'category': category,
        }),
      );
      debugPrint('[uploadFile] response: ${res.statusCode}');
      if (res.statusCode != 201) throw Exception('Upload failed: ${res.body}');
      return Map<String, dynamic>.from(jsonDecode(res.body));
    } catch (e) {
      debugPrint('[uploadFile] ERROR: $e');
      rethrow;
    }
  }

  static Future<List<Map<String, dynamic>>> listAttachments(String tripId) async {
    final res = await http.get(Uri.parse('$_apiBase/api/attachments?tripId=$tripId'));
    if (res.statusCode != 200) throw Exception('Failed to load attachments');
    return List<Map<String, dynamic>>.from(jsonDecode(res.body));
  }

  static Future<List<Map<String, dynamic>>> listExpenses(String tripId) async {
    final res = await http.get(Uri.parse('$_apiBase/api/expenses?tripId=$tripId'));
    if (res.statusCode != 200) throw Exception('Failed to load expenses');
    return List<Map<String, dynamic>>.from(jsonDecode(res.body));
  }

  static Future<Map<String, dynamic>> addExpense({
    required String tripId,
    required int amount,
    required String category,
    String? memo,
    String currency = 'KRW',
    int? dayNumber,
    String? linkedItem,
  }) async {
    final res = await http.post(
      Uri.parse('$_apiBase/api/expenses?tripId=$tripId'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'amount': amount,
        'category': category,
        'memo': memo,
        'currency': currency,
        if (dayNumber != null) 'dayNumber': dayNumber,
        if (linkedItem != null) 'linkedItem': linkedItem,
      }),
    );
    if (res.statusCode != 201) throw Exception('Failed to add expense');
    return Map<String, dynamic>.from(jsonDecode(res.body));
  }

  static Future<void> deleteExpense(String tripId, String expenseId) async {
    await http.delete(Uri.parse('$_apiBase/api/expenses?tripId=$tripId&id=$expenseId'));
  }

  static Future<List<Map<String, dynamic>>> listMessages(String tripId) async {
    final res = await http.get(Uri.parse('$_apiBase/api/messages?tripId=$tripId'));
    if (res.statusCode != 200) throw Exception('Failed to load messages');
    return List<Map<String, dynamic>>.from(jsonDecode(res.body));
  }

  static Future<void> postMessage({
    required String tripId,
    required String role,
    required String content,
    String? messageType,
    Map<String, dynamic>? metadata,
  }) async {
    await http.post(
      Uri.parse('$_apiBase/api/messages?tripId=$tripId'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'role': role,
        'content': content,
        if (messageType != null) 'message_type': messageType,
        if (metadata != null) 'metadata': metadata,
      }),
    );
  }
}
