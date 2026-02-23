import 'dart:async';
import 'dart:ui';

import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

import '../../config/theme.dart';
import '../../providers/service_providers.dart';
import '../../utils/audio_output.dart';

enum VoiceState { idle, connecting, listening, speaking, error }

class VoiceChatScreen extends ConsumerStatefulWidget {
  const VoiceChatScreen({super.key});

  @override
  ConsumerState<VoiceChatScreen> createState() => _VoiceChatScreenState();
}

class _VoiceChatScreenState extends ConsumerState<VoiceChatScreen>
    with TickerProviderStateMixin {
  VoiceState _state = VoiceState.idle;
  final List<_TranscriptMessage> _transcript = [];
  String? _errorMessage;

  LiveSession? _session;
  final AudioRecorder _recorder = AudioRecorder();
  final AudioOutput _audioOutput = AudioOutput();
  StreamSubscription? _receiveSubscription;
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
    _recorder.dispose();
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

      _startReceiving();
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
    final stream = await _recorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 24000,
        numChannels: 1,
        echoCancel: true,
        noiseSuppress: true,
        androidConfig: AndroidRecordConfig(
          audioSource: AndroidAudioSource.voiceCommunication,
        ),
      ),
    );

    _recordSubscription = stream.listen(
      (data) {
        if (_session != null) {
          _session!.sendAudioRealtime(InlineDataPart('audio/pcm', data));
        }
      },
      onError: (e) {
        debugPrint('Recording error: $e');
      },
    );
  }

  void _startReceiving() {
    if (_session == null) return;

    _receiveSubscription = _session!.receive().listen(
      (response) {
        final message = response.message;

        if (message is LiveServerContent) {
          if (message.modelTurn != null) {
            for (final part in message.modelTurn!.parts) {
              if (part is InlineDataPart && part.mimeType.startsWith('audio')) {
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
      },
      onError: (e) {
        debugPrint('Live receive error: $e');
        setState(() {
          _state = VoiceState.error;
          _errorMessage = 'Connection error: ${e.toString()}';
        });
      },
      onDone: () {
        if (_state != VoiceState.idle) {
          setState(() => _state = VoiceState.idle);
        }
      },
    );
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
    _receiveSubscription?.cancel();
    _receiveSubscription = null;
    _recordSubscription?.cancel();
    _recordSubscription = null;

    try { await _audioOutput.stopStream(); } catch (_) {}
    try { await _recorder.stop(); } catch (_) {}
    try { await _session?.close(); } catch (_) {}
    _session = null;

    _inputTranscriptionIndex = null;
    _outputTranscriptionIndex = null;

    if (mounted) setState(() => _state = VoiceState.idle);
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
              AppColors.primary.withOpacity(0.06),
              AppColors.background,
              AppColors.secondary.withOpacity(0.03),
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const SizedBox(width: 48),
          Expanded(
            child: Text(
              'Voice Chat',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
          ),
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
                          color: AppColors.primary.withOpacity(0.15),
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
                            .withOpacity(0.15),
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
                            .withOpacity(0.35),
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
                    .withOpacity(alpha),
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
                  ? AppColors.primary.withOpacity(0.1)
                  : AppColors.secondary.withOpacity(0.1),
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
                  message.isUser ? 'You' : 'MindfulAI',
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
