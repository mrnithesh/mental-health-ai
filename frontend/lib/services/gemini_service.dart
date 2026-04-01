import 'package:firebase_ai/firebase_ai.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class GeminiService {
  static const _textModel = 'gemini-2.5-flash';
  static const _liveModel = 'gemini-2.5-flash-native-audio-preview-12-2025';

  static String _buildTextInstruction(String personality, String userName) => '''
$personality

The user's name is $userName. You may use their name occasionally to feel personal, but don't overdo it.

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

  static String _buildVoiceInstruction(String personality, String userName) => '''
$personality

The user's name is $userName. You may use their name occasionally to feel personal.

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

  static const _defaultPersonality =
      'You are Nila — a warm, empathetic female companion who speaks gently like a caring older sister.';

  late GenerativeModel _chatModel;
  late LiveGenerativeModel _voiceModel;
  String _currentVoiceCode = 'Leda';
  String _currentPersonality = _defaultPersonality;
  String _currentUserName = 'Friend';
  String _currentVoiceName = 'Nila';

  String get activeVoiceName => _currentVoiceName;

  GeminiService() {
    debugPrint('GeminiService: initializing with models $_textModel / $_liveModel');
    final ai = FirebaseAI.googleAI(auth: FirebaseAuth.instance);

    _chatModel = ai.generativeModel(
      model: _textModel,
      systemInstruction: Content.system(
        _buildTextInstruction(_defaultPersonality, _currentUserName),
      ),
    );

    _voiceModel = _buildVoiceModel(ai, 'Leda');
    debugPrint('GeminiService: initialized successfully');
  }

  LiveGenerativeModel _buildVoiceModel(FirebaseAI ai, String voiceName) {
    return ai.liveGenerativeModel(
      model: _liveModel,
      systemInstruction: Content.system(
        _buildVoiceInstruction(_currentPersonality, _currentUserName),
      ),
      liveGenerationConfig: LiveGenerationConfig(
        speechConfig: SpeechConfig(voiceName: voiceName),
        responseModalities: [ResponseModalities.audio],
        inputAudioTranscription: AudioTranscriptionConfig(),
        outputAudioTranscription: AudioTranscriptionConfig(),
      ),
    );
  }

  void setVoice(String voiceCode, {String? personality, String? voiceName}) {
    final personalityChanged = personality != null && personality != _currentPersonality;
    final voiceChanged = voiceCode != _currentVoiceCode && voiceCode.isNotEmpty;

    if (personality != null) _currentPersonality = personality;
    if (voiceName != null) _currentVoiceName = voiceName;

    if (voiceChanged || personalityChanged) {
      if (voiceCode.isNotEmpty) _currentVoiceCode = voiceCode;
      final ai = FirebaseAI.googleAI(auth: FirebaseAuth.instance);
      _voiceModel = _buildVoiceModel(ai, _currentVoiceCode);
      debugPrint('GeminiService: voice=$_currentVoiceCode personality=$_currentVoiceName');
    }

    _rebuildChatModel();
  }

  void setUserName(String name) {
    if (name == _currentUserName || name.isEmpty) return;
    _currentUserName = name;
    _rebuildChatModel();
  }

  /// Play a short voice preview using Gemini Live API with the given voice.
  /// The caller must init and dispose the [audioOutput].
  Future<void> previewVoice({
    required String voiceCode,
    required String sampleText,
    required dynamic audioOutput,
    VoidCallback? onFirstAudio,
  }) async {
    final ai = FirebaseAI.googleAI(auth: FirebaseAuth.instance);
    final model = ai.liveGenerativeModel(
      model: _liveModel,
      systemInstruction: Content.system(
        'Say exactly what the user asks. Keep it natural and warm with a friendly Indian accent. Do not add anything extra.',
      ),
      liveGenerationConfig: LiveGenerationConfig(
        speechConfig: SpeechConfig(voiceName: voiceCode),
        responseModalities: [ResponseModalities.audio],
      ),
    );

    LiveSession? session;
    try {
      session = await model.connect();
      await session.send(
        input: Content.text('Say this exactly: $sampleText'),
        turnComplete: true,
      );

      await for (final response in session.receive()) {
        final message = response.message;
          if (message is LiveServerContent) {
          if (message.modelTurn != null) {
            for (final part in message.modelTurn!.parts) {
              if (part is InlineDataPart &&
                  part.mimeType.startsWith('audio')) {
                onFirstAudio?.call();
                onFirstAudio = null;
                audioOutput.addData(part.bytes);
              }
            }
          }
          if (message.turnComplete == true) break;
        }
      }
    } finally {
      try { await session?.close(); } catch (_) {}
    }
  }

  void resetForNewUser() {
    _currentUserName = 'Friend';
    _currentPersonality = _defaultPersonality;
    _currentVoiceName = 'Nila';
    _currentVoiceCode = 'Leda';
    _rebuildChatModel();
    final ai = FirebaseAI.googleAI(auth: FirebaseAuth.instance);
    _voiceModel = _buildVoiceModel(ai, 'Leda');
    debugPrint('GeminiService: reset for new user');
  }

  void _rebuildChatModel() {
    final ai = FirebaseAI.googleAI(auth: FirebaseAuth.instance);
    _chatModel = ai.generativeModel(
      model: _textModel,
      systemInstruction: Content.system(
        _buildTextInstruction(_currentPersonality, _currentUserName),
      ),
    );
  }

  ChatSession startChat({List<Content>? history}) =>
      _chatModel.startChat(history: history);

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
        'Write a one-line summary (max 80 chars) of this journal entry. '
        'Make it specific and personal, not generic. Use the same language as the entry '
        '(Tamil/English/Tanglish). It should read like a note-to-self, not a headline.\n\n';

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
    final prompt = '''
You are $_currentVoiceName, reading your friend's journal entry. Write a short, personal response — like a text message from a close friend who truly gets it.

Rules:
- Match their language exactly (Tamil, English, Tanglish — whatever they used). If they wrote in Tanglish, respond in Tanglish.
- 2-3 sentences max. Be real, not generic. Reference something specific they wrote.
- Don't repeat what they said back to them. Don't start with "I can see that..." or "It sounds like...".
- If they were being funny or casual, match that energy. If they were hurting, be gentle.
- No diagnosis, no advice unless it's very light ("maybe take a breather?" level). No therapist-speak.
- It should feel like a warm voice note, not a counseling session.

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

  /// Transform a chat/voice conversation into a first-person journal entry.
  /// Returns a record with title and body. Falls back to raw transcript on error.
  Future<({String title, String body})> summarizeConversation(
      String formattedTranscript) async {
    final prompt = '''
