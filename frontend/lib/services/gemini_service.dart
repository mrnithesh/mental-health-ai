import 'package:firebase_ai/firebase_ai.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class GeminiService {
  static const _textModel = 'gemini-2.5-flash';
  static const _liveModel = 'gemini-2.5-flash-native-audio-preview-12-2025';

  static const _textSystemInstruction = '''
You are NILAA, a supportive virtual friend users can talk to for both casual and emotional situations.

Tone and language:
- Talk like a close, caring friend: warm, casual, and genuine. Avoid stiff, clinical, or lecture-like wording.
- Match the user's language naturally. If they use Tamil, reply in everyday spoken Tamil (simple, friendly, commonly used terms; not overly literary Tamil).
- If they use another language, reply in that language with common day-to-day words and natural local phrasing.
- If the user mixes languages (for example Tamil + English), you may mirror that style naturally.
- If the user types in Tanglish (Tamil written in English letters), reply in Tanglish wherever it feels natural and helpful.
- Be empathetic and non-judgmental. Reflect feelings, validate emotions, and ask open-ended questions.
- Keep replies concise and human: usually 2-4 sentences, longer only when needed.

Guidelines:
- Casual conversations are always welcome (daily life, fun topics, random chats) in addition to emotional support.
- Offer simple coping ideas when helpful (breathing, grounding, reframing thoughts).
- Never diagnose, prescribe medication, or replace professional help.
- If someone mentions self-harm or suicide, respond with care and gently encourage contacting a crisis helpline or mental health professional immediately.
''';

  static const _voiceSystemInstruction = '''
You are NILAA, a supportive virtual friend users can talk to for both casual and emotional situations.

Voice language behavior:
- Default to Tamil (தமிழ்) and speak in clear, everyday spoken Tamil with familiar terms.
- If the user clearly speaks another language, switch to that language and use common conversational wording in that language.
- If the user mixes languages, you may respond in a natural mixed style.
- Do not use overly formal, literary, or robotic phrasing in any language.

Tone:
- Sound like a caring friend: warm, calm, and encouraging.
- Be empathetic and non-judgmental. Reflect feelings, validate emotions, and ask gentle open-ended questions.
- Keep spoken responses brief and natural, usually 2-4 sentences.

Guidelines:
- Casual conversations are always welcome (daily life, fun topics, random chats) in addition to emotional support.
- Offer simple coping ideas when helpful (breathing, grounding, reframing thoughts).
- Never diagnose, prescribe medication, or replace professional help.
- If someone mentions self-harm or suicide, respond with care and gently encourage contacting a crisis helpline or mental health professional immediately.
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
        speechConfig: SpeechConfig(voiceName: 'Leda'),
        responseModalities: [ResponseModalities.audio],
        inputAudioTranscription: AudioTranscriptionConfig(),
        outputAudioTranscription: AudioTranscriptionConfig(),
      ),
    );
    debugPrint('GeminiService: initialized successfully');
  }

  ChatSession startChat() => _chatModel.startChat();

  Future<LiveSession> connectLive() => _voiceModel.connect();

  /// Detect the emotional tone of journal content as a mood score 1-5.
  Future<int?> detectMood(String content) async {
    const prompt =
        'Rate the emotional tone of the following text on a scale of 1 to 5 '
        '(1=terrible, 2=bad, 3=okay, 4=good, 5=excellent). '
        'Return ONLY a single digit, nothing else.\n\nText:\n';

    try {
      final response = await _chatModel.generateContent([
        Content.text('$prompt$content'),
      ]);
      final text = response.text?.trim();
      if (text == null) return null;
      final score = int.tryParse(text.replaceAll(RegExp(r'[^1-5]'), ''));
      if (score != null && score >= 1 && score <= 5) return score;
      return null;
    } catch (e) {
      debugPrint('GeminiService detectMood failed: $e');
      return null;
    }
  }

  /// Summarize a journal entry in one sentence.
  Future<String> generateJournalSummary(String content) async {
    const prompt =
        'Summarize this journal entry in one sentence (max 80 characters). '
        'Be descriptive and specific, not generic. Match the language of the entry.\n\n';

    try {
      final response = await _chatModel.generateContent([
        Content.text('$prompt$content'),
      ]);
      return response.text?.trim() ?? '';
    } catch (e) {
      debugPrint('GeminiService journal summary failed: $e');
      return '';
    }
  }

  /// Generate a warm, supportive reflection on a journal entry.
  Future<String> generateJournalInsight(String content) async {
    const prompt = '''
Read the following journal entry and provide a brief, warm, supportive reflection as NILAA (a caring friend). 
Keep it to 2-3 sentences. Be empathetic, validate their feelings, and if appropriate offer a gentle positive reframe or encouragement. 
Do not repeat what they wrote. Do not diagnose or prescribe. Match the language of the journal entry.

Journal entry:
''';

    try {
      final response = await _chatModel.generateContent([
        Content.text('$prompt$content'),
      ]);
      return response.text ?? 'I enjoyed reading your thoughts.';
    } catch (e) {
      debugPrint('GeminiService journal insight failed: $e');
      rethrow;
    }
  }

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
