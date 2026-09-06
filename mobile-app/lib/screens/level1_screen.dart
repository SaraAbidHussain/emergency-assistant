import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/emergency_service.dart';
import '../utils/severity_helper.dart';
import 'chat_screen.dart';
import 'emergency_active_screen.dart';
import 'level2_screen.dart';

enum _QuestionStep { conscious, breathing, bleeding, done }

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
  _QuestionStep _step = _QuestionStep.conscious;
  String? _finalMessage;
  Timer? _unresponsiveTimer;
  int _unresponsiveSecondsLeft = 10;
  bool _unresponsiveActive = true;
  bool _escalated = false;
  bool _statusRequestInFlight = false;

  @override
  void initState() {
    super.initState();
    _severity = widget.initialSeverity;
    if (widget.initialData != null) {
      _seedInitialData(widget.initialData!);
    }
    _startUnresponsiveTimer();
  }

  @override
  void dispose() {
    _unresponsiveTimer?.cancel();
    super.dispose();
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
        MaterialPageRoute(builder: (_) => _screenForLevel(levelLabel, data)),
      );
      return;
    }

    setState(() {
      if (data['user_message'] != null) {
        _userMessage = data['user_message'] as String;
      }
      if (levelLabel != null) _levelLabel = levelLabel;
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

  void _startUnresponsiveTimer() {
    _unresponsiveTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() => _unresponsiveSecondsLeft -= 1);
      if (_unresponsiveSecondsLeft <= 0) {
        timer.cancel();
        _escalate();
      }
    });
  }

  void _cancelUnresponsiveTimer() {
    _unresponsiveTimer?.cancel();
    setState(() => _unresponsiveActive = false);
  }

  Future<void> _escalate() async {
    final result = await EmergencyService.escalateEmergency(
      userId: widget.userId,
      reason: 'No response within 10 seconds',
    );
    if (!mounted) return;
    setState(() {
      _unresponsiveActive = false;
      _escalated = true;
      final contacts = result['contacts_notified'] as List?;
      if (contacts != null) {
        _contactsNotified = contacts.map((e) => e.toString()).toList();
      }
    });
  }

  Future<void> _answer(String questionId, String answer) async {
    if (_unresponsiveActive) _cancelUnresponsiveTimer();
    final result = await EmergencyService.submitAnswer(
      userId: widget.userId,
      questionId: questionId,
      answer: answer,
    );
    if (!mounted) return;
    _applyEventData(result);
    if (!mounted || result['level_label'] != 'minor') return;
    setState(() {
      switch (questionId) {
        case 'conscious':
          _step = answer == 'No' ? _QuestionStep.breathing : _QuestionStep.bleeding;
          break;
        case 'breathing':
          _finalMessage = answer == 'No' || answer == 'Unsure'
              ? 'Not breathing normally. Escalating immediately — begin CPR if trained, and keep emergency services on the line.'
              : 'Breathing confirmed. Keep the person in the recovery position and monitor closely until help arrives.';
          _step = _QuestionStep.done;
          break;
        case 'bleeding':
          _finalMessage = answer == 'Yes'
              ? 'Apply firm, direct pressure to the wound with a clean cloth. Keep the injured area raised above heart level if possible. If the cloth soaks through, add more on top — do not remove it.'
              : 'No heavy bleeding detected. Keep the person still and monitor for any change.';
          _step = _QuestionStep.done;
          break;
      }
    });
  }

  Future<void> _submitStatus(String answer) async {
    if (_statusRequestInFlight) return;
    setState(() => _statusRequestInFlight = true);
    try {
      final result = await EmergencyService.submitAnswer(
        userId: widget.userId,
        questionId: 'status_check',
        answer: answer,
      );
      if (!mounted) return;
      if (result['event_id'] == 'offline-fallback') {
        throw Exception('Emergency services are unavailable');
      }
      _applyEventData(result);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to update your emergency status. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _statusRequestInFlight = false);
    }
  }

  Future<void> _messageAFriend() async {
    final uri = Uri(
      scheme: 'sms',
      queryParameters: {
        'body': _userMessage ?? "I'm okay but wanted to let you know something happened. Checking in.",
      },
    );
    final ok = await launchUrl(uri);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open messaging app.')),
      );
    }
  }

  Widget _buildQuestionArea() {
    switch (_step) {
      case _QuestionStep.conscious:
        return _QuestionCard(question: 'Is the person conscious?', options: const ['Yes', 'No'], onAnswer: (answer) => _answer('conscious', answer));
      case _QuestionStep.breathing:
        return _QuestionCard(question: 'Is the person breathing normally?', options: const ['Yes', 'No', 'Unsure'], onAnswer: (answer) => _answer('breathing', answer));
      case _QuestionStep.bleeding:
        return _QuestionCard(question: 'Is there heavy bleeding?', options: const ['Yes', 'No'], onAnswer: (answer) => _answer('bleeding', answer));
      case _QuestionStep.done:
        return Padding(padding: const EdgeInsets.all(24), child: Text(_finalMessage ?? '', style: const TextStyle(fontSize: 18, height: 1.4), textAlign: TextAlign.center));
    }
  }

  Widget _buildUnresponsiveBanner() {
    if (_escalated) {
      return Container(width: double.infinity, color: Colors.red.shade900, padding: const EdgeInsets.all(16), child: const Text('Escalating — contacts notified', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)));
    }
    if (!_unresponsiveActive) return const SizedBox.shrink();
    return Container(width: double.infinity, color: Colors.black87, padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16), child: Column(children: [Text('Are you okay? Auto-escalating in $_unresponsiveSecondsLeft s', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 15)), const SizedBox(height: 12), ElevatedButton(onPressed: _cancelUnresponsiveTimer, style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14), textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), child: const Text("I'm OK"))]));
  }

  Widget _buildActions() {
    return Row(children: [
      Expanded(child: ElevatedButton(onPressed: _statusRequestInFlight ? null : () => _submitStatus('safe'), child: _statusRequestInFlight ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text("I'm Safe"))),
      const SizedBox(width: 12),
      Expanded(child: ElevatedButton(onPressed: _statusRequestInFlight ? null : () => _submitStatus('still_need_help'), child: _statusRequestInFlight ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Still Need Help'))),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: severityBackground(1),
      appBar: AppBar(title: Text('Emergency — ${_levelLabel ?? severityLabel(1)}'), backgroundColor: severityColor(1), automaticallyImplyLeading: false),
      body: SafeArea(
        child: Column(
          children: [
            _buildUnresponsiveBanner(),
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Card(
                        key: ValueKey(Object.hash(
                          _severity,
                          Object.hashAll(_actionsTaken),
                          Object.hashAll(_contactsNotified),
                          Object.hashAll(_nearbyHelp),
                        )),
                        color: severityBackground(1),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _userMessage ?? "You've reported a minor situation.",
                                style: const TextStyle(fontSize: 16),
                              ),
                              const SizedBox(height: 12),
                              OutlinedButton.icon(
                                onPressed: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => ChatScreen(userId: widget.userId),
                                  ),
                                ),
                                icon: const Icon(Icons.chat_bubble_outline),
                                label: const Text('Open Chat for Help'),
                              ),
                              const SizedBox(height: 12),
                              _buildActions(),
                              const SizedBox(height: 12),
                              OutlinedButton.icon(
                                onPressed: _messageAFriend,
                                icon: const Icon(Icons.sms_outlined),
                                label: const Text('Message a friend'),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildQuestionArea(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuestionCard extends StatelessWidget {
  final String question;
  final List<String> options;
  final void Function(String answer) onAnswer;

  const _QuestionCard({required this.question, required this.options, required this.onAnswer});

  @override
  Widget build(BuildContext context) {
    return Padding(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16), child: Column(mainAxisSize: MainAxisSize.min, children: [
      Text(question, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
      const SizedBox(height: 32),
      Wrap(spacing: 12, runSpacing: 12, alignment: WrapAlignment.center, children: options.map((option) => ElevatedButton(onPressed: () => onAnswer(option), style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16), textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)), child: Text(option))).toList()),
    ]));
  }
}