You are ghostwriting a personal journal entry for someone based on their conversation.

Read the conversation below carefully. Pay close attention to:
1. The LANGUAGE the user actually uses — if they speak in Tamil, write in Tamil. If they mix Tamil and English (Tanglish), write in that same mixed style. If pure English, write in English. Mirror their exact linguistic style, slang, and phrasing patterns.
2. The TONE — are they venting, reflecting, excited, sad, confused? Match that emotional register. Don't sanitize or formalize raw emotions.
3. The DEPTH — if the conversation was casual/light, keep the journal light. If it was deep and emotional, go deeper. Don't manufacture profundity that wasn't there.

Write a first-person journal entry as if $_currentUserName sat down and wrote it naturally — not a summary or report of the conversation, but their own thoughts flowing onto the page.

Rules:
- Use "I" voice throughout. Write like a real person thinks — messy, honest, with natural pauses and fragments if that matches their style.
- NEVER mention $_currentVoiceName, "AI", "chatbot", or "conversation". It should read like the person journaled independently.
- Weave in any realizations or reframes that came up, but make them feel self-discovered, not told.
- Keep it 150-250 words. Don't pad with generic reflection. Every sentence should carry meaning from the actual conversation.
- If the conversation had humor or lightness, keep that energy. Don't make everything heavy and "deep".

Return in this exact format:
TITLE: <a short, natural title in the user's language, max 60 chars — like something they'd name a note, not a newspaper headline>
---
<journal body>

Conversation:
''';

    try {
      final response = await _chatModel.generateContent([
        Content.text('$prompt$formattedTranscript'),
      ]);
      final text = response.text?.trim();
      if (text == null || text.isEmpty) {
        return _fallbackSummary(formattedTranscript);
      }

      final separatorIndex = text.indexOf('---');
      if (separatorIndex == -1) {
        return _fallbackSummary(formattedTranscript, body: text);
      }

      final titleSection = text.substring(0, separatorIndex).trim();
      final body = text.substring(separatorIndex + 3).trim();

      var title = titleSection;
      if (titleSection.toUpperCase().startsWith('TITLE:')) {
        title = titleSection.substring(6).trim();
      }

      if (title.isEmpty) title = _fallbackTitle();
      if (body.isEmpty) return _fallbackSummary(formattedTranscript);

      return (title: title, body: body);
    } catch (e) {
      debugPrint('GeminiService summarizeConversation failed: $e');
      return _fallbackSummary(formattedTranscript);
    }
  }

  ({String title, String body}) _fallbackSummary(String transcript,
      {String? body}) {
    return (
      title: _fallbackTitle(),
      body: body ?? transcript,
    );
  }

  String _fallbackTitle() {
    final now = DateTime.now();
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return 'Chat with $_currentVoiceName -- ${months[now.month - 1]} ${now.day}';
  }

  /// Summarize older messages to create a compact context for continuing a conversation.
  Future<String> summarizeForContext(String messageHistory) async {
    const prompt = '''
Summarize the key topics, emotions, and decisions from this conversation in 2-3 sentences. 
This summary will be used as context for continuing the conversation. Be concise and factual.
Focus on what the user shared, how they felt, and any conclusions reached.

Conversation:
''';

    try {
      final response = await _chatModel.generateContent([
        Content.text('$prompt$messageHistory'),
      ]);
      return response.text?.trim() ?? '';
    } catch (e) {
      debugPrint('GeminiService summarizeForContext failed: $e');
      return '';
    }
  }

  /// Generate a daily reflection/journaling prompt.
  Future<String> generateDailyPrompt() async {
    const prompt = '''
Generate a single, warm, thoughtful journaling prompt for today. 
It should be a reflective question that encourages self-awareness and is suitable for any mood.
Keep it under 15 words. Do not add quotes or prefixes. Just the question.
''';

    try {
      final response = await _chatModel.generateContent([
        Content.text(prompt),
      ]);
      return response.text?.trim() ?? 'What moment today are you most grateful for?';
    } catch (e) {
      debugPrint('GeminiService generateDailyPrompt failed: $e');
      return 'What moment today are you most grateful for?';
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
