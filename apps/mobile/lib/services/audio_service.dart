import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Audio service managing background music and sound effects
class AudioService {
  final AudioPlayer _bgmPlayer = AudioPlayer();
  final AudioPlayer _sfxPlayer = AudioPlayer();

  // Storage keys
  static const String _keyBgmVolume = 'audio_bgm_volume';
  static const String _keySfxVolume = 'audio_sfx_volume';
  static const String _keyBgmEnabled = 'audio_bgm_enabled';
  static const String _keySfxEnabled = 'audio_sfx_enabled';

  double _bgmVolume = 0.5;
  double _sfxVolume = 0.7;
  bool _bgmEnabled = true;
  bool _sfxEnabled = true;
  String? _currentBgm;
  bool _initialized = false;

  double get bgmVolume => _bgmVolume;
  double get sfxVolume => _sfxVolume;
  bool get bgmEnabled => _bgmEnabled;
  bool get sfxEnabled => _sfxEnabled;
  bool get isInitialized => _initialized;

  AudioService() {
    _bgmPlayer.setReleaseMode(ReleaseMode.loop);
    _loadSettings();
  }

  /// Load saved audio settings from SharedPreferences
  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _bgmVolume = prefs.getDouble(_keyBgmVolume) ?? 0.5;
      _sfxVolume = prefs.getDouble(_keySfxVolume) ?? 0.7;
      _bgmEnabled = prefs.getBool(_keyBgmEnabled) ?? true;
      _sfxEnabled = prefs.getBool(_keySfxEnabled) ?? true;
      _initialized = true;
    } catch (_) {
      // Use defaults if loading fails
      _initialized = true;
    }
  }

  /// Save current settings to SharedPreferences
  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_keyBgmVolume, _bgmVolume);
      await prefs.setDouble(_keySfxVolume, _sfxVolume);
      await prefs.setBool(_keyBgmEnabled, _bgmEnabled);
      await prefs.setBool(_keySfxEnabled, _sfxEnabled);
    } catch (_) {
      // Silently fail - settings will be lost on restart
    }
  }

  // --- BGM ---

  Future<void> playBgm(String track) async {
    if (!_bgmEnabled || _currentBgm == track) return;
    _currentBgm = track;
    try {
      await _bgmPlayer.stop();
      await _bgmPlayer.setVolume(_bgmVolume);
      await _bgmPlayer.play(AssetSource('audio/$track'));
    } catch (_) {
      _currentBgm = null;
    }
  }

  Future<void> stopBgm() async {
    _currentBgm = null;
    await _bgmPlayer.stop();
  }

  Future<void> setBgmVolume(double volume) async {
    _bgmVolume = volume.clamp(0.0, 1.0);
    await _bgmPlayer.setVolume(_bgmVolume);
    _saveSettings();
  }

  void toggleBgm(bool enabled) {
    _bgmEnabled = enabled;
    if (!enabled) stopBgm();
    _saveSettings();
  }

  // --- SFX ---

  Future<void> playSfx(String effect) async {
    if (!_sfxEnabled) return;
    try {
      await _sfxPlayer.setVolume(_sfxVolume);
      await _sfxPlayer.play(AssetSource('audio/$effect'));
    } catch (_) {}
  }

  Future<void> setSfxVolume(double volume) async {
    _sfxVolume = volume.clamp(0.0, 1.0);
    _saveSettings();
  }

  void toggleSfx(bool enabled) {
    _sfxEnabled = enabled;
    _saveSettings();
  }

  // --- BGM Track Names (actual files in assets/audio/bgm/) ---
  // The_Watcher_s_Garden.mp3 - mysterious, suitable for night
  // Morning_in_the_High_Meadows.mp3 - bright, suitable for day/lobby
  static const String _nightBgm = 'bgm/The_Watcher_s_Garden.mp3';
  static const String _dayBgm = 'bgm/Morning_in_the_High_Meadows.mp3';
  static const String _lobbyBgm = 'bgm/Morning_in_the_High_Meadows.mp3';

  // --- Phase-based BGM ---

  void playPhaseMusic(String phase) {
    switch (phase) {
      case 'NIGHT_START':
      case 'NIGHT':
      case 'WOLF_TURN':
      case 'DOCTOR_TURN':
      case 'WITCH_TURN':
      case 'SEER_TURN':
      case 'NIGHT_RESOLVE':
        playBgm(_nightBgm);
        break;
      case 'DAY_START':
      case 'DISCUSSION':
      case 'VOTING':
      case 'TESTAMENT':
        playBgm(_dayBgm);
        break;
      case 'ROLE_REVEAL':
        playSfx('sfx/role-reveal.mp3');
        playBgm(_lobbyBgm);
        break;
      case 'GAME_END':
        stopBgm();
        playSfx('sfx/victory.mp3');
        break;
      default:
        playBgm(_lobbyBgm);
    }
  }

  // --- SFX triggers ---

  void playVoteSfx() => playSfx('sfx/vote-cast.mp3');
  void playEliminationSfx() => playSfx('sfx/elimination.mp3');
  void playTimerWarningSfx() => playSfx('sfx/timer-warning.mp3');
  void playPhaseTransitionSfx() => playSfx('sfx/phase-transition.mp3');
  void playGameStartSfx() => playSfx('sfx/game-start.mp3');
  void playNightActionSfx() => playSfx('sfx/night-action.mp3');
  void playChatSfx() => playSfx('sfx/message.mp3');

  // --- Lifecycle ---

  void dispose() {
    _bgmPlayer.dispose();
    _sfxPlayer.dispose();
  }
}

/// Audio service provider
final audioServiceProvider = Provider<AudioService>((ref) {
  final service = AudioService();
  ref.onDispose(() => service.dispose());
  return service;
});
