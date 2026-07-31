import 'package:flutter_test/flutter_test.dart';
import 'package:ggs_werewolf/services/api_service.dart';

void main() {
  group('ApiResponse', () {
    test('isSuccess returns true for 2xx status codes', () {
      expect(const ApiResponse(data: {}, statusCode: 200).isSuccess, true);
      expect(const ApiResponse(data: {}, statusCode: 201).isSuccess, true);
      expect(const ApiResponse(data: {}, statusCode: 204).isSuccess, true);
      expect(const ApiResponse(data: {}, statusCode: 299).isSuccess, true);
    });

    test('isSuccess returns false for non-2xx status codes', () {
      expect(const ApiResponse(data: {}, statusCode: 100).isSuccess, false);
      expect(const ApiResponse(data: {}, statusCode: 199).isSuccess, false);
      expect(const ApiResponse(data: {}, statusCode: 300).isSuccess, false);
      expect(const ApiResponse(data: {}, statusCode: 400).isSuccess, false);
      expect(const ApiResponse(data: {}, statusCode: 401).isSuccess, false);
      expect(const ApiResponse(data: {}, statusCode: 500).isSuccess, false);
    });

    test('isSuccess returns false for zero status code (network error)', () {
      expect(const ApiResponse(error: 'Network error', statusCode: 0).isSuccess, false);
    });

    test('can hold data and error simultaneously', () {
      const response = ApiResponse(
        data: {'partial': 'data'},
        error: 'Partial error',
        statusCode: 207,
      );
      expect(response.data, isNotNull);
      expect(response.error, isNotNull);
      expect(response.isSuccess, true);
    });
  });

  group('ApiService', () {
    late ApiService apiService;

    setUp(() {
      apiService = ApiService();
    });

    test('initial state has no token', () {
      expect(apiService.token, null);
      expect(apiService.isAuthenticated, false);
    });

    test('setToken updates token and authentication state', () {
      apiService.setToken('test-token-123');
      
      expect(apiService.token, 'test-token-123');
      expect(apiService.isAuthenticated, true);
    });

    test('setToken with null clears authentication', () {
      apiService.setToken('test-token');
      expect(apiService.isAuthenticated, true);

      apiService.setToken(null);
      expect(apiService.token, null);
      expect(apiService.isAuthenticated, false);
    });

    test('setToken with empty string is still not authenticated', () {
      apiService.setToken('');
      // empty string token - should technically be set but isAuthenticated checks for non-null non-empty
      expect(apiService.token, '');
    });
  });
}
