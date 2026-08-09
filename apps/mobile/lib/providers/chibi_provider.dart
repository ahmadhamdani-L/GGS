import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../widgets/chibi_avatar.dart';
import '../services/api_service.dart';
import 'auth_provider.dart'; // For apiServiceProvider

/// Persists chibi character configuration with debounced saving and backend sync
class ChibiNotifier extends StateNotifier<ChibiConfig> {
  ChibiNotifier(this._apiService) : super(ChibiPresets.defaultMale) {
    _loadFromPrefs();
  }

  final ApiService _apiService;
  static const _prefsKey = 'chibi_config';
  Timer? _saveDebounce;
  Timer? _syncDebounce;
  bool _isLoading = true;
  bool _isSyncing = false;
  String? _lastSyncError;

  bool get isLoading => _isLoading;
  bool get isSyncing => _isSyncing;
  String? get lastSyncError => _lastSyncError;

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_prefsKey);
      if (json != null) {
        final map = jsonDecode(json) as Map<String, dynamic>;
        state = _configFromJson(map);
      }
    } catch (e) {
      debugPrint('Error loading chibi config: $e');
      // Keep default state on error
    } finally {
      _isLoading = false;
    }
  }

  /// Load chibi config from backend (call after login/profile fetch)
  Future<void> loadFromBackend(Map<String, dynamic>? backendConfig) async {
    if (backendConfig == null || backendConfig.isEmpty) return;
    
    try {
      final config = _configFromJson(backendConfig);
      state = config;
      // Also save to local prefs
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, jsonEncode(_configToJson(state)));
    } catch (e) {
      debugPrint('Error loading chibi from backend: $e');
    }
  }

  /// Debounced save to prevent excessive writes
  void _saveToPrefs() {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 300), () async {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_prefsKey, jsonEncode(_configToJson(state)));
      } catch (e) {
        debugPrint('Error saving chibi config: $e');
      }
    });
  }

  /// Debounced sync to backend (longer delay to batch multiple changes)
  void _syncToBackend() {
    _syncDebounce?.cancel();
    _syncDebounce = Timer(const Duration(milliseconds: 1000), () async {
      await _performBackendSync();
    });
  }

  /// Perform the actual backend sync
  Future<bool> _performBackendSync() async {
    if (_isSyncing) return false;
    
    _isSyncing = true;
    _lastSyncError = null;
    
    try {
      final result = await _apiService.updateProfile(
        chibiConfig: _configToJson(state),
      );
      
      if (result.error != null) {
        _lastSyncError = result.error;
        debugPrint('Backend sync error: ${result.error}');
        return false;
      }
      
      debugPrint('Chibi config synced to backend');
      return true;
    } catch (e) {
      _lastSyncError = e.toString();
      return false;
    } finally {
      _isSyncing = false;
    }
  }

  /// Purchase or rent a premium wardrobe item
  Future<bool> purchasePremiumItem(int price, String duration) async {
    try {
      final response = await _apiService.purchaseWardrobe(price, duration);
      if (response.isSuccess) {
        // Force refresh user profile to update coins
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Force immediate save and sync (e.g., when exiting wardrobe)
  Future<void> saveImmediately() async {
    _saveDebounce?.cancel();
    _syncDebounce?.cancel();
    
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, jsonEncode(_configToJson(state)));
      
      // Also sync to backend
      await _performBackendSync();
    } catch (e) {
      debugPrint('Error saving chibi config: $e');
    }
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    _syncDebounce?.cancel();
    super.dispose();
  }

  // Individual setters (with local + backend save)
  void setSkinColor(Color c) {
    state = state.copyWith(skinColor: c);
    _saveToPrefs();
    _syncToBackend();
  }

  void setHairColor(Color c) {
    state = state.copyWith(hairColor: c);
    _saveToPrefs();
    _syncToBackend();
  }

  void setEyeColor(Color c) {
    state = state.copyWith(eyeColor: c);
    _saveToPrefs();
    _syncToBackend();
  }

  void setShirtColor(Color c) {
    state = state.copyWith(shirtColor: c);
    _saveToPrefs();
    _syncToBackend();
  }

  void setPantsColor(Color c) {
    state = state.copyWith(pantsColor: c);
    _saveToPrefs();
    _syncToBackend();
  }

  void setPantsStyle(PantsStyle s) {
    state = state.copyWith(pantsStyle: s);
    _saveToPrefs();
    _syncToBackend();
  }

  void setHairStyle(HairStyle s) {
    state = state.copyWith(hairStyle: s);
    _saveToPrefs();
    _syncToBackend();
  }

  void setEyeStyle(EyeStyle s) {
    state = state.copyWith(eyeStyle: s);
    _saveToPrefs();
    _syncToBackend();
  }

  void setExpression(Expression e) {
    state = state.copyWith(expression: e);
    _saveToPrefs();
    _syncToBackend();
  }

  void setShirtStyle(ShirtStyle s) {
    state = state.copyWith(shirtStyle: s);
    _saveToPrefs();
    _syncToBackend();
  }

  void setAccessory(Accessory a) {
    state = state.copyWith(accessory: a);
    _saveToPrefs();
    _syncToBackend();
  }

  void setAccessoryColor(Color c) {
    state = state.copyWith(accessoryColor: c);
    _saveToPrefs();
    _syncToBackend();
  }

  void setShowBlush(bool v) {
    state = state.copyWith(showBlush: v);
    _saveToPrefs();
    _syncToBackend();
  }

  void setFaceShape(FaceShape v) {
    state = state.copyWith(faceShape: v);
    _saveToPrefs();
    _syncToBackend();
  }

  void setGender(Gender v) {
    state = state.copyWith(gender: v);
    _saveToPrefs();
    _syncToBackend();
  }

  /// Batch update multiple properties at once
  void update({
    Color? skinColor,
    Color? hairColor,
    Color? eyeColor,
    Color? shirtColor,
    Color? pantsColor,
    HairStyle? hairStyle,
    EyeStyle? eyeStyle,
    Expression? expression,
    ShirtStyle? shirtStyle,
    PantsStyle? pantsStyle,
    Accessory? accessory,
    Color? accessoryColor,
    bool? showBlush,
  }) {
    state = state.copyWith(
      skinColor: skinColor,
      hairColor: hairColor,
      eyeColor: eyeColor,
      shirtColor: shirtColor,
      pantsColor: pantsColor,
      hairStyle: hairStyle,
      eyeStyle: eyeStyle,
      expression: expression,
      shirtStyle: shirtStyle,
      pantsStyle: pantsStyle,
      accessory: accessory,
      accessoryColor: accessoryColor,
      showBlush: showBlush,
    );
    _saveToPrefs();
    _syncToBackend();
  }

  void randomize() {
    state = ChibiPresets.randomConfig();
    _saveToPrefs();
    _syncToBackend();
  }

  void reset() {
    state = ChibiPresets.defaultMale;
    _saveToPrefs();
    _syncToBackend();
  }

  // JSON serialization (compatible with backend)
  Map<String, dynamic> _configToJson(ChibiConfig c) => {
        'version': 1, // For future migrations
        'skinColor': c.skinColor.toARGB32(),
        'hairColor': c.hairColor.toARGB32(),
        'eyeColor': c.eyeColor.toARGB32(),
        'shirtColor': c.shirtColor.toARGB32(),
        'pantsColor': c.pantsColor.toARGB32(),
        'hairStyle': c.hairStyle.index,
        'eyeStyle': c.eyeStyle.index,
        'expression': c.expression.index,
        'shirtStyle': c.shirtStyle.index,
        'pantsStyle': c.pantsStyle.index,
        'accessory': c.accessory.index,
        'accessoryColor': c.accessoryColor?.toARGB32(),
        'showBlush': c.showBlush,
        'faceShape': c.faceShape.index,
        'gender': c.gender.index,
      };

  ChibiConfig _configFromJson(Map<String, dynamic> j) {
    // Safe enum parsing with bounds checking
    final hairIdx = (j['hairStyle'] as int? ?? 0).clamp(0, HairStyle.values.length - 1);
    final eyeIdx = (j['eyeStyle'] as int? ?? 0).clamp(0, EyeStyle.values.length - 1);
    final exprIdx = (j['expression'] as int? ?? 0).clamp(0, Expression.values.length - 1);
    final shirtIdx = (j['shirtStyle'] as int? ?? 0).clamp(0, ShirtStyle.values.length - 1);
    final pantsIdx = (j['pantsStyle'] as int? ?? 0).clamp(0, PantsStyle.values.length - 1);
    final accIdx = (j['accessory'] as int? ?? 0).clamp(0, Accessory.values.length - 1);
    
    return ChibiConfig(
      skinColor: Color(j['skinColor'] as int? ?? 0xFFFFDBB4),
      hairColor: Color(j['hairColor'] as int? ?? 0xFF4A3728),
      eyeColor: Color(j['eyeColor'] as int? ?? 0xFF5D4037),
      shirtColor: Color(j['shirtColor'] as int? ?? 0xFF2196F3),
      pantsColor: Color(j['pantsColor'] as int? ?? 0xFF37474F),
      hairStyle: HairStyle.values[hairIdx],
      eyeStyle: EyeStyle.values[eyeIdx],
      expression: Expression.values[exprIdx],
      shirtStyle: ShirtStyle.values[shirtIdx],
      pantsStyle: PantsStyle.values[pantsIdx],
      accessory: Accessory.values[accIdx],
      accessoryColor: j['accessoryColor'] != null ? Color(j['accessoryColor'] as int) : null,
      showBlush: j['showBlush'] as bool? ?? true,
      faceShape: FaceShape.values[(j['faceShape'] as int? ?? 0).clamp(0, FaceShape.values.length - 1)],
      gender: Gender.values[(j['gender'] as int? ?? 2).clamp(0, Gender.values.length - 1)],
    );
  }

  /// Export current config as JSON (for debugging/backup)
  Map<String, dynamic> exportConfig() => _configToJson(state);
}

/// Provider for API service (needed for chibi sync)
/// Note: Uses the same apiServiceProvider from auth_provider
final chibiProvider = StateNotifierProvider<ChibiNotifier, ChibiConfig>((ref) {
  // Import apiServiceProvider from auth_provider
  // This avoids duplicate providers
  late final ApiService apiService;
  try {
    apiService = ref.watch(apiServiceProvider);
  } catch (_) {
    apiService = ApiService();
  }
  return ChibiNotifier(apiService);
});
