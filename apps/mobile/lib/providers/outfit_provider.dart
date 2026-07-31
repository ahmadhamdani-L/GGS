import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants.dart';

/// Manages the player's outfit selection (persisted locally via SharedPreferences)
class OutfitNotifier extends StateNotifier<Outfit> {
  OutfitNotifier() : super(const Outfit()) {
    _load();
  }

  static const _key = 'player_outfit';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw != null) {
      try {
        state = Outfit.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {}
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(state.toJson()));
  }

  void setAvatar(int avatarId) {
    state = state.copyWith(avatarId: avatarId);
    _save();
  }

  void setTop(String? topId) {
    if (topId == state.topId) {
      // Toggle off
      state = state.copyWith(clearTop: true);
    } else {
      state = state.copyWith(topId: topId);
    }
    _save();
  }

  void setBottom(String? bottomId) {
    if (bottomId == state.bottomId) {
      // Toggle off
      state = state.copyWith(clearBottom: true);
    } else {
      state = state.copyWith(bottomId: bottomId);
    }
    _save();
  }

  void clearOutfit() {
    state = Outfit(avatarId: state.avatarId);
    _save();
  }
}

final outfitProvider = StateNotifierProvider<OutfitNotifier, Outfit>((ref) {
  return OutfitNotifier();
});
