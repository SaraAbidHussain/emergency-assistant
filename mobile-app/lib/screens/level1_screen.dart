import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/emergency_service.dart';
import '../utils/severity_helper.dart';
import 'chat_screen.dart';
import 'emergency_active_screen.dart';
import 'level2_screen.dart';

class Level1Screen extends StatefulWidget {
  final int initialSeverity;
  final String userId;
  final Map<String, dynamic>? initialData;
  final VoidCallback? onUserSafe;

  const Level1Screen({
    super.key,
    required this.initialSeverity,
    required this.userId,
    this.initialData,
    this.onUserSafe,
  });

  @override
  State<Level1Screen> createState() => _Level1ScreenState();
}

class _Level1ScreenState extends State<Level1Screen> {
  late int _severity;
  String? _userMessage;
  String? _levelLabel;
  List<String> _actionsTaken = [];
  List<String> _contactsNotified = [];
  List<Map<String, dynamic>> _nearbyHelp = [];

  @override
  void initState() {
    super.initState();

    _severity = widget.initialSeverity;

    if (widget.initialData != null) {
      _seedInitialData(widget.initialData!);
    }
  }

  void _seedInitialData(Map<String, dynamic> data) {
    _userMessage = data['user_message'] as String?;
    _levelLabel = data['level_label'] as String?;

    _actionsTaken = ((data['actions_taken'] as List?) ?? [])
        .map((e) => e.toString())
        .toList();

    _contactsNotified = ((data['contacts_notified'] as List?) ?? [])
        .map((e) => e.toString())
        .toList();

    _nearbyHelp = ((data['nearby_help'] as List?) ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  void _applyEventData(Map<String, dynamic> data) {
    final levelLabel = data['level_label'] as String?;

    if (levelLabel != null && levelLabel != 'minor') {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => _screenForLevel(levelLabel, data),
        ),
      );
      return;
    }

    setState(() {
      if (data['user_message'] != null) {
        _userMessage = data['user_message'] as String;
      }

      if (levelLabel != null) {
        _levelLabel = levelLabel;
      }

      if (data['actions_taken'] != null) {
        _actionsTaken = (data['actions_taken'] as List)
            .map((e) => e.toString())
            .toList();
      }

      if (data['contacts_notified'] != null) {
        _contactsNotified = (data['contacts_notified'] as List)
            .map((e) => e.toString())
            .toList();
      }

      if (data['nearby_help'] != null) {
        _nearbyHelp = (data['nearby_help'] as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      }
    });
  }

  Widget _screenForLevel(String level, Map<String, dynamic> data) {
    final severity = data['current_severity'] as int? ?? 1;

    switch (level) {
      case 'moderate':
        return Level2Screen(
          initialSeverity: severity,
          userId: widget.userId,
          initialData: data,
          onUserSafe: widget.onUserSafe,
        );

      case 'serious':
      case 'critical':
        return EmergencyActiveScreen(
          initialSeverity: severity,
          userId: widget.userId,
          initialData: data,
          onUserSafe: widget.onUserSafe,
        );

      default:
        return Level1Screen(
          initialSeverity: severity,
          userId: widget.userId,
          initialData: data,
          onUserSafe: widget.onUserSafe,
        );
    }
  }

  Future<void> _messageAFriend() async {
    final uri = Uri(
      scheme: 'sms',
      queryParameters: {
        'body': _userMessage ??
            "I'm okay but wanted to let you know something happened. Checking in.",
      },
    );

    final ok = await launchUrl(uri);

    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open messaging app.'),
        ),
      );
    }
  }

  Future<void> _markSafe() async {
  try {
    await EmergencyService.resolveEmergency(
      userId: widget.userId,
    );

    if (!mounted) return;

    widget.onUserSafe?.call();
  } catch (_) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Unable to resolve the emergency. Please try again.',
        ),
      ),
    );
  }
}
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: severityBackground(1),
      appBar: AppBar(
        title: Text(
          'Emergency — ${_levelLabel ?? severityLabel(1)}',
        ),
        backgroundColor: severityColor(1),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Card(
                  color: severityBackground(1),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _userMessage ??
                              "You've reported a minor situation.",
                          style: const TextStyle(
                            fontSize: 16,
                            height: 1.4,
                          ),
                        ),

                        const SizedBox(height: 16),

                        if (_actionsTaken.isNotEmpty) ...[
                          const Text(
                            'What you can do:',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),

                          ..._actionsTaken.map(
                            (action) => Padding(
                              padding:
                                  const EdgeInsets.only(bottom: 6),
                              child: Row(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  const Text('• '),
                                  Expanded(
                                    child: Text(
                                      action,
                                      style: const TextStyle(
                                        fontSize: 15,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 12),
                        ],

                        OutlinedButton.icon(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ChatScreen(
                                userId: widget.userId,
                              ),
                            ),
                          ),
                          icon: const Icon(
                            Icons.chat_bubble_outline,
                          ),
                          label: const Text('Open Chat for Help'),
                        ),

                        const SizedBox(height: 12),

                        OutlinedButton.icon(
                          onPressed: _messageAFriend,
                          icon: const Icon(Icons.sms_outlined),
                          label: const Text('Message a friend'),
                        ),

                        const SizedBox(height: 16),

                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _markSafe,
                            child: const Text("I'm Safe"),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                if (_nearbyHelp.isNotEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Nearby Help',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 10),

                          ..._nearbyHelp.map(
                            (help) => ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(
                                Icons.location_on_outlined,
                              ),
                              title: Text(
                                help['name']?.toString() ??
                                    'Nearby help',
                              ),
                              subtitle: Text(
                                help['address']?.toString() ?? '',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}