import 'dart:convert';
import 'package:http/http.dart' as http;

class ChatApi {
  static const String _baseUrl = '';

  static Future<String> sendMessage({
    required String message,
    required List<Map<String, String>> history,
    String? tripId,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/chat');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'message': message,
        'history': history,
        if (tripId != null) 'tripId': tripId,
      }),
    );

    // Decode body from bytes to ensure proper UTF-8
    final body = utf8.decode(response.bodyBytes);

    // Parse SSE response
    final lines = body.split('\n');
    final buffer = StringBuffer();
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.startsWith('data: ')) {
        try {
          final data = jsonDecode(trimmed.substring(6)) as Map<String, dynamic>;
          if (data['type'] == 'text') {
            buffer.write(data['content']);
          } else if (data['type'] == 'error') {
            throw Exception(data['content']);
          }
        } catch (e) {
          if (e is Exception && e.toString().contains('content')) rethrow;
        }
      }
    }

    final result = buffer.toString();
    if (result.isEmpty) {
      throw Exception('API error: ${response.statusCode} - $body');
    }
    return result;
  }

  static Map<String, dynamic>? parseItinerary(String text) {
    return _parseJsonBlock(text, 'itinerary');
  }

  static Map<String, dynamic>? parsePacking(String text) {
    return _parseJsonBlock(text, 'packing');
  }

  static Map<String, dynamic>? _parseJsonBlock(String text, String tag) {
    final pattern = RegExp(r'```json:' + tag + r'\s*\n([\s\S]*?)\n```');
    final match = pattern.firstMatch(text);
    if (match == null) return null;
    try {
      return jsonDecode(match.group(1)!) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  static String cleanText(String text) {
    return text
        .replaceAll(RegExp(r'```json:(itinerary|packing)\s*\n[\s\S]*?\n```'), '')
        .trim();
  }
}
