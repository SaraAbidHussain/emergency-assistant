import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_header_service.dart';

class EmergencyService {
  static const String _baseUrl = 'http://192.168.18.23:8000';

  static Map<String, dynamic> _parseEmergencyResponse(
    Map<String, dynamic> data,
  ) {
    return {
      'event_id': data['event_id'] as String,
      'timestamp': data['timestamp'] as String,
      'current_severity': data['current_severity'] as int,
      'level_label': data['level_label'] as String,
      'actions_taken': (data['actions_taken'] as List)
          .map((action) => action.toString())
          .toList(),
      'user_message': data['user_message'] as String,
      'contacts_notified': (data['contacts_notified'] as List)
          .map((contact) => contact.toString())
          .toList(),
      'nearby_help': (data['nearby_help'] as List)
          .map((help) => Map<String, dynamic>.from(help as Map))
          .toList(),
      'chat_available': data['chat_available'] as bool,
    };
  }

  static Map<String, dynamic> _emergencyFallback({
    required int? currentSeverity,
  }) {
    return {
      'event_id': 'offline-fallback',
      'timestamp': DateTime.now().toIso8601String(),
      'current_severity': currentSeverity,
      'level_label': 'minor',
      'actions_taken': <String>[],
      'user_message': 'Emergency services are temporarily unavailable.',
      'contacts_notified': <String>[],
      'nearby_help': <Map<String, dynamic>>[],
      'chat_available': true,
    };
  }

  static Future<Map<String, dynamic>> saveProfile({
    required String name,
    required String phone,
    required String bloodGroup,
    required DateTime dob,
  }) async {
    final uri = Uri.parse('$_baseUrl/profile');

    final authHeader = await AuthHeaderService.getAuthHeader();
    if (authHeader.isEmpty) {
      throw Exception('No authenticated user available for profile save.');
    }

    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        ...authHeader,
      },
      body: jsonEncode({
        'name': name,
        'phone': phone,
        'blood_group': bloodGroup,
        'dob': dob.toIso8601String().split('T').first,
      }),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response.body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(response.body) as Map<String, dynamic>;
    }

    throw Exception('Backend error ${response.statusCode}: ${response.body}');
  }

  static Future<Map<String, dynamic>> getProfile() async {
    final uri = Uri.parse('$_baseUrl/profile');

    final authHeader = await AuthHeaderService.getAuthHeader();
    if (authHeader.isEmpty) {
      throw Exception('No authenticated user available for profile retrieval.');
    }

    final response = await http.get(
      uri,
      headers: {
        'Content-Type': 'application/json',
        ...authHeader,
      },
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response.body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(response.body) as Map<String, dynamic>;
    }

    throw Exception('Backend error ${response.statusCode}: ${response.body}');
  }

  static Future<Map<String, dynamic>> triggerEmergency({
    required String userId,
    String description = 'Emergency SOS activated',
  }) async {
    final uri = Uri.parse('$_baseUrl/emergency/event');

    try {
      final authHeader = await AuthHeaderService.getAuthHeader();
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          ...authHeader,
        },
        body: jsonEncode({
          'user_id': userId,
          'type': 'trigger',
          'payload': {'description': description},
        }),
      );

      if (response.statusCode == 200) {
        return _parseEmergencyResponse(
          jsonDecode(response.body) as Map<String, dynamic>,
        );
      }

      throw Exception('Backend error ${response.statusCode}: ${response.body}');
    } catch (e) {
      print('triggerEmergency failed, using fallback: $e');
      return _emergencyFallback(currentSeverity: 2);
    }
  }

  static Future<Map<String, dynamic>> submitAnswer({
    required String userId,
    required String questionId,
    required String answer,
  }) async {
    final uri = Uri.parse('$_baseUrl/emergency/event');

    try {
      final authHeader = await AuthHeaderService.getAuthHeader();
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          ...authHeader,
        },
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
        return _parseEmergencyResponse(
          jsonDecode(response.body) as Map<String, dynamic>,
        );
      }

      throw Exception('Backend error ${response.statusCode}: ${response.body}');
    } catch (e) {
      print('submitAnswer failed, using fallback: $e');
      return _emergencyFallback(currentSeverity: null);
    }
  }

  static Future<Map<String, dynamic>> escalateEmergency({
    required String userId,
    required String reason,
  }) async {
    final uri = Uri.parse('$_baseUrl/emergency/$userId/escalate');

    try {
      final authHeader = await AuthHeaderService.getAuthHeader();
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          ...authHeader,
        },
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

  static Future<void> resolveEmergency({
    required String userId,
  }) async {
    final uri = Uri.parse('$_baseUrl/emergency/$userId/resolve');

    final authHeader = await AuthHeaderService.getAuthHeader();
    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        ...authHeader,
      },
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Resolve failed: ${response.statusCode}');
    }
  }

  static Future<Map<String, dynamic>> sendChatMessage({
    required String userId,
    required String message,
    required List<Map<String, dynamic>> conversationHistory,
  }) async {
    const fallbackReply =
        "Sorry, I'm having trouble responding right now. If this feels urgent, "
        'please use the SOS button or contact emergency services directly.';
    final uri = Uri.parse('$_baseUrl/emergency/chat');

    try {
      final authHeader = await AuthHeaderService.getAuthHeader();
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          ...authHeader,
        },
        body: jsonEncode({
          'user_id': userId,
          'message': message,
          'conversation_history': conversationHistory,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }

      throw Exception('Backend error ${response.statusCode}: ${response.body}');
    } catch (e) {
      print('sendChatMessage failed, using fallback: $e');
      return {'reply': fallbackReply};
    }
  }
}