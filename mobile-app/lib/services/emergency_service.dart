import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_header_service.dart';

class EmergencyService {
  static const String _baseUrl = 'http://localhost:8000';

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
    final uri = Uri.parse('$_baseUrl/users/profile/me');

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

  static Future<List<String>> searchUsers({
    required String query,
    required String excludeUserId,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return <String>[];
    }

    final uri = Uri.parse('$_baseUrl/users/search').replace(
      queryParameters: {
        'q': trimmed,
        'exclude': excludeUserId,
      },
    );

    final authHeader = await AuthHeaderService.getAuthHeader();
    if (authHeader.isEmpty) {
      throw Exception('No authenticated user available for user search.');
    }

    final response = await http.get(
      uri,
      headers: {
        'Content-Type': 'application/json',
        ...authHeader,
      },
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Backend error ${response.statusCode}: ${response.body}');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) {
      final users = decoded['users'];
      if (users is List) {
        return users.map((item) => item.toString()).toList();
      }
    }
    if (decoded is List) {
      return decoded.map((item) => item.toString()).toList();
    }
    return <String>[];
  }

  static Future<List<String>> browseUsers({
    required String excludeUserId,
  }) async {
    final uri = Uri.parse('$_baseUrl/users').replace(
      queryParameters: {
        'exclude': excludeUserId,
      },
    );

    final authHeader = await AuthHeaderService.getAuthHeader();
    if (authHeader.isEmpty) {
      throw Exception('No authenticated user available for browsing users.');
    }

    final response = await http.get(
      uri,
      headers: {
        'Content-Type': 'application/json',
        ...authHeader,
      },
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Backend error ${response.statusCode}: ${response.body}');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) {
      final users = decoded['users'];
      if (users is List) {
        return users.map((item) => item.toString()).toList();
      }
    }
    if (decoded is List) {
      return decoded.map((item) => item.toString()).toList();
    }
    return <String>[];
  }

  static Future<Map<String, dynamic>> addContact({
    required String myUserId,
    required String contactId,
  }) async {
    final uri = Uri.parse('$_baseUrl/contacts/$myUserId/add');

    final authHeader = await AuthHeaderService.getAuthHeader();
    if (authHeader.isEmpty) {
      throw Exception('No authenticated user available for adding contact.');
    }

    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        ...authHeader,
      },
      body: jsonEncode({'contact_id': contactId}),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response.body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(response.body) as Map<String, dynamic>;
    }

    throw Exception('Backend error ${response.statusCode}: ${response.body}');
  }

  static Future<List<String>> getContacts({
    required String userId,
  }) async {
    final uri = Uri.parse('$_baseUrl/contacts/$userId');

    final authHeader = await AuthHeaderService.getAuthHeader();
    if (authHeader.isEmpty) {
      throw Exception('No authenticated user available for fetching contacts.');
    }

    final response = await http.get(
      uri,
      headers: {
        'Content-Type': 'application/json',
        ...authHeader,
      },
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Backend error ${response.statusCode}: ${response.body}');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) {
      final contacts = decoded['contacts'];
      if (contacts is List) {
        return contacts.map((item) => item.toString()).toList();
      }
    }
    if (decoded is List) {
      return decoded.map((item) => item.toString()).toList();
    }
    return <String>[];
  }
}