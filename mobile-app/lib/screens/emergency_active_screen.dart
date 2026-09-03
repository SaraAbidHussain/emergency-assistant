import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/emergency_service.dart';
import '../utils/severity_helper.dart';

enum _QuestionStep { conscious, breathing, bleeding, done }

class EmergencyActiveScreen extends StatefulWidget {
  final int initialSeverity;

  /// Optional full `/emergency/event` response from the screen that
  /// triggered this one (e.g. the initial SOS trigger call). If null,
  /// the level-specific fields (user_message, nearby_help, etc.) will
  /// simply be empty until the first Q&A answer comes back.
  final Map<String, dynamic>? initialData;

  /// Called when the user confirms "I AM SAFE" at level 4. Hook this up
  /// to whatever should happen next (e.g. pop the screen, call a
  /// "resolve emergency" endpoint once the backend has one).
  final VoidCallback? onUserSafe;

  const EmergencyActiveScreen({
    super.key,
    required this.initialSeverity,
    this.initialData,
    this.onUserSafe,
  });

  @override
  State<EmergencyActiveScreen> createState() => _EmergencyActiveScreenState();
}

class _EmergencyActiveScreenState extends State<EmergencyActiveScreen> {
  late int _severity;
  int? _pendingDowngradeSeverity;

  String? _userMessage;
  String? _levelLabel;
  List<String> _actionsTaken = [];
  List<String> _contactsNotified = [];
  List<Map<String, dynamic>> _nearbyHelp = [];

  bool _locationSharedL2 = false;
  bool _iAmSafeArmed = false;
  Timer? _iAmSafeArmTimer;

  _QuestionStep _step = _QuestionStep.conscious;
  String? _finalMessage;

