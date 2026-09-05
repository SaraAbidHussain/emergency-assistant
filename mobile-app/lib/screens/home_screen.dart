import 'dart:async';
import 'package:flutter/material.dart';
import '../widgets/sos_button.dart';
import '../widgets/countdown_overlay.dart';
import '../widgets/pulsing_dot.dart';
import '../services/emergency_service.dart';
import '../services/voice_trigger_service.dart';
import '../models/user_model.dart';
import 'emergency_active_screen.dart';

class HomeScreen extends StatefulWidget {
  final UserModel currentUser;
  const HomeScreen({super.key, required this.currentUser});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _countingDown = false;
  int _secondsLeft = 3;
  Timer? _timer;
  String _pendingDescription = 'Emergency SOS activated';

  bool _voiceModeEnabled = false;
  final VoiceTriggerService _voiceService = VoiceTriggerService();

  @override
  void dispose() {
    _timer?.cancel();
    _voiceService.stopListening();
    super.dispose();
  }

  void _startCountdown() {
    if (_countingDown) return;

    setState(() {
      _countingDown = true;
      _secondsLeft = 3;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _secondsLeft -= 1;
      });

      if (_secondsLeft <= 0) {
        timer.cancel();
        setState(() {
          _countingDown = false;
        });
        _handleTrigger();
      }
    });
  }

  void _cancelCountdown() {
    _timer?.cancel();
    setState(() {
      _countingDown = false;
    });
  }

  Future<void> _handleTrigger() async {
    final result = await EmergencyService.triggerEmergency(
      userId: widget.currentUser.phoneNumber,
      description: _pendingDescription,
    );

    if (!mounted) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => EmergencyActiveScreen(
          initialSeverity: result['current_severity'] as int,
          userId: widget.currentUser.phoneNumber,
          onUserSafe: () => Navigator.of(context).pop(),
        ),
      ),
    );

    _pendingDescription = 'Emergency SOS activated';
  }

  Future<void> _toggleVoiceMode(bool enabled) async {
    setState(() {
      _voiceModeEnabled = enabled;
    });

    if (enabled) {
      await _voiceService.startListening(
        onTriggerPhraseDetected: (recognizedText) {
          if (!_countingDown) {
            _pendingDescription = recognizedText;
            _startCountdown();
          }
        },
      );
    } else {
      await _voiceService.stopListening();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12),
            color: Colors.grey.shade100,
            child: const Text(
              'Ready',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
                letterSpacing: 1.2,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_voiceModeEnabled) ...[
                  const PulsingDot(),
                  const SizedBox(width: 8),
                ],
                IconButton(
                  onPressed: () => _toggleVoiceMode(!_voiceModeEnabled),
                  icon: Icon(
                    _voiceModeEnabled ? Icons.mic : Icons.mic_off,
                    color: _voiceModeEnabled ? Colors.red : Colors.grey,
                  ),
                ),
                Text(
                  'Voice mode',
                  style: TextStyle(
                    color: _voiceModeEnabled ? Colors.red : Colors.grey.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Center(
              child: _countingDown
                  ? CountdownOverlay(secondsLeft: _secondsLeft, onCancel: _cancelCountdown)
                  : SosButton(onTap: _startCountdown),
            ),
          ),
        ],
      ),
    );
  }
}