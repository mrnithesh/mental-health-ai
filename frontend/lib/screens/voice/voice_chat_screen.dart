import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../config/theme.dart';

enum VoiceState {
  idle,
  listening,
  thinking,
  speaking,
}

class VoiceChatScreen extends StatefulWidget {
  const VoiceChatScreen({super.key});

  @override
  State<VoiceChatScreen> createState() => _VoiceChatScreenState();
}

class _VoiceChatScreenState extends State<VoiceChatScreen>
    with TickerProviderStateMixin {
  VoiceState _state = VoiceState.idle;
  final List<_TranscriptMessage> _transcript = [];
  
  late AnimationController _pulseController;
  late AnimationController _waveController;
  late Animation<double> _pulseAnimation;
  
  Timer? _stateTimer;

  final List<String> _aiResponses = [
    "I hear you, and it's completely valid to feel that way. Remember, it's okay to take things one step at a time.",
    "Thank you for sharing that with me. Taking a moment to acknowledge your feelings is an important step.",
    "That sounds challenging. Would you like to try a quick breathing exercise together?",
    "I'm here for you. Sometimes just talking about how we feel can help lighten the load.",
    "It takes courage to open up. I appreciate you trusting me with your thoughts.",
  ];

  @override
  void initState() {
    super.initState();
    
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    
    _waveController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _waveController.dispose();
    _stateTimer?.cancel();
    super.dispose();
  }

  void _onMicTap() {
    if (_state == VoiceState.idle) {
      _startListening();
    } else if (_state == VoiceState.listening) {
      _stopListening();
    }
  }

  void _startListening() {
    setState(() {
      _state = VoiceState.listening;
    });
    
    _stateTimer = Timer(const Duration(seconds: 3), () {
      _processUserInput();
    });
  }

  void _stopListening() {
    _stateTimer?.cancel();
    _processUserInput();
  }

  void _processUserInput() {
    setState(() {
      _state = VoiceState.thinking;
      _transcript.add(_TranscriptMessage(
        text: "I've been feeling a bit overwhelmed lately...",
        isUser: true,
      ));
    });
    
    _stateTimer = Timer(const Duration(seconds: 2), () {
      _aiRespond();
    });
  }

  void _aiRespond() {
    final random = Random();
    final response = _aiResponses[random.nextInt(_aiResponses.length)];
    
    setState(() {
      _state = VoiceState.speaking;
      _transcript.add(_TranscriptMessage(
        text: response,
        isUser: false,
      ));
    });
    
    _stateTimer = Timer(const Duration(seconds: 4), () {
      setState(() {
        _state = VoiceState.idle;
      });
    });
  }

  String get _statusText {
    switch (_state) {
      case VoiceState.idle:
        return 'Tap to speak';
      case VoiceState.listening:
        return 'Listening...';
      case VoiceState.thinking:
        return 'AI is thinking...';
      case VoiceState.speaking:
        return 'AI is speaking...';
    }
  }

  Color get _statusColor {
    switch (_state) {
      case VoiceState.idle:
        return AppColors.textSecondary;
      case VoiceState.listening:
        return AppColors.error;
      case VoiceState.thinking:
        return AppColors.warning;
      case VoiceState.speaking:
        return AppColors.success;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.primary.withOpacity(0.1),
              AppColors.background,
              AppColors.secondary.withOpacity(0.05),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // App bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Expanded(
                      child: Text(
                        'Voice Chat',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
              
              // Main content
              Expanded(
                child: Column(
                  children: [
                    const Spacer(flex: 1),
                    
                    // Animated microphone button
                    _buildMicrophoneButton(),
                    
                    const SizedBox(height: 24),
                    
                    // Status text
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: Text(
                        _statusText,
                        key: ValueKey(_state),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          color: _statusColor,
                        ),
                      ),
                    ),
                    
                    const Spacer(flex: 1),
                    
                    // Transcript area
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

  Widget _buildMicrophoneButton() {
    final isActive = _state == VoiceState.listening || _state == VoiceState.speaking;
    
    return GestureDetector(
      onTap: _onMicTap,
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          return Stack(
            alignment: Alignment.center,
            children: [
              // Outer ripple waves
              if (isActive) ...[
                _buildWaveCircle(180, 0.1, 0),
                _buildWaveCircle(160, 0.15, 0.2),
                _buildWaveCircle(140, 0.2, 0.4),
              ],
              
              // Pulsing background
              Transform.scale(
                scale: isActive ? _pulseAnimation.value : 1.0,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _state == VoiceState.listening
                        ? AppColors.error.withOpacity(0.2)
                        : _state == VoiceState.speaking
                            ? AppColors.success.withOpacity(0.2)
                            : AppColors.primary.withOpacity(0.1),
                  ),
                ),
              ),
              
              // Main button
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: _state == VoiceState.listening
                        ? [AppColors.error, AppColors.error.withOpacity(0.8)]
                        : _state == VoiceState.speaking
                            ? [AppColors.success, AppColors.success.withOpacity(0.8)]
                            : [AppColors.primary, AppColors.primaryLight],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (_state == VoiceState.listening
                              ? AppColors.error
                              : _state == VoiceState.speaking
                                  ? AppColors.success
                                  : AppColors.primary)
                          .withOpacity(0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Icon(
                  _state == VoiceState.listening
                      ? Icons.mic
                      : _state == VoiceState.speaking
                          ? Icons.volume_up
                          : _state == VoiceState.thinking
                              ? Icons.psychology
                              : Icons.mic_none,
                  color: Colors.white,
                  size: 40,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildWaveCircle(double size, double opacity, double delay) {
    return AnimatedBuilder(
      animation: _waveController,
      builder: (context, child) {
        final value = ((_waveController.value + delay) % 1.0);
        final scale = 1.0 + (value * 0.3);
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
                        ? AppColors.error
                        : AppColors.success)
                    .withOpacity(alpha),
                width: 2,
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
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.history, size: 18, color: AppColors.textSecondary),
              const SizedBox(width: 8),
              Text(
                'Conversation',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _transcript.isEmpty
                ? Center(
                    child: Text(
                      'Tap the microphone to start talking',
                      style: TextStyle(
                        color: AppColors.textTertiary,
                        fontSize: 14,
                      ),
                    ),
                  )
                : ListView.builder(
                    reverse: true,
                    itemCount: _transcript.length,
                    itemBuilder: (context, index) {
                      final message = _transcript[_transcript.length - 1 - index];
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
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: message.isUser
                  ? AppColors.primary.withOpacity(0.1)
                  : AppColors.secondary.withOpacity(0.1),
            ),
            child: Icon(
              message.isUser ? Icons.person : Icons.psychology,
              size: 14,
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
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  message.text,
                  style: const TextStyle(fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
