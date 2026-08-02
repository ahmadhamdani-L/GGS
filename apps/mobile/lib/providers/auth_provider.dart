import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/room.dart';
import '../services/api_service.dart';

/// API service singleton
final apiServiceProvider = Provider<ApiService>((ref) => ApiService());

/// Secure storage for sensitive tokens
const _secureStorage = FlutterSecureStorage(
  aOptions: AndroidOptions(encryptedSharedPreferences: true),
  iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
);

/// Storage keys
const _kAccessToken = 'access_token';
const _kRefreshToken = 'refresh_token';
const _kTokenExpiry = 'token_expiry';

/// Auth state
enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthState {
  final AuthStatus status;
  final String? userId;
  final UserProfile? profile;
  final bool isLoading;
  final String? error;

  const AuthState({
    this.status = AuthStatus.unknown,
    this.userId,
    this.profile,
    this.isLoading = false,
    this.error,
  });

  AuthState copyWith({
    AuthStatus? status,
    String? userId,
    UserProfile? profile,
    bool? isLoading,
    String? error,
  }) {
    return AuthState(
      status: status ?? this.status,
      userId: userId ?? this.userId,
      profile: profile ?? this.profile,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  bool get isAuthenticated => status == AuthStatus.authenticated;
}

class AuthNotifier extends StateNotifier<AuthState> {
  final ApiService _api;
  Timer? _refreshTimer;
  
  AuthNotifier(this._api) : super(const AuthState()) {
    _tryRestoreSession();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  /// Schedule token refresh before expiry
  void _scheduleTokenRefresh(int expiresInSeconds) {
    _refreshTimer?.cancel();
    
    // Refresh 1 minute before expiry, minimum 30 seconds
    final refreshIn = Duration(seconds: (expiresInSeconds - 60).clamp(30, expiresInSeconds));
    
    _refreshTimer = Timer(refreshIn, () async {
      await _refreshAccessToken();
    });
  }

  /// Refresh access token using refresh token
  Future<bool> _refreshAccessToken() async {
    final refreshToken = await _secureStorage.read(key: _kRefreshToken);
    if (refreshToken == null) return false;

    final resp = await _api.refreshToken(refreshToken);
    
    if (resp.isSuccess && resp.data != null) {
      await _saveTokens(
        accessToken: resp.data!['accessToken'] as String,
        refreshToken: resp.data!['refreshToken'] as String,
        expiresIn: resp.data!['expiresIn'] as int,
      );
      return true;
    }
    
    // Refresh failed - logout
    await logout();
    return false;
  }

  Future<void> _tryRestoreSession() async {
    // Try to get access token from secure storage
    final accessToken = await _secureStorage.read(key: _kAccessToken);
    final refreshToken = await _secureStorage.read(key: _kRefreshToken);
    final expiryStr = await _secureStorage.read(key: _kTokenExpiry);
    
    // Fallback: try old token from SharedPreferences (migration)
    if (accessToken == null) {
      final prefs = await SharedPreferences.getInstance();
      final oldToken = prefs.getString('auth_token');
      if (oldToken != null) {
        // Migrate old token and try to use it
        _api.setToken(oldToken);
        final resp = await _api.getProfile();
        if (resp.isSuccess && resp.data != null) {
          // Old token still valid - user will get new tokens on next login
          state = AuthState(
            status: AuthStatus.authenticated,
            userId: resp.data!['userId'] as String?,
            profile: UserProfile.fromJson(resp.data!),
          );
          return;
        }
        // Old token invalid, remove it
        await prefs.remove('auth_token');
      }
      state = const AuthState(status: AuthStatus.unauthenticated);
      return;
    }

    // Check if token is expired
    if (expiryStr != null) {
      final expiry = DateTime.tryParse(expiryStr);
      if (expiry != null && DateTime.now().isAfter(expiry)) {
        // Access token expired, try refresh
        if (refreshToken != null) {
          final refreshed = await _refreshAccessToken();
          if (!refreshed) {
            state = const AuthState(status: AuthStatus.unauthenticated);
            return;
          }
          // Token refreshed, continue with new token
          final newToken = await _secureStorage.read(key: _kAccessToken);
          if (newToken != null) {
            _api.setToken(newToken);
          }
        } else {
          state = const AuthState(status: AuthStatus.unauthenticated);
          return;
        }
      } else {
        _api.setToken(accessToken);
        
        // Schedule refresh if we know expiry
        if (expiry != null) {
          final secondsUntilExpiry = expiry.difference(DateTime.now()).inSeconds;
          if (secondsUntilExpiry > 0) {
            _scheduleTokenRefresh(secondsUntilExpiry);
          }
        }
      }
    } else {
      _api.setToken(accessToken);
    }

    // Validate token by fetching profile
    final resp = await _api.getProfile();
    if (resp.isSuccess && resp.data != null) {
      state = AuthState(
        status: AuthStatus.authenticated,
        userId: resp.data!['userId'] as String?,
        profile: UserProfile.fromJson(resp.data!),
      );
    } else {
      // Token invalid, try refresh
      if (refreshToken != null) {
        final refreshed = await _refreshAccessToken();
        if (refreshed) {
          // Retry profile fetch
          final retryResp = await _api.getProfile();
          if (retryResp.isSuccess && retryResp.data != null) {
            state = AuthState(
              status: AuthStatus.authenticated,
              userId: retryResp.data!['userId'] as String?,
              profile: UserProfile.fromJson(retryResp.data!),
            );
            return;
          }
        }
      }
      await _clearTokens();
      state = const AuthState(status: AuthStatus.unauthenticated);
    }
  }

  Future<void> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    final resp = await _api.register(
      email: email,
      password: password,
      displayName: displayName,
    );

    if (resp.isSuccess && resp.data != null) {
      await _saveTokens(
        accessToken: resp.data!['accessToken'] as String? ?? resp.data!['token'] as String,
        refreshToken: resp.data!['refreshToken'] as String?,
        expiresIn: resp.data!['expiresIn'] as int? ?? 900,
      );

      final profileData = resp.data!['profile'] as Map<String, dynamic>;
      state = AuthState(
        status: AuthStatus.authenticated,
        userId: profileData['userId'] as String?,
        profile: UserProfile.fromJson(profileData),
      );
    } else {
      state = state.copyWith(
        isLoading: false,
        error: resp.error ?? 'Registration failed',
      );
    }
  }

  Future<void> login({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    final resp = await _api.login(email: email, password: password);

    if (resp.isSuccess && resp.data != null) {
      await _saveTokens(
        accessToken: resp.data!['accessToken'] as String? ?? resp.data!['token'] as String,
        refreshToken: resp.data!['refreshToken'] as String?,
        expiresIn: resp.data!['expiresIn'] as int? ?? 900,
      );

      final profileData = resp.data!['profile'] as Map<String, dynamic>;
      state = AuthState(
        status: AuthStatus.authenticated,
        userId: profileData['userId'] as String?,
        profile: UserProfile.fromJson(profileData),
      );
      
      // Chibi config is included in profile - will be synced by chibi_provider
    } else {
      state = state.copyWith(
        isLoading: false,
        error: resp.error ?? 'Login failed',
      );
    }
  }

  Future<void> loginAsGuest({String? displayName}) async {
    state = state.copyWith(isLoading: true, error: null);

    final resp = await _api.loginAsGuest(displayName: displayName);

    if (resp.isSuccess && resp.data != null) {
      await _saveTokens(
        accessToken: resp.data!['accessToken'] as String? ?? resp.data!['token'] as String,
        refreshToken: resp.data!['refreshToken'] as String?,
        expiresIn: resp.data!['expiresIn'] as int? ?? 900,
      );

      final profileData = resp.data!['profile'] as Map<String, dynamic>;
      state = AuthState(
        status: AuthStatus.authenticated,
        userId: profileData['userId'] as String?,
        profile: UserProfile.fromJson(profileData),
      );
    } else {
      state = state.copyWith(
        isLoading: false,
        error: resp.error ?? 'Guest login failed',
      );
    }
  }

  Future<void> updateProfile({
    String? displayName,
    int? avatarId,
    String? avatarUrl,  // custom uploaded photo URL
  }) async {
    final resp = await _api.updateProfile(
      displayName: displayName,
      avatarId: avatarId,
      avatarUrl: avatarUrl,
    );

    if (resp.isSuccess && resp.data != null) {
      state = state.copyWith(profile: UserProfile.fromJson(resp.data!));
    }
  }

  /// Refresh profile data from server (e.g., after purchase to update coins)
  Future<void> refreshProfile() async {
    final resp = await _api.getProfile();
    if (resp.isSuccess && resp.data != null) {
      state = state.copyWith(profile: UserProfile.fromJson(resp.data!));
    }
  }

  /// Convert a guest account to a registered email account
  Future<bool> convertGuest({required String email, required String password}) async {
    state = state.copyWith(isLoading: true, error: null);
    final resp = await _api.convertGuest(email: email, password: password);
    if (resp.isSuccess && resp.data != null) {
      final profileData = resp.data!['profile'] as Map<String, dynamic>?;
      if (profileData != null) {
        state = state.copyWith(
          isLoading: false,
          profile: UserProfile.fromJson(profileData),
        );
      } else {
        state = state.copyWith(isLoading: false);
      }
      return true;
    } else {
      state = state.copyWith(
        isLoading: false,
        error: resp.error ?? 'Gagal menghubungkan akun',
      );
      return false;
    }
  }

  Future<void> logout() async {
    _refreshTimer?.cancel();
    
    // Call backend to revoke all refresh tokens
    await _api.logout();
    
    _api.setToken(null);
    await _clearTokens();
    
    // Also clear old token storage
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  Future<void> _saveTokens({
    required String accessToken,
    String? refreshToken,
    required int expiresIn,
  }) async {
    _api.setToken(accessToken);
    
    await _secureStorage.write(key: _kAccessToken, value: accessToken);
    
    if (refreshToken != null) {
      await _secureStorage.write(key: _kRefreshToken, value: refreshToken);
    }
    
    // Store expiry time
    final expiry = DateTime.now().add(Duration(seconds: expiresIn));
    await _secureStorage.write(key: _kTokenExpiry, value: expiry.toIso8601String());
    
    // Schedule token refresh
    _scheduleTokenRefresh(expiresIn);
  }

  Future<void> _clearTokens() async {
    await _secureStorage.delete(key: _kAccessToken);
    await _secureStorage.delete(key: _kRefreshToken);
    await _secureStorage.delete(key: _kTokenExpiry);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.watch(apiServiceProvider));
});
