import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../constants/api_constants.dart';

// Auth state
class AuthState {
  final UserModel? user;
  final bool isLoading;
  final String? error;
  final bool isAuthenticated;

  const AuthState({
    this.user,
    this.isLoading = false,
    this.error,
    this.isAuthenticated = false,
  });

  AuthState copyWith({
    UserModel? user,
    bool? isLoading,
    String? error,
    bool? isAuthenticated,
  }) =>
      AuthState(
        user: user ?? this.user,
        isLoading: isLoading ?? this.isLoading,
        error: error,
        isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      );
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState()) {
    _tryRestoreSession();
  }

  Future<void> _tryRestoreSession() async {
    final token = await StorageService.getToken();
    final userJson = await StorageService.getUser();
    if (token != null && userJson != null) {
      try {
        final user = UserModel.fromJson(jsonDecode(userJson));
        state = AuthState(user: user, isAuthenticated: true);
      } catch (_) {
        await StorageService.clear();
      }
    }
  }

  /// Returns null on success, mfa_token string if MFA required, or throws
  Future<String?> login(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final res = await ApiService.post(ApiConstants.login, data: {
        'email': email,
        'password': password,
      });
      final body = res.data as Map<String, dynamic>;

      if (body['mfa_required'] == true) {
        state = state.copyWith(isLoading: false);
        return body['mfa_token'] as String;
      }

      await _saveSession(body);
      return null;
    } on DioException catch (e) {
      state = state.copyWith(isLoading: false, error: ApiException.fromDio(e).message);
      rethrow;
    }
  }

  Future<void> verifyMfa(String mfaToken, String code) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final res = await ApiService.post(ApiConstants.mfaVerify, data: {
        'mfa_token': mfaToken,
        'code': code,
      });
      await _saveSession(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      state = state.copyWith(isLoading: false, error: ApiException.fromDio(e).message);
      rethrow;
    }
  }

  Future<void> logout() async {
    try {
      await ApiService.post(ApiConstants.logout)
          .timeout(const Duration(seconds: 5));
    } catch (_) {}
    await StorageService.clear();
    state = const AuthState();
  }

  Future<void> _saveSession(Map<String, dynamic> body) async {
    final token = body['token'] as String;
    final user = UserModel.fromJson(body['user'] as Map<String, dynamic>);
    await StorageService.saveToken(token);
    await StorageService.saveUser(jsonEncode(user.toJson()));
    state = AuthState(user: user, isAuthenticated: true);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (_) => AuthNotifier(),
);
