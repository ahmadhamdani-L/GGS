import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ggs_werewolf/providers/auth_provider.dart';

void main() {
  group('AuthState', () {
    test('initial state has unknown status', () {
      const state = AuthState();
      expect(state.status, AuthStatus.unknown);
      expect(state.isAuthenticated, false);
      expect(state.userId, null);
      expect(state.profile, null);
      expect(state.isLoading, false);
      expect(state.error, null);
    });

    test('copyWith preserves unchanged values', () {
      const state = AuthState(
        status: AuthStatus.authenticated,
        userId: 'user-123',
        isLoading: false,
      );

      final newState = state.copyWith(isLoading: true);
      
      expect(newState.status, AuthStatus.authenticated);
      expect(newState.userId, 'user-123');
      expect(newState.isLoading, true);
    });

    test('isAuthenticated returns true when status is authenticated', () {
      const state = AuthState(status: AuthStatus.authenticated);
      expect(state.isAuthenticated, true);
    });

    test('isAuthenticated returns false for unauthenticated status', () {
      const state = AuthState(status: AuthStatus.unauthenticated);
      expect(state.isAuthenticated, false);
    });

    test('isAuthenticated returns false for unknown status', () {
      const state = AuthState(status: AuthStatus.unknown);
      expect(state.isAuthenticated, false);
    });

    test('copyWith can update error', () {
      const state = AuthState();
      final newState = state.copyWith(error: 'Login failed');
      expect(newState.error, 'Login failed');
    });

    test('copyWith can clear error by passing null explicitly', () {
      const state = AuthState(error: 'Some error');
      final newState = state.copyWith(error: null);
      // Note: copyWith uses ?? so null won't clear, this tests current behavior
      expect(newState.error, null);
    });
  });

  group('AuthStatus', () {
    test('enum values exist', () {
      expect(AuthStatus.values.length, 3);
      expect(AuthStatus.values.contains(AuthStatus.unknown), true);
      expect(AuthStatus.values.contains(AuthStatus.authenticated), true);
      expect(AuthStatus.values.contains(AuthStatus.unauthenticated), true);
    });
  });
}
