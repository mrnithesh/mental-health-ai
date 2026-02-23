import 'package:firebase_ai/firebase_ai.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class GeminiService {
  static const _textModel = 'gemini-2.5-flash';
  static const _liveModel = 'gemini-2.5-flash-native-audio-preview-12-2025';

  static const _systemInstruction = '''
You are MindfulAI, a compassionate and empathetic mental health companion.

Guidelines:
- Be warm, gentle, and non-judgmental in every response.
- Use active listening techniques: reflect feelings, validate emotions, ask open-ended questions.
- Offer evidence-based coping strategies when appropriate (breathing exercises, grounding techniques, cognitive reframing).
- Never diagnose, prescribe medication, or replace professional therapy.
- If someone expresses thoughts of self-harm or suicide, gently encourage them to contact a crisis helpline or mental health professional.
- Keep responses concise but meaningful - aim for 2-4 sentences unless the user needs more.
- Remember context from the conversation to provide personalized support.
''';

  late final GenerativeModel _chatModel;
  late final LiveGenerativeModel _voiceModel;

  GeminiService() {
    debugPrint('GeminiService: initializing with models $_textModel / $_liveModel');
    final ai = FirebaseAI.googleAI(auth: FirebaseAuth.instance);

    _chatModel = ai.generativeModel(
      model: _textModel,
      systemInstruction: Content.system(_systemInstruction),
    );

    _voiceModel = ai.liveGenerativeModel(
      model: _liveModel,
      systemInstruction: Content.system(_systemInstruction),
      liveGenerationConfig: LiveGenerationConfig(
        speechConfig: SpeechConfig(voiceName: 'Fenrir'),
        responseModalities: [ResponseModalities.audio],
        inputAudioTranscription: AudioTranscriptionConfig(),
        outputAudioTranscription: AudioTranscriptionConfig(),
      ),
    );
    debugPrint('GeminiService: initialized successfully');
  }

  ChatSession startChat() => _chatModel.startChat();

  Future<LiveSession> connectLive() => _voiceModel.connect();

  /// Quick health check: sends a trivial prompt to verify the API is reachable.
  Future<bool> isAvailable() async {
    try {
      final response = await _chatModel.generateContent([Content.text('hi')]);
      return response.text != null;
    } catch (e) {
      debugPrint('GeminiService health check failed: $e');
      return false;
    }
  }
}
