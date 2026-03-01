import 'dart:convert';
import 'package:http/http.dart' as http;

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

  static Future<void> deleteTrip(String id) async {
    await http.delete(Uri.parse('$_apiBase/api/trips?id=$id'));
  }

  static Future<List<Map<String, dynamic>>> listMessages(String tripId) async {
    final res = await http.get(Uri.parse('$_apiBase/api/messages?tripId=$tripId'));
    if (res.statusCode != 200) throw Exception('Failed to load messages');
    return List<Map<String, dynamic>>.from(jsonDecode(res.body));
  }
}
