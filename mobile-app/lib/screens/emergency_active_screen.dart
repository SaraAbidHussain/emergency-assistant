import 'dart:async';
import 'package:flutter/material.dart';
import '../services/emergency_service.dart';

enum _QuestionStep { conscious, breathing, bleeding, done }

class EmergencyActiveScreen extends StatefulWidget {
  final int initialSeverity;

  const EmergencyActiveScreen({super.key, required this.initialSeverity});

  @override
  State<EmergencyActiveScreen> createState() => _EmergencyActiveScreenState();
}

class _EmergencyActiveScreenState extends State<EmergencyActiveScreen> {
  late int _severity;
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
    _startUnresponsiveTimer();
  }

  @override
  void dispose() {
    _unresponsiveTimer?.cancel();
    super.dispose();
  }

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
    await EmergencyService.escalateEmergency(
      userId: 'sara-001',
      reason: 'No response within 10 seconds',
    );

    if (!mounted) return;

    setState(() {
      _unresponsiveActive = false;
      _escalated = true;
    });
  }

  Future<void> _answer(String questionId, String answer) async {
    if (_unresponsiveActive) {
      _cancelUnresponsiveTimer();
    }

    final result = await EmergencyService.submitAnswer(
      userId: 'sara-001',
      questionId: questionId,
      answer: answer,
    );

    final backendSeverity = result['current_severity'] as int?;

    setState(() {
      if (backendSeverity != null) {
        _severity = backendSeverity;
      }

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

  Color get _severityColor {
    switch (_severity) {
      case 1:
        return Colors.green;
      case 2:
        return Colors.amber.shade700;
      case 3:
        return Colors.orange;
      case 4:
      default:
        return Colors.red;
    }
  }

  Widget _buildBody() {
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

  @override
  Widget build(BuildContext context) {
    final unresponsiveBanner = _buildUnresponsiveBanner();

    return Scaffold(
      backgroundColor: Colors.red.shade50,
      appBar: AppBar(
        title: const Text('Emergency Active'),
        backgroundColor: Colors.red,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              color: _severityColor,
              child: Text(
                'SEVERITY LEVEL $_severity',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 1.5,
                ),
              ),
            ),
            if (unresponsiveBanner != null) unresponsiveBanner,
            Expanded(
              child: Center(child: _buildBody()),
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

  const _QuestionCard({
    required this.question,
    required this.options,
    required this.onAnswer,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
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