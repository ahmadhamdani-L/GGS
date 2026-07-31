import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/config.dart';

/// Response wrapper
class ApiResponse<T> {
  final T? data;
  final String? error;
  final int statusCode;

  const ApiResponse({this.data, this.error, required this.statusCode});

  bool get isSuccess => statusCode >= 200 && statusCode < 300;
}

/// HTTP API service for Go backend
class ApiService {
  String? _token;

  String? get token => _token;
  bool get isAuthenticated => _token != null;

  void setToken(String? token) {
    _token = token;
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  // --- Auth ---

  Future<ApiResponse<Map<String, dynamic>>> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    return _post('/api/auth/register', {
      'email': email,
      'password': password,
      'displayName': displayName,
    });
  }

  Future<ApiResponse<Map<String, dynamic>>> login({
    required String email,
    required String password,
  }) async {
    return _post('/api/auth/login', {
      'email': email,
      'password': password,
    });
  }

  Future<ApiResponse<Map<String, dynamic>>> loginAsGuest({
    String? displayName,
  }) async {
    return _post('/api/auth/guest', {
      'displayName': displayName ?? '',
    });
  }

  /// Refresh access token using refresh token
  Future<ApiResponse<Map<String, dynamic>>> refreshToken(String refreshToken) async {
    return _post('/api/auth/refresh', {
      'refreshToken': refreshToken,
    });
  }

  /// Logout from all devices (revokes all refresh tokens)
  Future<ApiResponse<Map<String, dynamic>>> logout() async {
    if (_token == null) {
      return const ApiResponse(data: {'status': 'ok'}, statusCode: 200);
    }
    return _post('/api/auth/logout', {});
  }

  // --- Profile ---

  Future<ApiResponse<Map<String, dynamic>>> getProfile() async {
    return _get('/api/profile');
  }

  Future<ApiResponse<Map<String, dynamic>>> updateProfile({
    String? displayName,
    int? avatarId,
    Map<String, dynamic>? chibiConfig,
  }) async {
    final body = <String, dynamic>{};
    if (displayName != null) body['displayName'] = displayName;
    if (avatarId != null) body['avatarId'] = avatarId;
    if (chibiConfig != null) body['chibiConfig'] = chibiConfig;
    return _put('/api/profile', body);
  }

  // --- Stats & Leaderboard ---

  Future<ApiResponse<Map<String, dynamic>>> getStats() async {
    return _get('/api/stats');
  }

  Future<ApiResponse<Map<String, dynamic>>> getHistory({int limit = 20}) async {
    return _get('/api/history?limit=$limit');
  }

  Future<ApiResponse<Map<String, dynamic>>> getLeaderboard({String sort = 'rating', int limit = 50}) async {
    return _get('/api/leaderboard?sort=$sort&limit=$limit');
  }

  // --- Social ---

  Future<ApiResponse<Map<String, dynamic>>> getFriends() async {
    return _get('/api/friends');
  }

  Future<ApiResponse<Map<String, dynamic>>> postFriendAction(String friendId, String action) async {
    return _post('/api/friends', {'friendId': friendId, 'action': action});
  }

  Future<ApiResponse<Map<String, dynamic>>> reportPlayer(String reportedId, String reason, String details) async {
    return _post('/api/report', {'reportedId': reportedId, 'reason': reason, 'details': details});
  }

  Future<ApiResponse<Map<String, dynamic>>> getRecentPlayers() async {
    return _get('/api/recent-players');
  }

  // --- Ranking ---

  Future<ApiResponse<Map<String, dynamic>>> getRankInfo() async {
    return _get('/api/rank');
  }

  // --- Shop ---

  /// Get all shop items with ownership status
  Future<ApiResponse<Map<String, dynamic>>> getShopItems() async {
    return _get('/api/shop');
  }

  /// Purchase an item from the shop
  Future<ApiResponse<Map<String, dynamic>>> purchaseItem(String itemId) async {
    return _post('/api/shop', {'itemId': itemId});
  }

  // --- Daily Missions ---

  /// Get daily missions for user
  Future<ApiResponse<Map<String, dynamic>>> getMissions() async {
    return _get('/api/missions');
  }

  /// Claim mission reward
  Future<ApiResponse<Map<String, dynamic>>> claimMission(String missionId) async {
    return _post('/api/missions', {'missionId': missionId});
  }

  // --- Notifications ---

  /// Get notifications for user
  Future<ApiResponse<Map<String, dynamic>>> getNotifications({int limit = 50, bool unreadOnly = false}) async {
    return _get('/api/notifications?limit=$limit&unread=$unreadOnly');
  }

  /// Mark notification as read
  Future<ApiResponse<Map<String, dynamic>>> markNotificationRead(String notificationId) async {
    return _post('/api/notifications', {'action': 'read', 'notificationId': notificationId});
  }

  /// Mark all notifications as read
  Future<ApiResponse<Map<String, dynamic>>> markAllNotificationsRead() async {
    return _post('/api/notifications', {'action': 'read_all'});
  }

  /// Delete a notification
  Future<ApiResponse<Map<String, dynamic>>> deleteNotification(String notificationId) async {
    return _post('/api/notifications', {'action': 'delete', 'notificationId': notificationId});
  }

  // --- HTTP helpers ---

  Future<ApiResponse<Map<String, dynamic>>> _get(String path) async {
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.apiUrl}$path'),
        headers: _headers,
      );
      return _parseResponse(response);
    } catch (e) {
      return ApiResponse(error: e.toString(), statusCode: 0);
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> _post(
      String path, Map<String, dynamic> body) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConfig.apiUrl}$path'),
        headers: _headers,
        body: jsonEncode(body),
      );
      return _parseResponse(response);
    } catch (e) {
      return ApiResponse(error: e.toString(), statusCode: 0);
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> _put(
      String path, Map<String, dynamic> body) async {
    try {
      final response = await http.put(
        Uri.parse('${AppConfig.apiUrl}$path'),
        headers: _headers,
        body: jsonEncode(body),
      );
      return _parseResponse(response);
    } catch (e) {
      return ApiResponse(error: e.toString(), statusCode: 0);
    }
  }

  ApiResponse<Map<String, dynamic>> _parseResponse(http.Response response) {
    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return ApiResponse(data: body, statusCode: response.statusCode);
      }
      return ApiResponse(
        error: body['error'] as String? ?? 'Unknown error',
        statusCode: response.statusCode,
      );
    } catch (e) {
      return ApiResponse(error: response.body, statusCode: response.statusCode);
    }
  }
}
