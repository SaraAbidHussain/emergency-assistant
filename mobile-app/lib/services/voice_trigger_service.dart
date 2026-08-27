import 'package:speech_to_text/speech_to_text.dart' as stt;

class VoiceTriggerService {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isInitialized = false;
  bool _shouldKeepListening = false;
  void Function(String recognizedText)? _onTriggerPhraseDetected;

  static const List<String> triggerPhrases = ['help me', 'emergency', 'i need help'];

  Future<bool> initialize() async {
    _isInitialized = await _speech.initialize(
      onStatus: _handleStatus,
      onError: (error) => print('Speech error: $error'),
    );
    return _isInitialized;
  }

  void _handleStatus(String status) {
    if (_shouldKeepListening && (status == 'done' || status == 'notListening')) {
      _listenOnce();
    }
  }

  Future<void> startListening({
    required void Function(String recognizedText) onTriggerPhraseDetected,
  }) async {
    _onTriggerPhraseDetected = onTriggerPhraseDetected;
    _shouldKeepListening = true;

    if (!_isInitialized) {
      final ok = await initialize();
      if (!ok) return;
    }

    _listenOnce();
  }

  void _listenOnce() {
    _speech.listen(
      onResult: (result) {
        final text = result.recognizedWords.toLowerCase();
        for (final phrase in triggerPhrases) {
          if (text.contains(phrase)) {
            _onTriggerPhraseDetected?.call(result.recognizedWords);
            break;
          }
        }
      },
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 5),
      partialResults: true,
    );
  }

  Future<void> stopListening() async {
    _shouldKeepListening = false;
    await _speech.stop();
  }

  bool get isListening => _speech.isListening;
}