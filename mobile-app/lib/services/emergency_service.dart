class EmergencyService {
  static Future<Map<String, dynamic>> triggerEmergency({required String userId}) async {
    final payload = {
      'user_id': userId,
      'type': 'trigger',
      'payload': {},
    };

    print('POST /emergency/event -> $payload');

    await Future.delayed(const Duration(milliseconds: 300));

    return {
      'event_id': 'mock-event-1',
      'timestamp': DateTime.now().toIso8601String(),
      'current_severity': 2,
    };
  }

  static Future<Map<String, dynamic>> submitAnswer({
    required String userId,
    required String questionId,
    required String answer,
  }) async {
    final payload = {
      'user_id': userId,
      'type': 'answer',
      'payload': {
        'question_id': questionId,
        'answer': answer,
      },
    };

    print('POST /emergency/event -> $payload');

    await Future.delayed(const Duration(milliseconds: 200));

    return {
      'event_id': 'mock-event-answer',
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  static Future<Map<String, dynamic>> escalateEmergency({
    required String userId,
    required String reason,
  }) async {
    final payload = {'reason': reason};

    print('POST /emergency/$userId/escalate -> $payload');

    await Future.delayed(const Duration(milliseconds: 300));

    return {
      'escalated': true,
      'contacts_notified': ['contact-1', 'contact-2'],
    };
  }
}