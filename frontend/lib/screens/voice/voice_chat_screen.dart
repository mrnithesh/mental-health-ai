import 'dart:async';
import 'dart:ui';

import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

import '../../config/routes.dart';
import '../../config/theme.dart';
import '../../providers/service_providers.dart';
import '../../providers/voice_provider.dart';
import '../../utils/audio_output.dart';
import '../journal/journal_editor_screen.dart' show JournalEditorArgs;

enum VoiceState { idle, connecting, listening, speaking, error }

class VoiceChatScreen extends ConsumerStatefulWidget {
  final bool journalMode;

  const VoiceChatScreen({super.key, this.journalMode = false});

  @override
  ConsumerState<VoiceChatScreen> createState() => _VoiceChatScreenState();
}

class _VoiceChatScreenState extends ConsumerState<VoiceChatScreen>
    with TickerProviderStateMixin {
  VoiceState _state = VoiceState.idle;
  final List<_TranscriptMessage> _transcript = [];
  String? _errorMessage;
  bool _savedAsJournal = false;
  bool _isSummarizing = false;
  bool _isMuted = false;
  LiveSession? _session;
  AudioRecorder? _recorder;
  final AudioOutput _audioOutput = AudioOutput();
  StreamSubscription? _recordSubscription;
  Timer? _durationTimer;
  Duration _sessionDuration = Duration.zero;

  late AnimationController _pulseController;
  late AnimationController _waveController;
  late AnimationController _breatheController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _breatheAnimation;

  // Index of the transcript message currently being appended to for each speaker.
  // Set to null when that speaker's utterance has finished, so the next chunk
  // from the same speaker always creates a brand-new message bubble.
  int? _currentUserMessageIndex;
  int? _currentAIMessageIndex;

  // Whether the most recent utterance for each speaker has been marked finished.
  // Starts true so the very first chunk always creates a new message.
  bool _userUtteranceFinished = true;
  bool _aiUtteranceFinished = true;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.12).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _waveController = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    )..repeat();

    _breatheController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    )..repeat(reverse: true);

    _breatheAnimation = Tween<double>(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(parent: _breatheController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _waveController.dispose();
    _breatheController.dispose();
    _durationTimer?.cancel();
    _durationTimer = null;
    _disconnect();
    _audioOutput.dispose();
    super.dispose();
  }

  Future<bool> _requestMicPermission() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  Future<void> _onMicTap() async {
    switch (_state) {
      case VoiceState.idle:
      case VoiceState.error:
        await _connect();
        break;
      case VoiceState.listening:
      case VoiceState.speaking:
        await _disconnect();
        break;
      case VoiceState.connecting:
        break;
    }
  }

  Future<void> _connect() async {
    debugPrint('[VOICE] ═══════════════════════════════════════');
    debugPrint('[VOICE] 🎤 STARTING VOICE CHAT SESSION');
    debugPrint('[VOICE] ═══════════════════════════════════════');

    final hasPermission = await _requestMicPermission();
    if (!hasPermission) {
      debugPrint('[VOICE] ❌ Microphone permission denied');
      setState(() {
        _state = VoiceState.error;
        _errorMessage = 'Microphone permission is required for voice chat';
      });
      return;
    }

    debugPrint('[VOICE] ✅ Microphone permission granted');
    setState(() {
      _state = VoiceState.connecting;
      _errorMessage = null;
      _sessionDuration = Duration.zero;
      _transcript.clear();
      // Reset all transcription tracking state for the new session
      _currentUserMessageIndex = null;
      _currentAIMessageIndex = null;
      _userUtteranceFinished = true;
      _aiUtteranceFinished = true;
    });

    try {
      debugPrint('[VOICE] Initializing audio output...');
      await _audioOutput.init();
      await _audioOutput.playStream();
      debugPrint('[VOICE] ✅ Audio output initialized');

      debugPrint('[VOICE] Connecting to Gemini Live API...');
      final geminiService = ref.read(geminiServiceProvider);
      _session = await geminiService.connectLive();
      debugPrint('[VOICE] ✅ Connected to Gemini Live API');

      // Start duration timer
      _durationTimer?.cancel();
      _durationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() {
          _sessionDuration = Duration(seconds: timer.tick);
        });
      });

      debugPrint('[VOICE] Starting receive and record handlers...');
      unawaited(_startReceiving());
      await _startRecording();

      debugPrint('[VOICE] ✅ Session ready - waiting for user input');
      setState(() {
        _state = VoiceState.listening;
        ref.read(voiceSessionActiveProvider.notifier).state = true;
      });
    } catch (e, stack) {
      debugPrint('[VOICE] ❌ Connection error: $e');
      debugPrint('[VOICE] Stack trace: $stack');
      ref.read(voiceSessionActiveProvider.notifier).state = false;
      setState(() {
        _state = VoiceState.error;
        _errorMessage =
            '${e.toString()}\n\nMake sure Firebase AI Logic (Gemini API) is enabled in your Firebase Console.';
      });
    }
  }

  Future<void> _startRecording() async {
    try {
      if (_recorder != null) {
        if (await _recorder!.isRecording()) {
          await _recorder!.stop();
        }
        _recorder!.dispose();
      }
    } catch (e) {
      debugPrint('Error cleaning up old recorder: $e');
    }
    _recorder = AudioRecorder();

    final stream = await _recorder!.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 16000,
        numChannels: 1,
        echoCancel: true,
        noiseSuppress: true,
        androidConfig: AndroidRecordConfig(
          audioSource: AndroidAudioSource.voiceCommunication,
        ),
        iosConfig: IosRecordConfig(categoryOptions: []),
      ),
    );

    debugPrint('[VOICE] Recording started, streaming audio to Gemini...');
    _recordSubscription = stream.listen(
      (data) {
        if (_session != null && !_isMuted) {
          debugPrint('[VOICE] Sending audio chunk: ${data.length} bytes');
          _session!.sendAudioRealtime(
            InlineDataPart('audio/pcm;rate=16000', data),
          );
        } else if (_isMuted) {
          debugPrint('[VOICE] Muted - audio not sent');
        } else {
          debugPrint('[VOICE] No active session - audio not sent');
        }
      },
      onError: (e) {
        debugPrint('[VOICE] ❌ Recording error: $e');
      },
    );
  }

  Future<void> _startReceiving() async {
    if (_session == null) {
      debugPrint('[VOICE] ❌ No session available for receiving');
      return;
    }

    debugPrint('[VOICE] ✅ Starting receive loop...');
    try {
      // The SDK's receive() breaks after each turnComplete, so we wrap it
      // in a while loop to restart listening for the next turn.
      while (mounted && _session != null) {
        await for (final response in _session!.receive()) {
          if (!mounted) break;

          final message = response.message;
          debugPrint('[VOICE] 📨 Received message: $message');

          if (message is LiveServerContent) {
            // Handle AI audio response
            if (message.modelTurn != null) {
              for (final part in message.modelTurn!.parts) {
                if (part is InlineDataPart &&
                    part.mimeType.startsWith('audio')) {
                  debugPrint('[VOICE] 🔊 AI Audio received: ${part.bytes.length} bytes');
                  _audioOutput.addData(part.bytes);
                  if (_state != VoiceState.speaking) {
                    setState(() => _state = VoiceState.speaking);
                  }
                }
              }
            }

            // Handle user input transcription
            if (message.inputTranscription != null) {
              debugPrint('[VOICE] 👤 User Input Transcription: ${message.inputTranscription?.text}');
              _handleTranscription(message.inputTranscription, isUser: true);
            }

            // Handle AI output transcription
            if (message.outputTranscription != null) {
              debugPrint('[VOICE] 🤖 AI Output Transcription: ${message.outputTranscription?.text}');
              _handleTranscription(message.outputTranscription, isUser: false);
            }

            if (message.turnComplete == true) {
              debugPrint('[VOICE] ✅ Turn complete - resetting both speaker states, returning to listening');
              // turnComplete is the most reliable signal that a full exchange
              // (user spoke → AI responded) has finished. Reset BOTH speakers
              // so the next utterance from either side always opens a fresh bubble.
              // This is especially important for the user side because
              // inputTranscription often never fires finished:true.
              setState(() {
                _aiUtteranceFinished = true;
                _currentAIMessageIndex = null;
                _userUtteranceFinished = true;
                _currentUserMessageIndex = null;
                _state = VoiceState.listening;
              });
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[VOICE] ❌ Live receive error: $e');
      if (mounted) {
        setState(() {
          _state = VoiceState.error;
          _errorMessage = 'Connection error: ${e.toString()}';
        });
      }
      return;
    }

    // Session closed or widget unmounted
    if (mounted && _state != VoiceState.idle) {
      debugPrint('[VOICE] Session closed or widget unmounted');
      setState(() => _state = VoiceState.idle);
    }
  }

  /// Handles an incoming transcription chunk from either the user or the AI.
  ///
  /// Strategy:
  /// - If the speaker's "utterance finished" flag is true, it means the previous
  ///   utterance ended, so we ALWAYS create a brand-new message bubble.
  /// - If the flag is false, the speaker is still mid-utterance, so we APPEND
  ///   the new text to the existing bubble for a smooth live-transcription effect.
  /// - When [Transcription.finished] is true, we mark the utterance as done so
  ///   the NEXT chunk from this speaker will open a fresh bubble.
  void _handleTranscription(Transcription? transcription, {required bool isUser}) {
    if (transcription?.text == null || transcription!.text!.isEmpty) {
      debugPrint('[VOICE] Skipping empty transcription');
      return;
    }

    final speaker = isUser ? '👤 User' : '🤖 AI';
    final isFinished = transcription.finished ?? false;
    debugPrint('[VOICE] $speaker - Text: "${transcription.text}", Finished: $isFinished');

    // Determine whether this speaker's previous utterance has finished.
    // If it has (or we have no active message), we must start a new bubble.
    final utteranceFinished = isUser ? _userUtteranceFinished : _aiUtteranceFinished;
    int? currentIndex = isUser ? _currentUserMessageIndex : _currentAIMessageIndex;

    if (utteranceFinished || currentIndex == null) {
      // --- Start a brand-new message bubble ---
      _transcript.add(_TranscriptMessage(
        text: transcription.text!,
        isUser: isUser,
      ));
      currentIndex = _transcript.length - 1;

      if (isUser) {
        _currentUserMessageIndex = currentIndex;
        _userUtteranceFinished = false;
      } else {
        _currentAIMessageIndex = currentIndex;
        _aiUtteranceFinished = false;
      }

      debugPrint('[VOICE] $speaker - ✨ NEW message created at index: $currentIndex');
    } else {
      // --- Append to the existing bubble (live streaming text) ---
      final oldText = _transcript[currentIndex].text;
      _transcript[currentIndex] = _TranscriptMessage(
        text: oldText + transcription.text!,
        isUser: isUser,
      );
      debugPrint('[VOICE] $speaker - ➕ APPENDED to message at index $currentIndex '
          '(total: ${_transcript[currentIndex].text.length} chars)');
    }

    // When the utterance finishes, clear the active index and set the finished
    // flag so the NEXT transcription event from this speaker opens a new bubble.
    if (isFinished) {
      if (isUser) {
        _currentUserMessageIndex = null;
        _userUtteranceFinished = true;
        debugPrint('[VOICE] $speaker - ✅ User utterance FINISHED - next chunk will create new message');
      } else {
        _currentAIMessageIndex = null;
        _aiUtteranceFinished = true;
        debugPrint('[VOICE] $speaker - ✅ AI utterance FINISHED - next chunk will create new message');
      }
    }

    debugPrint('[VOICE] Total messages: ${_transcript.length}');
    setState(() {});
  }

  Future<void> _disconnect() async {
    debugPrint('[VOICE] ══════════════════════════════════════');
    debugPrint('[VOICE] 🛑 ENDING VOICE CHAT SESSION');
    debugPrint('[VOICE] Session duration: ${_formatDuration(_sessionDuration)}');
    debugPrint('[VOICE] Total messages: ${_transcript.length}');
    debugPrint('[VOICE] ══════════════════════════════════════');

    _recordSubscription?.cancel();
    _recordSubscription = null;

    _durationTimer?.cancel();
    _durationTimer = null;

    try { await _audioOutput.stopStream(); } catch (_) {}
    try {
      if (_recorder != null) {
        await _recorder!.stop();
        _recorder!.dispose();
        _recorder = null;
      }
    } catch (_) {}
    // Closing the session also terminates the await-for receive loop
    try { await _session?.close(); } catch (_) {}
    _session = null;

    // Reset transcription tracking
    _currentUserMessageIndex = null;
    _currentAIMessageIndex = null;
    _userUtteranceFinished = true;
    _aiUtteranceFinished = true;

    if (mounted) {
      setState(() {
        _state = VoiceState.idle;
        ref.read(voiceSessionActiveProvider.notifier).state = false;
      });

      final shouldPrompt = widget.journalMode
          ? _transcript.isNotEmpty && !_savedAsJournal
          : _hasEnoughTranscript && !_savedAsJournal;

      if (shouldPrompt) {
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) _showJournalPrompt();
        });
      }
    }
  }

  Future<void> _endSession() async {
    await _disconnect();
  }

  bool get _hasEnoughTranscript {
    if (_transcript.length < 3) return false;
    final userChars = _transcript
        .where((m) => m.isUser)
        .fold<int>(0, (sum, m) => sum + m.text.length);
    return userChars >= 50;
  }

  String _gatherTranscriptAsText() {
    final buffer = StringBuffer();
    for (final msg in _transcript) {
      final label = msg.isUser ? 'User' : ref.read(activeVoiceProvider).name;
      buffer.writeln('$label: ${msg.text}');
    }
    return buffer.toString();
  }

  void _showJournalPrompt() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              if (_isSummarizing) ...[
                const SizedBox(height: 12),
                const CircularProgressIndicator(color: AppColors.primary),
                const SizedBox(height: 16),
                Text(
                  '${ref.read(activeVoiceProvider).name} is writing it up...',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 12),
              ] else ...[
                Icon(Icons.auto_awesome_rounded,
                    size: 32, color: AppColors.secondary),
                const SizedBox(height: 12),
                Text(
                  'That was a good conversation!',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Want to save it as a journal entry?',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textTertiary,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      setState(() => _isSummarizing = true);
                      setSheetState(() {});
                      Navigator.pop(ctx);
                      await _summarizeAndNavigate();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Save as Journal',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('Maybe Later',
                      style: TextStyle(color: AppColors.textSecondary)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _summarizeAndNavigate() async {
    try {
      final geminiService = ref.read(geminiServiceProvider);
      final transcript = _gatherTranscriptAsText();
      final result = await geminiService.summarizeConversation(transcript);

      if (mounted) {
        setState(() {
          _isSummarizing = false;
          _savedAsJournal = true;
        });
        Navigator.pushReplacementNamed(
          context,
          AppRoutes.journalEditor,
          arguments: JournalEditorArgs(
            prefillTitle: result.title,
            prefillContent: result.body,
            prefillTags: ['voice-journal'],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSummarizing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Could not summarize conversation'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  String get _statusText {
    switch (_state) {
      case VoiceState.idle: return 'Tap to start';
      case VoiceState.connecting: return 'Connecting...';
      case VoiceState.listening: return 'Listening...';
      case VoiceState.speaking: return 'AI is speaking...';
      case VoiceState.error: return 'Error occurred';
    }
  }

  Color get _statusColor {
    switch (_state) {
      case VoiceState.idle:
        return const Color(0xFF8A96B8);
      case VoiceState.connecting:
        return const Color(0xFF7C8CD3);
      case VoiceState.listening:
        return const Color(0xFF9B74FF);
      case VoiceState.speaking:
        return const Color(0xFF7CE3FF);
      case VoiceState.error:
        return const Color(0xFFFF6666);
    }
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Future<bool> _onWillPop() async {
    final isActive = _state == VoiceState.listening || _state == VoiceState.speaking;
    
    if (isActive) {
      final shouldLeave = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Quit Voice chat with Amigo',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          content: Text(
            'Are you sure you want to end the voice chat session?',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(
                'NO',
                style: TextStyle(color: AppColors.primary),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(
                'YES',
                style: TextStyle(color: AppColors.error),
              ),
            ),
          ],
        ),
      ) ?? false;

      if (shouldLeave) {
        await _disconnect();
        return true;
      }
      return false;
    }
    
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Stack(
          children: [
            // Perplexity-like dark gradient background
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF0A0F25),
                    Color(0xFF121B3E),
                    Color(0xFF0C1229),
                  ],
                ),
              ),
            ),
            ClipRRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  color: Colors.black.withValues(alpha: 0),
                ),
              ),
            ),
            // Content
            SafeArea(
              child: Column(
                children: [
                  _buildHeader(),
                  Expanded(
                    child: Column(
                      children: [
                        const Spacer(flex: 1),
                        _buildMicrophoneButton(),
                        const SizedBox(height: 20),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: Text(
                            _statusText,
                            key: ValueKey(_state),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: _statusColor,
                            ),
                          ),
                        ),
                        if (_errorMessage != null) ...[
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 32),
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(
                                  fontSize: 11, color: AppColors.error),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                        const Spacer(flex: 1),
                        _buildTranscriptArea(),
                      ],
                    ),
                  ),
                  _buildBottomControls(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          const SizedBox(width: 48),

          // CENTER: Title with Duration
          Expanded(
            child: Column(
              children: [
                Text(
                  widget.journalMode ? 'Voice & Journal' : 'Voice Chat',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                  textAlign: TextAlign.center,
                ),
                if (_state == VoiceState.listening ||
                    _state == VoiceState.speaking)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      _formatDuration(_sessionDuration),
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textTertiary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // RIGHT: Placeholder for alignment
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildMicrophoneButton() {
    final isActive =
        _state == VoiceState.listening || _state == VoiceState.speaking;
    final isIdle = _state == VoiceState.idle || _state == VoiceState.error;

    return GestureDetector(
      onTap: _onMicTap,
      child: SizedBox(
        width: 200,
        height: 200,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Wave circles when active
            if (isActive) ...[
              _buildWaveCircle(180, 0.08, 0),
              _buildWaveCircle(160, 0.12, 0.25),
              _buildWaveCircle(140, 0.15, 0.5),
            ],

            // Breathing ring when idle
            if (isIdle)
              AnimatedBuilder(
                animation: _breatheController,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _breatheAnimation.value,
                    child: Container(
                      width: 130,
                      height: 130,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          width: 2,
                        ),
                      ),
                    ),
                  );
                },
              ),

            // Glow behind button
            if (isActive)
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _pulseAnimation.value,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: (_state == VoiceState.listening
                                ? AppColors.primary
                                : AppColors.secondary)
                            .withValues(alpha: 0.15),
                      ),
                    ),
                  );
                },
              ),

            // Frosted glass mic button
            ClipOval(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: _state == VoiceState.listening
                          ? [AppColors.primary, AppColors.primaryDark]
                          : _state == VoiceState.speaking
                              ? [AppColors.secondary, AppColors.secondaryDark]
                              : _state == VoiceState.connecting
                                  ? [AppColors.accent, AppColors.accentLight]
                                  : [AppColors.primary, AppColors.primaryLight],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: (_state == VoiceState.listening
                                ? AppColors.primary
                                : _state == VoiceState.speaking
                                    ? AppColors.secondary
                                    : AppColors.primary)
                            .withValues(alpha: 0.35),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: _state == VoiceState.connecting
                      ? const Padding(
                          padding: EdgeInsets.all(28),
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : Icon(
                          _state == VoiceState.listening
                              ? Icons.mic_rounded
                              : _state == VoiceState.speaking
                                  ? Icons.volume_up_rounded
                                  : _state == VoiceState.error
                                      ? Icons.refresh_rounded
                                      : Icons.mic_none_rounded,
                          color: Colors.white,
                          size: 36,
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWaveCircle(double size, double opacity, double delay) {
    return AnimatedBuilder(
      animation: _waveController,
      builder: (context, child) {
        final value = ((_waveController.value + delay) % 1.0);
        final scale = 1.0 + (value * 0.25);
        final alpha = (1.0 - value) * opacity;

        return Transform.scale(
          scale: scale,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: (_state == VoiceState.listening
                        ? AppColors.primary
                        : AppColors.secondary)
                    .withValues(alpha: alpha),
                width: 1.5,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTranscriptArea() {
    return Container(
      height: 200,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.surfaceVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.subtitles_outlined,
                  size: 16, color: AppColors.textTertiary),
              const SizedBox(width: 6),
              Text(
                'Conversation',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: _transcript.isEmpty
                ? Center(
                    child: Text(
                      'Tap the microphone to start talking',
                      style: TextStyle(
                        color: AppColors.textTertiary,
                        fontSize: 13,
                      ),
                    ),
                  )
                : ListView.builder(
                    reverse: true,
                    itemCount: _transcript.length,
                    itemBuilder: (context, index) {
                      final message =
                          _transcript[_transcript.length - 1 - index];
                      return _TranscriptBubble(
                        message: message,
                        voiceName: ref.read(activeVoiceProvider).name,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomControls() {
    final isActive =
        _state == VoiceState.listening || _state == VoiceState.speaking;

    if (!isActive) {
      return const SizedBox(height: 80);
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // End Session button (shown only when session active)
          GestureDetector(
            onTap: () async {
              await _endSession();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFFA5252), Color(0xFFBA1A1A)],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFBA1A1A).withOpacity(0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.close_rounded, size: 20, color: Colors.white),
                  SizedBox(width: 8),
                  Text(
                    'End Session',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 16),

          // Mute button
          GestureDetector(
            onTap: () {
              setState(() => _isMuted = !_isMuted);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: _isMuted
                      ? const [Color(0xFF4B5563), Color(0xFF374151)]
                      : const [Color(0xFF3A9B5A), Color(0xFF2D6A3E)],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: (_isMuted
                            ? const Color(0xFF4B5563)
                            : const Color(0xFF3A9B5A))
                        .withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                    size: 20,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _isMuted ? 'Muted' : 'Mute',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TranscriptMessage {
  final String text;
  final bool isUser;
  _TranscriptMessage({required this.text, required this.isUser});
}

class _TranscriptBubble extends StatelessWidget {
  final _TranscriptMessage message;
  final String voiceName;
  const _TranscriptBubble({required this.message, required this.voiceName});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: message.isUser
                  ? AppColors.primary.withValues(alpha: 0.1)
                  : AppColors.secondary.withValues(alpha: 0.1),
            ),
            child: Icon(
              message.isUser ? Icons.person_rounded : Icons.auto_awesome_rounded,
              size: 12,
              color: message.isUser ? AppColors.primary : AppColors.secondary,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message.isUser ? 'You' : voiceName,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textTertiary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  message.text,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.3,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}