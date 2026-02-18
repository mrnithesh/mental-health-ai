import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/routes.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/common/loading_button.dart';

class PhoneAuthScreen extends ConsumerStatefulWidget {
  const PhoneAuthScreen({super.key});

  @override
  ConsumerState<PhoneAuthScreen> createState() => _PhoneAuthScreenState();
}

class _PhoneAuthScreenState extends ConsumerState<PhoneAuthScreen> {
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _phoneFocusNode = FocusNode();
  final _otpFocusNode = FocusNode();

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    _phoneFocusNode.dispose();
    _otpFocusNode.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    final phoneNumber = _phoneController.text.trim();
    if (phoneNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your phone number')),
      );
      return;
    }

    // Add country code if not present
    final formattedNumber =
        phoneNumber.startsWith('+') ? phoneNumber : '+91$phoneNumber';

    await ref.read(phoneAuthProvider.notifier).sendOtp(formattedNumber);
  }

  Future<void> _verifyOtp() async {
    final otp = _otpController.text.trim();
    if (otp.isEmpty || otp.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter 6-digit OTP')),
      );
      return;
    }

    final success = await ref.read(phoneAuthProvider.notifier).verifyOtp(otp);
    
    if (success && mounted) {
      Navigator.of(context).pushReplacementNamed(AppRoutes.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    final phoneAuthState = ref.watch(phoneAuthProvider);
    final isCodeSent = phoneAuthState.isCodeSent;
    final isVerifying = phoneAuthState.isVerifying;
    final error = phoneAuthState.error;

    // Show error if any
    if (error != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error)),
        );
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Phone Sign In'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              // Icon
              const Icon(
                Icons.phone_android,
                size: 64,
                color: AppColors.primary,
              ),
              const SizedBox(height: 24),
              const Text(
                'Verify Your Phone',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                isCodeSent
                    ? 'Enter the 6-digit code sent to your phone'
                    : 'We will send you a verification code',
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),

              if (!isCodeSent) ...[
                // Phone number input
                TextFormField(
                  controller: _phoneController,
                  focusNode: _phoneFocusNode,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number',
                    prefixIcon: Icon(Icons.phone),
                    prefixText: '+91 ',
                    hintText: '9876543210',
                  ),
                  onFieldSubmitted: (_) => _sendOtp(),
                ),
                const SizedBox(height: 24),
                LoadingButton(
                  onPressed: _sendOtp,
                  isLoading: isVerifying,
                  child: const Text('Send OTP'),
                ),
              ] else ...[
                // OTP input
                TextFormField(
                  controller: _otpController,
                  focusNode: _otpFocusNode,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  maxLength: 6,
                  decoration: const InputDecoration(
                    labelText: 'Enter OTP',
                    prefixIcon: Icon(Icons.lock_clock),
                    counterText: '',
                  ),
                  style: const TextStyle(
                    fontSize: 24,
                    letterSpacing: 8,
                  ),
                  textAlign: TextAlign.center,
                  onFieldSubmitted: (_) => _verifyOtp(),
                ),
                const SizedBox(height: 24),
                LoadingButton(
                  onPressed: _verifyOtp,
                  isLoading: isVerifying,
                  child: const Text('Verify OTP'),
                ),
                const SizedBox(height: 16),
                // Resend OTP
                TextButton(
                  onPressed: isVerifying
                      ? null
                      : () {
                          ref.read(phoneAuthProvider.notifier).reset();
                        },
                  child: const Text('Change Phone Number'),
                ),
              ],
              const SizedBox(height: 24),

              // Info text
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.info.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      color: AppColors.info,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Standard SMS charges may apply',
                        style: TextStyle(
                          color: AppColors.info,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