  Timer? _unresponsiveTimer;
  int _unresponsiveSecondsLeft = 10;
  bool _unresponsiveActive = true;
  bool _escalated = false;

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
    _iAmSafeArmTimer?.cancel();
    super.dispose();
  }

  // ---- seeding / applying backend data --------------------------------

  void _seedInitialData(Map<String, dynamic> data) {
    _userMessage = data['user_message'] as String?;
    _levelLabel = data['level_label'] as String?;
    _actionsTaken =
        ((data['actions_taken'] as List?) ?? []).map((e) => e.toString()).toList();
    _contactsNotified =
        ((data['contacts_notified'] as List?) ?? []).map((e) => e.toString()).toList();
    _nearbyHelp = ((data['nearby_help'] as List?) ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  /// Applies a fresh /emergency/event response. Content fields
  /// (message, contacts, nearby help) update immediately. The severity
  /// LEVEL (which drives the layout) never silently downgrades — if the
  /// backend reports a lower level than what's on screen, we stash it
  /// and ask for confirmation instead of switching the UI automatically.
  void _applyEventData(Map<String, dynamic> data) {
    final newSeverity = data['current_severity'] as int?;
    final userMessage = data['user_message'] as String?;
    final levelLabel = data['level_label'] as String?;
    final actionsTaken = data['actions_taken'] as List?;
    final contactsNotified = data['contacts_notified'] as List?;
    final nearbyHelpRaw = data['nearby_help'] as List?;

    setState(() {
      if (userMessage != null) _userMessage = userMessage;
      if (levelLabel != null) _levelLabel = levelLabel;
      if (actionsTaken != null) {
        _actionsTaken = actionsTaken.map((e) => e.toString()).toList();
      }
      if (contactsNotified != null) {
        _contactsNotified = contactsNotified.map((e) => e.toString()).toList();
      }
      if (nearbyHelpRaw != null) {
        _nearbyHelp = nearbyHelpRaw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }

      if (newSeverity != null && newSeverity != _severity) {
        if (newSeverity >= _severity) {
          _severity = newSeverity;
          _pendingDowngradeSeverity = null;
        } else {
          _pendingDowngradeSeverity = newSeverity;
        }
      }
    });
  }

  void _confirmDowngrade() {
    setState(() {
      if (_pendingDowngradeSeverity != null) {
        _severity = _pendingDowngradeSeverity!;
      }
      _pendingDowngradeSeverity = null;
    });
  }

  void _dismissDowngrade() {
    setState(() {
      _pendingDowngradeSeverity = null;
    });
  }

  // ---- unresponsive timer (unchanged behavior) -------------------------

  void _startUnresponsiveTimer() {
    _unresponsiveTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _unresponsiveSecondsLeft -= 1;
      });

      if (_unresponsiveSecondsLeft <= 0) {
        timer.cancel();
        _escalate();
      }
    });
  }

  void _cancelUnresponsiveTimer() {
    _unresponsiveTimer?.cancel();
    setState(() {
      _unresponsiveActive = false;
    });
  }

  Future<void> _escalate() async {
    final result = await EmergencyService.escalateEmergency(
      userId: 'sara-001',
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

  // ---- Q&A flow (unchanged aside from routing through _applyEventData) -

  Future<void> _answer(String questionId, String answer) async {
    if (_unresponsiveActive) {
      _cancelUnresponsiveTimer();
    }

    final result = await EmergencyService.submitAnswer(
      userId: 'sara-001',
      questionId: questionId,
      answer: answer,
    );

    if (!mounted) return;

    _applyEventData(result);

    setState(() {
      switch (questionId) {
        case 'conscious':
          _step = answer == 'No' ? _QuestionStep.breathing : _QuestionStep.bleeding;
          break;

        case 'breathing':
          if (answer == 'No' || answer == 'Unsure') {
            _finalMessage =
                'Not breathing normally. Escalating immediately — begin CPR if trained, and keep emergency services on the line.';
          } else {
            _finalMessage =
                'Breathing confirmed. Keep the person in the recovery position and monitor closely until help arrives.';
          }
          _step = _QuestionStep.done;
          break;

        case 'bleeding':
          if (answer == 'Yes') {
            _finalMessage =
                'Apply firm, direct pressure to the wound with a clean cloth. Keep the injured area raised above heart level if possible. If the cloth soaks through, add more on top — do not remove it.';
          } else {
            _finalMessage = 'No heavy bleeding detected. Keep the person still and monitor for any change.';
          }
          _step = _QuestionStep.done;
          break;
      }
    });
  }

  // ---- level 1: "message a friend" -------------------------------------

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

  // ---- level 2: opt-in location share ----------------------------------

  void _shareLocationOptIn() {
    // TODO: wire this up to the actual location-share endpoint once it
    // exists. For now this just flips local UI state so the user gets
    // clear feedback that their tap registered.
    setState(() => _locationSharedL2 = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Location sharing enabled.')),
    );
  }

  // ---- level 3: call a nearby hospital -----------------------------------

  Future<void> _callHospital(String? phone) async {
    if (phone == null || phone.isEmpty) return;
    final uri = Uri(scheme: 'tel', path: phone);
    final ok = await launchUrl(uri);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not start the call.')),
      );
    }
  }

  // ---- level 4: "I AM SAFE" double-tap confirm ---------------------------

  void _tapIAmSafe() {
    if (!_iAmSafeArmed) {
      setState(() => _iAmSafeArmed = true);
      _iAmSafeArmTimer?.cancel();
      _iAmSafeArmTimer = Timer(const Duration(seconds: 5), () {
        if (mounted) setState(() => _iAmSafeArmed = false);
      });
      return;
    }

    _iAmSafeArmTimer?.cancel();
    setState(() => _iAmSafeArmed = false);
    widget.onUserSafe?.call();
  }

  // ---- shared bits --------------------------------------------------

  Widget? _buildDowngradeBanner() {
    if (_pendingDowngradeSeverity == null) return null;
    final newLabel = severityLabel(_pendingDowngradeSeverity!);
    return Container(
      width: double.infinity,
      color: Colors.blueGrey.shade900,
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Text(
            'Backend reports a lower severity: $newLabel. Update the screen?',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(
                onPressed: _dismissDowngrade,
                child: const Text('Keep current', style: TextStyle(color: Colors.white70)),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: _confirmDowngrade,
                child: const Text('Update'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget? _buildUnresponsiveBanner() {
    if (_escalated) {
      return Container(
        width: double.infinity,
        color: Colors.red.shade900,
        padding: const EdgeInsets.all(16),
        child: const Text(
          'Escalating — contacts notified',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
        ),
      );
    }

    if (!_unresponsiveActive) return null;

    return Container(
      width: double.infinity,
      color: Colors.black87,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      child: Column(
        children: [
          Text(
            'Are you okay? Auto-escalating in $_unresponsiveSecondsLeft s',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 15),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _cancelUnresponsiveTimer,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
              textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            child: const Text("I'm OK"),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionArea() {
    switch (_step) {
      case _QuestionStep.conscious:
        return _QuestionCard(
          question: 'Is the person conscious?',
          options: const ['Yes', 'No'],
          onAnswer: (answer) => _answer('conscious', answer),
        );
      case _QuestionStep.breathing:
        return _QuestionCard(
          question: 'Is the person breathing normally?',
          options: const ['Yes', 'No', 'Unsure'],
          onAnswer: (answer) => _answer('breathing', answer),
        );
      case _QuestionStep.bleeding:
        return _QuestionCard(
          question: 'Is there heavy bleeding?',
          options: const ['Yes', 'No'],
          onAnswer: (answer) => _answer('bleeding', answer),
        );
      case _QuestionStep.done:
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _finalMessage ?? '',
            style: const TextStyle(fontSize: 18, height: 1.4),
            textAlign: TextAlign.center,
          ),
        );
    }
  }

  Widget _buildNearbyHelpList({bool withCallButton = false}) {
    if (_nearbyHelp.isEmpty) return const SizedBox.shrink();
    final items = _nearbyHelp.take(3).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items.map((place) {
        final name = place['name']?.toString() ?? 'Unknown';
        final distance = place['distance'];
        final address = place['address']?.toString() ?? '';
        final phone = place['phone']?.toString();

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text(
                      distance != null ? '$distance km · $address' : address,
                      style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                    ),
                  ],
                ),
              ),
              if (withCallButton && phone != null && phone.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.call),
                  onPressed: () => _callHospital(phone),
                ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildActionsTaken() {
  if (_actionsTaken.isEmpty) return const SizedBox.shrink();
  return Padding(
    padding: const EdgeInsets.only(top: 12),
    child: Wrap(
      spacing: 6,
      runSpacing: 6,
      children: _actionsTaken.map((action) {
        return Chip(
          label: Text(action, style: const TextStyle(fontSize: 12)),
          visualDensity: VisualDensity.compact,
          backgroundColor: Colors.white,
        );
      }).toList(),
    ),
  );
  }

  // ---- level-specific layouts -----------------------------------------

  Widget _buildLevel1() {
    return SingleChildScrollView(
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
                      _userMessage ?? "You've reported a minor situation.",
                      style: const TextStyle(fontSize: 16),
                    ),
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
    );
  }

  Widget _buildLevel2() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Card(
              color: severityBackground(2),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
  _userMessage ?? "This looks moderate — keep an eye on the situation.",
  style: const TextStyle(fontSize: 16),
),
_buildActionsTaken(),
                    if (_nearbyHelp.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      const Text('Nearby help:', style: TextStyle(fontWeight: FontWeight.w600)),
                      _buildNearbyHelpList(),
                    ],
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _locationSharedL2 ? null : _shareLocationOptIn,
                      icon: Icon(_locationSharedL2 ? Icons.check : Icons.share_location),
                      label: Text(_locationSharedL2 ? 'Location shared' : 'Share my location'),
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
    );
  }

  Widget _buildLevel3() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Card(
              color: severityBackground(3),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Emergency Mode Active',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: severityColor(3),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(_userMessage ?? '', style: const TextStyle(fontSize: 16)),
                    if (_contactsNotified.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text('Notified: ${_contactsNotified.join(", ")}'),
                    ],
                    if (_nearbyHelp.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      const Text('Nearby help:', style: TextStyle(fontWeight: FontWeight.w600)),
                      _buildNearbyHelpList(withCallButton: true),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildQuestionArea(),
          ],
        ),
      ),
    );
  }

  Widget _buildLevel4() {
    // Full-screen lock layout: minimal buttons only, Q&A paused.
    return Container(
      color: Colors.red.shade900,
      width: double.infinity,
      height: double.infinity,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 56),
              const SizedBox(height: 16),
              const Text(
                'CRITICAL EMERGENCY',
                style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              if (_userMessage != null)
                Text(
                  _userMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 15),
                ),
              const Spacer(),
              if (_contactsNotified.isNotEmpty) ...[
                Text(
                  'Notified: ${_contactsNotified.join(", ")}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 12),
              ],
              if (_nearbyHelp.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: _buildNearbyHelpListForLock(),
                ),
                const SizedBox(height: 24),
              ],
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _tapIAmSafe,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.red.shade900,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  child: Text(_iAmSafeArmed ? 'TAP AGAIN TO CONFIRM' : 'I AM SAFE'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Same list content as _buildNearbyHelpList but styled for the dark lock screen.
  Widget _buildNearbyHelpListForLock() {
    final items = _nearbyHelp.take(3).toList();
    return Column(
      children: items.map((place) {
        final name = place['name']?.toString() ?? 'Unknown';
        final distance = place['distance'];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(
            distance != null ? '$name — $distance km' : name,
            style: const TextStyle(color: Colors.white),
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Level 4 takes over the whole screen — no AppBar, no Q&A.
    if (_severity == 4) {
      return Scaffold(
        body: Stack(
          children: [
            _buildLevel4(),
            if (_buildDowngradeBanner() != null)
              Positioned(top: 0, left: 0, right: 0, child: _buildDowngradeBanner()!),
          ],
        ),
      );
    }

    final downgradeBanner = _buildDowngradeBanner();
    final unresponsiveBanner = _buildUnresponsiveBanner();

    Widget levelContent;
    switch (_severity) {
      case 1:
        levelContent = _buildLevel1();
        break;
      case 2:
        levelContent = _buildLevel2();
        break;
      case 3:
      default:
        levelContent = _buildLevel3();
        break;
    }

    return Scaffold(
      backgroundColor: severityBackground(_severity),
      appBar: AppBar(
        title: Text('Emergency — ${_levelLabel ?? severityLabel(_severity)}'),
        backgroundColor: severityColor(_severity),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (downgradeBanner != null) downgradeBanner,
            if (unresponsiveBanner != null) unresponsiveBanner,
            Expanded(child: levelContent),
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

  const _QuestionCard({
    required this.question,
    required this.options,
    required this.onAnswer,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            question,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: options.map((option) {
              return ElevatedButton(
                onPressed: () => onAnswer(option),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                child: Text(option),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}