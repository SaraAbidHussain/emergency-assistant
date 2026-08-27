import 'dart:convert';
import 'package:http/http.dart' as http;

class EmergencyService {
  static const String _baseUrl = 'http://localhost:8000';

  static Future<Map<String, dynamic>> triggerEmergency({
    required String userId,
    String description = 'Emergency SOS activated',
  }) async {
    final uri = Uri.parse('$_baseUrl/emergency/event');

    try {
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': userId,
          'type': 'trigger',
          'payload': {'description': description},
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }

      throw Exception('Backend error ${response.statusCode}: ${response.body}');
    } catch (e) {
      print('triggerEmergency failed, using fallback: $e');
      return {
        'event_id': 'offline-fallback',
        'timestamp': DateTime.now().toIso8601String(),
        'current_severity': 2,
      };
    }
  }

  static Future<Map<String, dynamic>> submitAnswer({
    required String userId,
    required String questionId,
    required String answer,
  }) async {
    final uri = Uri.parse('$_baseUrl/emergency/event');

    try {
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': userId,
          'type': 'answer',
          'payload': {
            'question_id': questionId,
            'answer': answer,
          },
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }

      throw Exception('Backend error ${response.statusCode}: ${response.body}');
    } catch (e) {
      print('submitAnswer failed, using fallback: $e');
      return {
        'event_id': 'offline-fallback',
        'timestamp': DateTime.now().toIso8601String(),
        'current_severity': null,
      };
    }
  }

  static Future<Map<String, dynamic>> escalateEmergency({
    required String userId,
    required String reason,
  }) async {
    final uri = Uri.parse('$_baseUrl/emergency/$userId/escalate');

    try {
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'reason': reason}),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }

      throw Exception('Backend error ${response.statusCode}: ${response.body}');
    } catch (e) {
      print('escalateEmergency failed, using fallback: $e');
      return {
        'escalated': true,
        'contacts_notified': <String>[],
      };
    }
  }
}