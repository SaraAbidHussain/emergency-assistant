import 'dart:async';

import 'package:flutter/material.dart';

import '../services/emergency_service.dart';
import 'emergency_active_screen.dart';
import 'level1_screen.dart';
import 'level2_screen.dart';

class EmergencyAssessmentScreen extends StatefulWidget {
  final String userId;

  const EmergencyAssessmentScreen({
    super.key,
    required this.userId,
  });

  @override
  State<EmergencyAssessmentScreen> createState() =>
      _EmergencyAssessmentScreenState();
}

class _EmergencyAssessmentScreenState
    extends State<EmergencyAssessmentScreen> {
  final TextEditingController _descriptionController =
      TextEditingController();

  Timer? _timer;

  int _secondsLeft = 10;

  bool _submitting = false;
  bool _escalated = false;

  int _currentQuestion = 0;

  final Map<String, String> _answers = {};

  final List<_AssessmentQuestion> _questions = const [
    _AssessmentQuestion(
      id: 'conscious',
      question: 'Is the person conscious?',
      options: ['Yes', 'No', 'Unsure'],
    ),
    _AssessmentQuestion(
      id: 'breathing',
      question: 'Is the person breathing normally?',
      options: ['Yes', 'No', 'Unsure'],
    ),
    _AssessmentQuestion(
      id: 'heavy_bleeding',
      question: 'Is there heavy bleeding?',
      options: ['Yes', 'No', 'Unsure'],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _descriptionController.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;

      setState(() {
        _secondsLeft--;
      });

      if (_secondsLeft <= 0) {
        timer.cancel();
        _autoEscalate();
      }
    });
  }

  void _stopTimer() {
    _timer?.cancel();

    if (mounted) {
      setState(() {
        _secondsLeft = 0;
      });
    }
  }

  void _userResponded() {
    if (_escalated) return;

    _timer?.cancel();

    // Restart a fresh 10-second window after each response.
    _secondsLeft = 10;

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;

      setState(() {
        _secondsLeft--;
      });

      if (_secondsLeft <= 0) {
        timer.cancel();
        _autoEscalate();
      }
    });
  }
  void _userStartedTyping() {
  if (_escalated || _submitting) return;

  // User is actively responding, so do not auto-escalate.
  _timer?.cancel();
}

  Future<void> _autoEscalate() async {
    if (_escalated || _submitting) return;

    _submitting = true;

    try {
      final result = await EmergencyService.escalateEmergency(
        userId: widget.userId,
        reason: 'No response during emergency assessment for 10 seconds',
      );

      if (!mounted) return;

      _escalated = true;
      _timer?.cancel();

      final contacts = (result['contacts_notified'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          <String>[];

      final data = <String, dynamic>{
        'event_id': 'auto-escalated',
        'timestamp': DateTime.now().toIso8601String(),
        'current_severity': 4,
        'level_label': 'critical',
        'actions_taken': <String>[
          'Emergency automatically escalated',
        ],
        'user_message':
            'No response was received during the emergency assessment.',
        'contacts_notified': contacts,
        'nearby_help': <Map<String, dynamic>>[],
        'chat_available': false,
      };

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => EmergencyActiveScreen(
            initialSeverity: 4,
            userId: widget.userId,
            initialData: data,
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;

      _submitting = false;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to contact the emergency backend. Please try again.',
          ),
        ),
      );
    }
  }

  void _selectAnswer(String answer) {
    if (_submitting || _escalated) return;

    _userResponded();

    final question = _questions[_currentQuestion];

    setState(() {
      _answers[question.id] = answer;

      if (_currentQuestion < _questions.length - 1) {
        _currentQuestion++;
      }
    });
  }

  Future<void> _submitAssessment() async {
    if (_submitting || _escalated) return;

    final description = _descriptionController.text.trim();

    if (_answers.isEmpty && description.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please answer at least one question or describe what happened.',
          ),
        ),
      );
      return;
    }

    _stopTimer();

    setState(() {
      _submitting = true;
    });

    try {
      final result = await EmergencyService.submitAssessment(
        userId: widget.userId,
        description: description,
        answers: _answers,
      );

      if (!mounted) return;

      _openLevel(result);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _submitting = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Assessment failed: $e'),
        ),
      );
    }
  }

  void _openLevel(Map<String, dynamic> data) {
    final severity = data['current_severity'] as int? ?? 1;
    final label = data['level_label']?.toString() ?? 'minor';

    Widget destination;

    switch (label) {
      case 'moderate':
        destination = Level2Screen(
          initialSeverity: severity,
          userId: widget.userId,
          initialData: data,
        );
        break;

      case 'serious':
      case 'critical':
        destination = EmergencyActiveScreen(
          initialSeverity: severity,
          userId: widget.userId,
          initialData: data,
        );
        break;

      case 'minor':
      default:
        destination = Level1Screen(
          initialSeverity: severity,
          userId: widget.userId,
          initialData: data,
        );
        break;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => destination,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final question = _questions[_currentQuestion];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Emergency Assessment'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              color: Colors.black87,
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              child: Text(
                'Please respond. Auto-escalating to Level 4 in $_secondsLeft s',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      size: 55,
                      color: Colors.red,
                    ),

                    const SizedBox(height: 12),

                    const Text(
                      'What happened?',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 8),

                    const Text(
                      'Answer the quick questions or describe the emergency below.',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.black54,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 28),

                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          children: [
                            Text(
                              question.question,
                              style: const TextStyle(
                                fontSize: 21,
                                fontWeight: FontWeight.w600,
                              ),
                              textAlign: TextAlign.center,
                            ),

                            const SizedBox(height: 20),

                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              alignment: WrapAlignment.center,
                              children: question.options.map((option) {
                                return ElevatedButton(
                                  onPressed: () => _selectAnswer(option),
                                  child: Text(option),
                                );
                              }).toList(),
                            ),

                            const SizedBox(height: 16),

                            Text(
                              'Question ${_currentQuestion + 1} of ${_questions.length}',
                              style: const TextStyle(
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Or describe the problem yourself',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    TextField(
                    controller: _descriptionController,
                    maxLines: 5,
                    onChanged: (_) {
                      _userStartedTyping();
                    },
                      decoration: InputDecoration(
                        hintText:
                            'Example: I fell from the stairs and my leg is bleeding badly.',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed:
                            _submitting ? null : _submitAssessment,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 17),
                        ),
                        child: _submitting
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'Submit Emergency Information',
                                style: TextStyle(fontSize: 17),
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
    );
  }
}

class _AssessmentQuestion {
  final String id;
  final String question;
  final List<String> options;

  const _AssessmentQuestion({
    required this.id,
    required this.question,
    required this.options,
  });
}