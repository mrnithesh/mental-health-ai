// Phase 2: API Service for backend communication
// This file is disabled until AI features are implemented

import 'package:dio/dio.dart';
import '../config/constants.dart';
import 'auth_service.dart';

/// API Service - Placeholder for Phase 2
/// Will be used for:
/// - Chat message streaming
/// - Voice ephemeral token
/// - Journal AI insights
/// - Mood AI analysis
class ApiService {
  final Dio _dio;
  final AuthService _authService;

  ApiService({required AuthService authService})
      : _authService = authService,
        _dio = Dio(BaseOptions(
          baseUrl: AppConstants.apiBaseUrl,
          connectTimeout: AppConstants.connectionTimeout,
          receiveTimeout: AppConstants.apiTimeout,
          headers: {
            'Content-Type': 'application/json',
          },
        ));

  /// Health check - can be used to verify backend connectivity
  Future<bool> healthCheck() async {
    try {
      final response = await _dio.get('/health');
      return response.data['status'] == 'healthy';
    } catch (e) {
      return false;
    }
  }
}

// Response models will be added in Phase 2
class EphemeralTokenResponse {
  final String token;
  final DateTime expiresAt;
  final String websocketUrl;

  EphemeralTokenResponse({
    required this.token,
    required this.expiresAt,
    required this.websocketUrl,
  });

  factory EphemeralTokenResponse.fromJson(Map<String, dynamic> json) {
    return EphemeralTokenResponse(
      token: json['token'],
      expiresAt: DateTime.parse(json['expires_at']),
      websocketUrl: json['websocket_url'],
    );
  }
}
