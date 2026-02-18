import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user_model.dart';
import '../services/auth_service.dart';
import 'service_providers.dart';

/// Stream of auth state changes
final authStateProvider = StreamProvider<User?>((ref) {
  final authService = ref.watch(authServiceProvider);
  return authService.authStateChanges;
});

/// Current user model provider
final userModelProvider = FutureProvider<UserModel?>((ref) async {
  final authService = ref.watch(authServiceProvider);
  final authState = ref.watch(authStateProvider);
  
  return authState.when(
    data: (user) async {
      if (user == null) return null;
      return await authService.getUserModel();
    },
    loading: () => null,
    error: (_, __) => null,
  );
});

/// Auth state notifier for handling auth actions
class AuthNotifier extends StateNotifier<AsyncValue<void>> {
  final AuthService _authService;

  AuthNotifier(this._authService) : super(const AsyncValue.data(null));

  Future<void> signInWithEmail(String email, String password) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _authService.signInWithEmail(email, password);
    });
  }

  Future<void> registerWithEmail(
    String email,
    String password,
    String? displayName,
  ) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _authService.registerWithEmail(email, password, displayName);
    });
  }

  Future<void> signInWithGoogle() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _authService.signInWithGoogle();
    });
  }

  Future<void> signOut() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _authService.signOut();
    });
  }

  Future<void> sendPasswordResetEmail(String email) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _authService.sendPasswordResetEmail(email);
    });
  }
}

final authNotifierProvider =
    StateNotifierProvider<AuthNotifier, AsyncValue<void>>((ref) {
  final authService = ref.watch(authServiceProvider);
  return AuthNotifier(authService);
});

/// Phone auth state
class PhoneAuthState {
  final String? verificationId;
  final bool isCodeSent;
  final bool isVerifying;
  final String? error;

  PhoneAuthState({
    this.verificationId,
    this.isCodeSent = false,
    this.isVerifying = false,
    this.error,
  });

  PhoneAuthState copyWith({
    String? verificationId,
    bool? isCodeSent,
    bool? isVerifying,
    String? error,
  }) {
    return PhoneAuthState(
      verificationId: verificationId ?? this.verificationId,
      isCodeSent: isCodeSent ?? this.isCodeSent,
      isVerifying: isVerifying ?? this.isVerifying,
      error: error,
    );
  }
}

class PhoneAuthNotifier extends StateNotifier<PhoneAuthState> {
  final AuthService _authService;

  PhoneAuthNotifier(this._authService) : super(PhoneAuthState());

  Future<void> sendOtp(String phoneNumber) async {
    state = state.copyWith(error: null, isVerifying: true);
    
    await _authService.sendPhoneOtp(
      phoneNumber: phoneNumber,
      onCodeSent: (verificationId, _) {
        state = state.copyWith(
          verificationId: verificationId,
          isCodeSent: true,
          isVerifying: false,
        );
      },
      onError: (e) {
        state = state.copyWith(
          error: e.message,
          isVerifying: false,
        );
      },
      onAutoVerify: (credential) async {
        await _authService.signInWithGoogle();
      },
    );
  }

  Future<bool> verifyOtp(String smsCode) async {
    if (state.verificationId == null) {
      state = state.copyWith(error: 'Please request OTP first');
      return false;
    }

    state = state.copyWith(error: null, isVerifying: true);
    
    try {
      await _authService.verifyPhoneOtp(state.verificationId!, smsCode);
      state = PhoneAuthState();
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString(), isVerifying: false);
      return false;
    }
  }

  void reset() {
    state = PhoneAuthState();
  }
}

final phoneAuthProvider =
    StateNotifierProvider<PhoneAuthNotifier, PhoneAuthState>((ref) {
  final authService = ref.watch(authServiceProvider);
  return PhoneAuthNotifier(authService);
});
