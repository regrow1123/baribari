import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class ChatApi {
  static const String _baseUrl = '';  // relative URL in production

  /// Sends a message and returns the full response text.
  /// For v1, we use non-streaming request and simulate typing on client side.
  static Future<String> sendMessage({
    required String message,
    required List<Map<String, String>> history,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/chat');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'message': message,
        'history': history,
      }),
    );

    if (response.statusCode != 200) {
      // Try to parse SSE response
      final lines = response.body.split('\n');
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
          } catch (_) {}
        }
      }
      if (buffer.isNotEmpty) return buffer.toString();
      throw Exception('API error: ${response.statusCode}');
    }

    // Parse SSE response
    final lines = response.body.split('\n');
    final buffer = StringBuffer();
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.startsWith('data: ')) {
        try {
          final data = jsonDecode(trimmed.substring(6)) as Map<String, dynamic>;
          if (data['type'] == 'text') {
            buffer.write(data['content']);
          }
        } catch (_) {}
      }
    }
    return buffer.toString();
  }

  /// Parse itinerary JSON from response text
  static Map<String, dynamic>? parseItinerary(String text) {
    return _parseJsonBlock(text, 'itinerary');
  }

  /// Parse packing JSON from response text
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

  /// Remove JSON blocks from text for display
  static String cleanText(String text) {
    return text
        .replaceAll(RegExp(r'```json:(itinerary|packing)\s*\n[\s\S]*?\n```'), '')
        .trim();
  }
}
