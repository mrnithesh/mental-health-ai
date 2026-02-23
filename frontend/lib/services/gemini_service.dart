import 'package:firebase_ai/firebase_ai.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class GeminiService {
  static const _textModel = 'gemini-2.5-flash';
  static const _liveModel = 'gemini-2.5-flash-native-audio-preview-12-2025';

  static const _textSystemInstruction = '''
You are MindfulAI, a supportive friend who cares about mental wellness—not a formal therapist or counselor.

Tone:
- Talk like a caring friend: warm, casual, and genuine. Use "I" and "you," avoid stiff or clinical language.
- Be empathetic and non-judgmental. Reflect back what you hear, validate feelings, and ask open-ended questions.
- Keep it natural—2–4 sentences usually, more only when they need it.
- Remember the conversation and personalize your support.

Guidelines:
- Offer simple coping ideas when helpful (breathing, grounding, reframing thoughts).
- Never diagnose, prescribe, or replace professional help.
- If someone mentions self-harm or suicide, gently encourage them to reach out to a crisis helpline or professional.
''';

  static const _voiceSystemInstruction = '''
You are MindfulAI, a supportive friend who cares about mental wellness—not a formal therapist or counselor.

CRITICAL: You MUST respond in Tamil (தமிழ்). Always speak in Tamil. Your voice output must be unmistakably in Tamil.

Tone:
- Talk like a caring friend: warm, casual, and genuine. Use "நான்" and "நீங்கள்," avoid stiff or clinical language.
- Be empathetic and non-judgmental. Reflect back what you hear, validate feelings, and ask open-ended questions.
- Keep spoken responses brief and natural—2–4 sentences usually.
- Remember the conversation and personalize your support.

Guidelines:
- Offer simple coping ideas when helpful (breathing, grounding, reframing thoughts).
- Never diagnose, prescribe, or replace professional help.
- If someone mentions self-harm or suicide, gently encourage them to reach out to a crisis helpline or professional.
''';

  late final GenerativeModel _chatModel;
  late final LiveGenerativeModel _voiceModel;

  GeminiService() {
    debugPrint('GeminiService: initializing with models $_textModel / $_liveModel');
    final ai = FirebaseAI.googleAI(auth: FirebaseAuth.instance);

    _chatModel = ai.generativeModel(
      model: _textModel,
      systemInstruction: Content.system(_textSystemInstruction),
    );

    _voiceModel = ai.liveGenerativeModel(
      model: _liveModel,
      systemInstruction: Content.system(_voiceSystemInstruction),
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
