import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import '../core/config.dart';
import 'debug_logger.dart';

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

// Add X-App-Version header to every request so the server can enforce min version.
  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
        'X-App-Version': '1.0.0', // matches pubspec version: 1.0.0+1
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

// api_service.dart — forgotPassword now matches the two-step API:
// Step 1: POST {email} → receive token (in dev mode returned in response)
// Step 2: POST {email, token, newPassword} → reset password
// The existing single-call forgotPassword is kept for backward compat
// but updated to pass both fields for the new two-step flow.
  Future<ApiResponse<Map<String, dynamic>>> forgotPassword({
    required String email,
    String? token,
    String? newPassword,
  }) async {
    final body = <String, dynamic>{'email': email};
    if (token != null) body['token'] = token;
    if (newPassword != null) body['newPassword'] = newPassword;
    return _post('/api/auth/forgot-password', body);
  }

  Future<ApiResponse<Map<String, dynamic>>> convertGuest({
    required String email,
    required String password,
  }) async {
    return _post('/api/auth/convert-guest', {
      'email': email,
      'password': password,
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
    String? avatarUrl,  // Task #6: custom uploaded photo URL
  }) async {
    final body = <String, dynamic>{};
    if (displayName != null) body['displayName'] = displayName;
    if (avatarId != null) body['avatarId'] = avatarId;
    if (chibiConfig != null) body['chibiConfig'] = chibiConfig;
    if (avatarUrl != null) body['avatarUrl'] = avatarUrl;
    return _put('/api/profile', body);
  }

  /// Build full URL for an avatar path returned by the server.
  /// avatarPath is like "/avatars/abc123.jpg"
  String buildAvatarUrl(String avatarPath) {
    if (avatarPath.startsWith('http')) return avatarPath;
    return '${AppConfig.apiUrl}$avatarPath';
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

  Future<ApiResponse<Map<String, dynamic>>> searchUsers(String query) async {
    return _get('/api/users/search?q=${Uri.encodeComponent(query)}');
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

  /// Get user's inventory (owned items with quantities)
  Future<ApiResponse<Map<String, dynamic>>> getInventory() async {
    return _get('/api/inventory');
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
    final stopwatch = Stopwatch()..start();
    logger.apiRequest('GET', path);
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.apiUrl}$path'),
        headers: _headers,
      );
      stopwatch.stop();
      final result = _parseResponse(response);
      if (result.isSuccess) {
        logger.apiResponse('GET', path, response.statusCode, stopwatch.elapsed);
      } else {
        logger.apiError('GET', path, result.error ?? 'Unknown', status: response.statusCode);
      }
      return result;
    } catch (e) {
      stopwatch.stop();
      logger.apiError('GET', path, e.toString());
      return ApiResponse(error: e.toString(), statusCode: 0);
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> _post(
      String path, Map<String, dynamic> body) async {
    final stopwatch = Stopwatch()..start();
    logger.apiRequest('POST', path, body: body);
    try {
      final response = await http.post(
        Uri.parse('${AppConfig.apiUrl}$path'),
        headers: _headers,
        body: jsonEncode(body),
      );
      stopwatch.stop();
      final result = _parseResponse(response);
      if (result.isSuccess) {
        logger.apiResponse('POST', path, response.statusCode, stopwatch.elapsed);
      } else {
        logger.apiError('POST', path, result.error ?? 'Unknown', status: response.statusCode);
      }
      return result;
    } catch (e) {
      stopwatch.stop();
      logger.apiError('POST', path, e.toString());
      return ApiResponse(error: e.toString(), statusCode: 0);
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> _put(
      String path, Map<String, dynamic> body) async {
    final stopwatch = Stopwatch()..start();
    logger.apiRequest('PUT', path, body: body);
    try {
      final response = await http.put(
        Uri.parse('${AppConfig.apiUrl}$path'),
        headers: _headers,
        body: jsonEncode(body),
      );
      stopwatch.stop();
      final result = _parseResponse(response);
      if (result.isSuccess) {
        logger.apiResponse('PUT', path, response.statusCode, stopwatch.elapsed);
      } else {
        logger.apiError('PUT', path, result.error ?? 'Unknown', status: response.statusCode);
      }
      return result;
    } catch (e) {
      stopwatch.stop();
      logger.apiError('PUT', path, e.toString());
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

  /// POST /api/fcm/token — register push notification token
  Future<ApiResponse<Map<String, dynamic>>> registerFCMToken({
    required String token,
    String platform = 'android',
  }) => _post('/api/fcm/token', {'token': token, 'platform': platform});

  // ─── Avatar Upload ────────────────────────────────────────

  /// POST /api/avatar/upload — multipart/form-data, field: "avatar"
  /// Returns { avatarUrl: "/avatars/xxx.jpg" }
  Future<ApiResponse<Map<String, dynamic>>> uploadAvatar(String filePath) async {
    try {
      final uri = Uri.parse('${AppConfig.apiUrl}/api/avatar/upload');
      final request = http.MultipartRequest('POST', uri);

      // Auth header
      if (_token != null) {
        request.headers['Authorization'] = 'Bearer $_token';
      }
      request.headers['X-App-Version'] = '1.0.0';

      request.files.add(await http.MultipartFile.fromPath('avatar', filePath));

      final streamed = await request.send().timeout(const Duration(seconds: 30));
      final response = await http.Response.fromStream(streamed);
      return _parseResponse(response);
    } on TimeoutException {
      return ApiResponse(error: 'Upload timeout — coba lagi', statusCode: 408);
    } catch (e) {
      return ApiResponse(error: e.toString(), statusCode: 0);
    }
  }

  /// DELETE /api/avatar — removes user's uploaded avatar, reverts to preset
  Future<ApiResponse<Map<String, dynamic>>> deleteAvatar() => _delete('/api/avatar');

  // Helper for DELETE requests
  Future<ApiResponse<Map<String, dynamic>>> _delete(String path) async {
    final stopwatch = Stopwatch()..start();
    logger.apiRequest('DELETE', path);
    try {
      final uri = Uri.parse('${AppConfig.apiUrl}$path');
      final response = await http.delete(uri, headers: _headers)
          .timeout(const Duration(seconds: 15));
      stopwatch.stop();
      final result = _parseResponse(response);
      if (result.isSuccess) {
        logger.apiResponse('DELETE', path, response.statusCode, stopwatch.elapsed);
      } else {
        logger.apiError('DELETE', path, result.error ?? 'Unknown', status: response.statusCode);
      }
      return result;
    } on TimeoutException {
      stopwatch.stop();
      logger.apiError('DELETE', path, 'Request timeout');
      return ApiResponse(error: 'Request timeout', statusCode: 408);
    } catch (e) {
      stopwatch.stop();
      logger.apiError('DELETE', path, e.toString());
      return ApiResponse(error: e.toString(), statusCode: 0);
    }
  }

  /// GET /api/gifts/catalog?type=gift|curse|all
  Future<ApiResponse<Map<String, dynamic>>> getGiftCatalog({String type = ''}) =>
      _get('/api/gifts/catalog${type.isNotEmpty ? '?type=$type' : ''}');

  /// POST /api/gifts/send
  Future<ApiResponse<Map<String, dynamic>>> sendGift({
    required String receiverId,
    required String giftId,
    required String idempotencyKey,
    String message = '',
  }) => _post('/api/gifts/send', {
        'receiverId': receiverId,
        'giftId': giftId,
        'message': message,
        'idempotencyKey': idempotencyKey,
      });

  /// GET /api/gifts/history?role=sent|received|all&limit=20
  Future<ApiResponse<Map<String, dynamic>>> getGiftHistory({String role = 'all', int limit = 20}) =>
      _get('/api/gifts/history?role=$role&limit=$limit');

  /// GET /api/social/stats?userId=...
  Future<ApiResponse<Map<String, dynamic>>> getSocialStats({String? userId}) =>
      _get('/api/social/stats${userId != null ? '?userId=$userId' : ''}');

  /// GET /api/social/feed?scope=global|mine&limit=30
  Future<ApiResponse<Map<String, dynamic>>> getActivityFeed({String scope = 'global', int limit = 30}) =>
      _get('/api/social/feed?scope=$scope&limit=$limit');

  /// GET /api/social/leaderboard?type=charm&period=weekly
  Future<ApiResponse<Map<String, dynamic>>> getSocialLeaderboard({
    String boardType = 'charm',
    String period    = 'alltime',
    int limit        = 50,
  }) => _get('/api/social/leaderboard?type=$boardType&period=$period&limit=$limit');

  /// GET /api/diamonds
  Future<ApiResponse<Map<String, dynamic>>> getDiamonds() =>
      _get('/api/diamonds');

  /// GET /api/daily-reward — check today's reward status
  Future<ApiResponse<Map<String, dynamic>>> getDailyReward() =>
      _get('/api/daily-reward');

  /// POST /api/daily-reward/claim — claim today's reward
  Future<ApiResponse<Map<String, dynamic>>> claimDailyReward() =>
      _post('/api/daily-reward/claim', {});

  // ─── Payment ──────────────────────────────────────────────

  /// GET /api/payment/packages
  Future<ApiResponse<Map<String, dynamic>>> getPaymentPackages() =>
      _get('/api/payment/packages');

  /// POST /api/payment/create-order
  Future<ApiResponse<Map<String, dynamic>>> createPaymentOrder(String packageId) =>
      _post('/api/payment/create-order', {'packageId': packageId});

  // ─── Achievements ──────────────────────────────────────────

  /// GET /api/achievements
  Future<ApiResponse<Map<String, dynamic>>> getAchievements() =>
      _get('/api/achievements');

  // ─── Player Profile (view others) ─────────────────────────

  /// GET /api/profile?userId=... — view another player's profile
  Future<ApiResponse<Map<String, dynamic>>> getPlayerProfile(String userId) =>
      _get('/api/profile?userId=$userId');

  // ─── Social actions (shortcuts) ────────────────────────────

  /// POST /api/friends — add friend
  Future<ApiResponse<Map<String, dynamic>>> addFriend(String targetId) =>
      _post('/api/friends', {'action': 'add', 'friendId': targetId});

  /// POST /api/friends — block player
  /// POST /api/friends — block player
  Future<ApiResponse<Map<String, dynamic>>> blockPlayer(String targetId) =>
      _post('/api/friends', {'action': 'block', 'friendId': targetId});

  /// DELETE /api/account — permanently delete user account
  Future<ApiResponse<Map<String, dynamic>>> deleteAccount({String? password}) async {
    try {
      final uri = Uri.parse('${AppConfig.apiUrl}/api/account');
      final request = http.Request('DELETE', uri);
      request.headers.addAll(_headers);
      request.body = jsonEncode({'password': password ?? '', 'confirm': true});
      final streamed = await request.send().timeout(const Duration(seconds: 15));
      final response = await http.Response.fromStream(streamed);
      return _parseResponse(response);
    } on TimeoutException {
      return ApiResponse(error: 'Request timeout', statusCode: 408);
    } catch (e) {
      return ApiResponse(error: e.toString(), statusCode: 0);
    }
  }

  // ─── Events ────────────────────────────────────────────────

  /// GET /api/events — get active events with user progress
  Future<ApiResponse<Map<String, dynamic>>> getEvents() => _get('/api/events');

  /// POST /api/events/claim — claim event reward
  Future<ApiResponse<Map<String, dynamic>>> claimEventReward(String eventId) =>
      _post('/api/events/claim', {'eventId': eventId});

  // ─── Quests ────────────────────────────────────────────────

  /// GET /api/quests — get daily & weekly quests with progress
  Future<ApiResponse<Map<String, dynamic>>> getQuests() => _get('/api/quests');

  /// POST /api/quests/claim — claim quest reward
  Future<ApiResponse<Map<String, dynamic>>> claimQuestReward(String questId) =>
      _post('/api/quests/claim', {'questId': questId});

  // ─── Lucky Spin ────────────────────────────────────────────

  /// GET /api/lucky-spin — get spin status + prizes
  Future<ApiResponse<Map<String, dynamic>>> getSpinStatus() => _get('/api/lucky-spin');

  /// POST /api/lucky-spin — perform a spin
  Future<ApiResponse<Map<String, dynamic>>> doSpin() => _post('/api/lucky-spin', {});

  /// GET /api/lucky-spin/history — get spin history
  Future<ApiResponse<Map<String, dynamic>>> getSpinHistory() => _get('/api/lucky-spin/history');

  // ─── Gift Inbox ────────────────────────────────────────────

  /// GET /api/gifts/inbox — get unclaimed gifts
  Future<ApiResponse<Map<String, dynamic>>> getGiftInbox() => _get('/api/gifts/inbox');

  /// POST /api/gifts/claim — claim a specific gift or all
  Future<ApiResponse<Map<String, dynamic>>> claimGift({String? giftId, bool all = false}) =>
      _post('/api/gifts/claim', {'giftId': giftId ?? '', 'all': all});
}

