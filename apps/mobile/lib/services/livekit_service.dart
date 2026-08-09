import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart';

class LiveKitService extends ChangeNotifier {
  Room? _room;
  bool _isConnected = false;
  EventsListener<RoomEvent>? _listener;
  List<String> _activeSpeakers = [];
  bool _isSpeakerMuted = false;

  bool get isConnected => _isConnected;
  Room? get room => _room;
  List<String> get activeSpeakers => _activeSpeakers;
  bool get isSpeakerMuted => _isSpeakerMuted;

  Future<void> connect(String url, String token) async {
    try {
      _room = Room();
      _listener = _room!.createListener();
      
      _listener!.on<ActiveSpeakersChangedEvent>((event) {
        _activeSpeakers = event.speakers.map((p) => p.identity).toList();
        notifyListeners();
      });

      await _room!.connect(url, token);
      _isConnected = true;
      notifyListeners();
    } catch (e) {
      debugPrint('LiveKit connection error: $e');
    }
  }

  Future<void> disconnect() async {
    if (_room != null) {
      await _room!.disconnect();
      await _listener?.dispose();
      _listener = null;
      _room = null;
    }
    _isConnected = false;
    _activeSpeakers = [];
    notifyListeners();
  }

  Future<void> setMicrophoneEnabled(bool enabled) async {
    if (_room == null || _room!.localParticipant == null) return;
    await _room!.localParticipant!.setMicrophoneEnabled(enabled);
    notifyListeners();
  }

  Future<void> setSpeakerMuted(bool muted) async {
    if (_room == null) return;
    _isSpeakerMuted = muted;
    // Iterate over remote participants to mute their audio output
    for (var participant in _room!.remoteParticipants.values) {
      for (var publication in participant.audioTrackPublications) {
        final track = publication.track;
        if (track is RemoteAudioTrack) {
          track.setVolume(muted ? 0.0 : 1.0);
        }
      }
    }
    notifyListeners();
  }
}
