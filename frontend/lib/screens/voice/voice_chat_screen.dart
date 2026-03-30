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

  LiveSession? _session;
  AudioRecorder? _recorder;
  final AudioOutput _audioOutput = AudioOutput();
  StreamSubscription? _recordSubscription;

  late AnimationController _pulseController;
  late AnimationController _waveController;
  late AnimationController _breatheController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _breatheAnimation;

  int? _inputTranscriptionIndex;
  int? _outputTranscriptionIndex;

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
    final hasPermission = await _requestMicPermission();
    if (!hasPermission) {
      setState(() {
        _state = VoiceState.error;
        _errorMessage = 'Microphone permission is required for voice chat';
      });
      return;
    }

    setState(() {
      _state = VoiceState.connecting;
      _errorMessage = null;
    });

    try {
      await _audioOutput.init();
      await _audioOutput.playStream();

      final geminiService = ref.read(geminiServiceProvider);
      debugPrint('Connecting to Gemini Live API...');
      _session = await geminiService.connectLive();
      debugPrint('Connected! Starting receive and record...');

      unawaited(_startReceiving());
      await _startRecording();

      setState(() {
        _state = VoiceState.listening;
      });
    } catch (e, stack) {
      debugPrint('Voice connect error: $e');
      debugPrint('Stack: $stack');
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

    _recordSubscription = stream.listen(
      (data) {
        if (_session != null && _state != VoiceState.speaking) {
          _session!.sendAudioRealtime(
            InlineDataPart('audio/pcm;rate=16000', data),
          );
        }
      },
      onError: (e) {
        debugPrint('Recording error: $e');
      },
    );
  }

  Future<void> _startReceiving() async {
    if (_session == null) return;

    try {
      // The SDK's receive() breaks after each turnComplete, so we wrap it
      // in a while loop to restart listening for the next turn.
      while (mounted && _session != null) {
        await for (final response in _session!.receive()) {
          if (!mounted) break;

          final message = response.message;

          if (message is LiveServerContent) {
            if (message.modelTurn != null) {
              for (final part in message.modelTurn!.parts) {
                if (part is InlineDataPart &&
                    part.mimeType.startsWith('audio')) {
                  _audioOutput.addData(part.bytes);
                  if (_state != VoiceState.speaking) {
                    setState(() => _state = VoiceState.speaking);
                  }
                }
              }
            }

            _inputTranscriptionIndex = _handleTranscription(
                message.inputTranscription, _inputTranscriptionIndex, true);

            _outputTranscriptionIndex = _handleTranscription(
                message.outputTranscription, _outputTranscriptionIndex, false);

            if (message.turnComplete == true) {
              setState(() => _state = VoiceState.listening);
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Live receive error: $e');
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
      setState(() => _state = VoiceState.idle);
    }
  }

  int? _handleTranscription(
      Transcription? transcription, int? messageIndex, bool isUser) {
    if (transcription?.text == null) return messageIndex;

    int? currentIndex = messageIndex;

    if (currentIndex != null && currentIndex < _transcript.length) {
      _transcript[currentIndex] = _TranscriptMessage(
        text: _transcript[currentIndex].text + transcription!.text!,
        isUser: isUser,
      );
    } else {
      _transcript.add(
          _TranscriptMessage(text: transcription!.text!, isUser: isUser));
      currentIndex = _transcript.length - 1;
    }

    if (transcription.finished ?? false) {
      currentIndex = null;
    }

    setState(() {});
    return currentIndex;
  }

  Future<void> _disconnect() async {
    _recordSubscription?.cancel();
    _recordSubscription = null;

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

    _inputTranscriptionIndex = null;
    _outputTranscriptionIndex = null;

    if (mounted) {
      setState(() => _state = VoiceState.idle);

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
      final label = msg.isUser ? 'User' : 'NILAA';
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
                  'NILAA is writing it up...',
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
                      await _summarizeAndNavigate();
                      if (ctx.mounted) Navigator.pop(ctx);
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
        Navigator.pushNamed(
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
      case VoiceState.idle: return AppColors.textSecondary;
      case VoiceState.connecting: return AppColors.accent;
      case VoiceState.listening: return AppColors.primary;
      case VoiceState.speaking: return AppColors.secondary;
      case VoiceState.error: return AppColors.error;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.primary.withValues(alpha: 0.06),
              AppColors.background,
              AppColors.secondary.withValues(alpha: 0.03),
            ],
          ),
        ),
        child: SafeArea(
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final canGoBack = Navigator.canPop(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          if (canGoBack)
            IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () async {
                if (_state == VoiceState.listening ||
                    _state == VoiceState.speaking) {
                  await _disconnect();
                }
                if (mounted) Navigator.pop(context);
              },
              color: AppColors.textPrimary,
            )
          else
            const SizedBox(width: 48),
          Expanded(
            child: Text(
              widget.journalMode ? 'Voice & Journal' : 'Voice Chat',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
          ),
          if (widget.journalMode && _hasEnoughTranscript && !_savedAsJournal)
            IconButton(
              icon: const Icon(Icons.save_rounded),
              onPressed: _isSummarizing ? null : _showJournalPrompt,
              color: AppColors.primary,
              tooltip: 'Save as Journal',
            )
          else
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
                      return _TranscriptBubble(message: message);
                    },
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
  const _TranscriptBubble({required this.message});

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
                  message.isUser ? 'You' : 'NILAA',
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
