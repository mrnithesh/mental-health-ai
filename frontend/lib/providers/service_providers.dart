import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/auth_service.dart';
import '../services/firestore_service.dart';

/// Auth service provider
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

/// Firestore service provider
final firestoreServiceProvider = Provider<FirestoreService>((ref) {
  return FirestoreService();
});

// Phase 2: API and Gemini providers
// final apiServiceProvider = Provider<ApiService>((ref) {
//   final authService = ref.watch(authServiceProvider);
//   return ApiService(authService: authService);
// });

// final geminiLiveServiceProvider = Provider<GeminiLiveService>((ref) {
//   final apiService = ref.watch(apiServiceProvider);
//   return GeminiLiveService(apiService: apiService);
// });
