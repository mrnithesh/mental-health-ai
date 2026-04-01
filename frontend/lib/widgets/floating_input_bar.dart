import 'dart:ui';
import 'package:flutter/material.dart';
import '../config/theme.dart';

class FloatingInputBar extends StatefulWidget {
  final VoidCallback? onAttachment;
  final VoidCallback? onVoiceInput;
  final Function(String)? onSend;
  final String? initialText;

  const FloatingInputBar({
    super.key,
    this.onAttachment,
    this.onVoiceInput,
    this.onSend,
    this.initialText,
  });

  @override
  State<FloatingInputBar> createState() => _FloatingInputBarState();
}

class _FloatingInputBarState extends State<FloatingInputBar> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  bool _attachmentPressed = false;
  bool _voicePressed = false;
  bool _sendPressed = false;

  @override
  void initState() {
    super.initState();
    _controller.text = widget.initialText ?? '';
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleSend() {
    final text = _controller.text.trim();
    if (text.isNotEmpty && widget.onSend != null) {
      widget.onSend!(text);
      _controller.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSendEnabled = _controller.text.trim().isNotEmpty;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding, vertical: AppSpacing.md),
        child: SizedBox(
          height: 52,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(25),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.2),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 20,
                      spreadRadius: 1,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Attachment button
                    _buildIconButton(
                      icon: Icons.add,
                      isPressed: _attachmentPressed,
                      onPressedChange: (pressed) => setState(() => _attachmentPressed = pressed),
                      onTap: widget.onAttachment,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    // Text field
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        focusNode: _focusNode,
                        decoration: InputDecoration(
                          hintText: 'Ask anything',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                        style: Theme.of(context).textTheme.bodyMedium,
                        onSubmitted: (_) => _handleSend(),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    // Voice button
                    _buildIconButton(
                      icon: Icons.mic,
                      isPressed: _voicePressed,
                      onPressedChange: (pressed) => setState(() => _voicePressed = pressed),
                      onTap: widget.onVoiceInput,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    // Send button
                    _buildSendButton(isSendEnabled),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required bool isPressed,
    required Function(bool) onPressedChange,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      onTapDown: (_) => onPressedChange(true),
      onTapUp: (_) => onPressedChange(false),
      onTapCancel: () => onPressedChange(false),
      child: Transform.scale(
        scale: isPressed ? 0.9 : 1.0,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: AppColors.textPrimary,
            size: 20,
          ),
        ),
      ),
    );
  }

  Widget _buildSendButton(bool enabled) {
    return GestureDetector(
      onTap: enabled ? _handleSend : null,
      onTapDown: (_) => setState(() {}),
      onTapUp: (_) => setState(() {}),
      onTapCancel: () => setState(() {}),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          gradient: enabled
              ? LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryLight],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: enabled ? null : Colors.grey.withOpacity(0.3),
          shape: BoxShape.circle,
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.4),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ]
              : null,
        ),
        child: Icon(
          Icons.send,
          color: enabled ? Colors.white : Colors.grey,
          size: 20,
        ),
      ),
    );
  }
}