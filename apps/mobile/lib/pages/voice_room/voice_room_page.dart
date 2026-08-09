import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/theme.dart';
import '../../models/room_v2.dart';
import '../../providers/room_provider_v2.dart';
import '../../providers/auth_provider.dart';
import '../../providers/livekit_provider.dart';
import '../../services/audio_service.dart';

class VoiceRoomPage extends ConsumerStatefulWidget {
  final String roomId;
  const VoiceRoomPage({super.key, required this.roomId});

  @override
  ConsumerState<VoiceRoomPage> createState() => _VoiceRoomPageState();
}

class _VoiceRoomPageState extends ConsumerState<VoiceRoomPage> {
  final _chatCtrl = TextEditingController();
  StreamSubscription? _tokenSub;
  bool _isMicMuted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initLiveKit();
      // Start background music when entering voice room
      ref.read(audioServiceProvider).playBgm('bgm/Morning_in_the_High_Meadows.mp3');
    });
  }

  void _initLiveKit() {
    final user = ref.read(authProvider).profile;
    if (user == null) return;
    
    // Listen for token responses
    _tokenSub = ref.read(roomV2Provider.notifier).livekitTokens.listen((data) async {
      if (!mounted) return;
      final token = data['token']!;
      final url = data['url']!;
      
      final liveKit = ref.read(liveKitProvider);
      if (liveKit.isConnected) {
        await liveKit.disconnect();
      }
      
      await liveKit.connect(url, token);
      _syncMicState();
    });

    _requestLiveKitToken();
  }

  void _requestLiveKitToken() {
    final user = ref.read(authProvider).profile;
    final room = ref.read(roomV2Provider);
    if (user == null || room == null) return;

    // Check if user is seated
    final isSpeaker = room.seats.any((s) => s.playerId == user.id);
    ref.read(roomV2Provider.notifier).getLiveKitToken(widget.roomId, user.displayName, isSpeaker);
  }

  void _syncMicState() async {
    final user = ref.read(authProvider).profile;
    final room = ref.read(roomV2Provider);
    if (user == null || room == null) return;

    final isSpeaker = room.seats.any((s) => s.playerId == user.id);
    if (isSpeaker) {
      await Permission.microphone.request();
      ref.read(liveKitProvider).setMicrophoneEnabled(!_isMicMuted);
    } else {
      ref.read(liveKitProvider).setMicrophoneEnabled(false);
    }
  }

  @override
  void dispose() {
    _tokenSub?.cancel();
    ref.read(liveKitProvider).disconnect();
    _chatCtrl.dispose();
    
    // Stop background music when leaving
    final audio = ref.read(audioServiceProvider);
    audio.stopBgm();
    
    super.dispose();
  }

  void _sendChat() {
    final text = _chatCtrl.text.trim();
    if (text.isEmpty) return;
    ref.read(roomV2Provider.notifier).sendChat(widget.roomId, text);
    _chatCtrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(roomV2Provider, (prev, next) {
      if (!mounted) return;
      if (prev != null && next != null) {
        final user = ref.read(authProvider).profile;
        if (user != null) {
          final wasSpeaker = prev.seats.any((s) => s.playerId == user.id);
          final isSpeaker = next.seats.any((s) => s.playerId == user.id);
          if (wasSpeaker != isSpeaker) {
            _requestLiveKitToken();
          }
        }
      }
    });

    final roomState = ref.watch(roomV2Provider);
    final user = ref.watch(authProvider).profile;

    if (roomState == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    final isHost = roomState.hostId == user?.id;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(roomState.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text('ID: ${roomState.code}', style: const TextStyle(fontSize: 12, color: Colors.white70)),
          ],
        ),
        actions: [
          Consumer(
            builder: (context, ref, child) {
              final isAudioEnabled = ref.watch(audioServiceProvider).bgmEnabled;
              return IconButton(
                icon: Icon(
                  isAudioEnabled ? Icons.music_note : Icons.music_off,
                  color: Colors.white,
                ),
                onPressed: () {
                  final audio = ref.read(audioServiceProvider);
                  audio.toggleBgm(!audio.bgmEnabled);
                  if (audio.bgmEnabled) {
                    audio.playBgm('bgm/Morning_in_the_High_Meadows.mp3');
                  }
                  // Force rebuild of icon
                  setState(() {});
                },
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.exit_to_app, color: Colors.white),
            onPressed: () {
              ref.read(roomV2Provider.notifier).leaveRoom(user?.id ?? '', widget.roomId);
              Navigator.pop(context);
            },
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/malam.png'), // Placeholder background
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // 1. Host Seat (Top Center)
              const SizedBox(height: 20),
              _buildSeat(roomState, 0, isHost: true),

              // 2. Guest Seats (Row 1: 4 seats, Row 2: 3 seats)
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildSeat(roomState, 1),
                  _buildSeat(roomState, 2),
                  _buildSeat(roomState, 3),
                  _buildSeat(roomState, 4),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildSeat(roomState, 5),
                  _buildSeat(roomState, 6),
                  _buildSeat(roomState, 7),
                ],
              ),

              const Spacer(),

              // 3. VIP / Audience Area
              Container(
                height: 50,
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(25),
                ),
                child: Row(
                  children: [
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text('VIP Area', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    ),
                    Expanded(
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: 10, // Dummy
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: const EdgeInsets.all(4.0),
                            child: CircleAvatar(
                              radius: 18,
                              backgroundColor: Colors.primaries[index % Colors.primaries.length],
                              child: Text('${index + 1}', style: const TextStyle(fontSize: 10, color: Colors.white)),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // 4. Chat Overlay
              Consumer(
                builder: (context, ref, child) {
                  final chats = ref.watch(roomChatProvider).reversed.toList();
                  return Container(
                    height: 150,
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListView.builder(
                      padding: const EdgeInsets.all(8),
                      reverse: true,
                      itemCount: chats.isEmpty ? 1 : chats.length,
                      itemBuilder: (context, index) {
                        if (chats.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: RichText(
                              text: const TextSpan(
                                children: [
                                  TextSpan(
                                    text: '[Sistem] ',
                                    style: TextStyle(color: Colors.yellow, fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                  TextSpan(
                                    text: 'Selamat datang di Voice Room!',
                                    style: TextStyle(color: Colors.white, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }

                        final chat = chats[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: RichText(
                            text: TextSpan(
                              children: [
                                TextSpan(
                                  text: '[${chat.displayName}] ',
                                  style: const TextStyle(color: Colors.blueAccent, fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                                TextSpan(
                                  text: chat.message,
                                  style: const TextStyle(color: Colors.white, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),

              // 5. Bottom Controls
              Container(
                padding: const EdgeInsets.all(12),
                color: Colors.black.withValues(alpha: 0.5),
                child: Row(
                  children: [
                    Consumer(
                      builder: (context, ref, child) {
                        final isMuted = ref.watch(liveKitProvider).isSpeakerMuted;
                        return IconButton(
                          icon: Icon(isMuted ? Icons.volume_off : Icons.volume_up, color: isMuted ? Colors.redAccent : Colors.white),
                          onPressed: () {
                            ref.read(liveKitProvider).setSpeakerMuted(!isMuted);
                          },
                        );
                      }
                    ),
                    IconButton(
                      icon: Icon(_isMicMuted ? Icons.mic_off : Icons.mic, color: _isMicMuted ? Colors.redAccent : Colors.white),
                      onPressed: () {
                        setState(() {
                          _isMicMuted = !_isMicMuted;
                        });
                        _syncMicState();
                      },
                    ),
                    Expanded(
                      child: Container(
                        height: 36,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: TextField(
                          controller: _chatCtrl,
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            hintText: 'Ngobrol yuk...',
                            hintStyle: TextStyle(color: Colors.white54),
                          ),
                          onSubmitted: (_) => _sendChat(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.card_giftcard, color: Colors.pinkAccent),
                      onPressed: () {},
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSeat(RoomStateV2 room, int index, {bool isHost = false}) {
    final seat = room.seats.where((s) => s.index == index).firstOrNull;
    final isOccupied = seat != null && seat.playerId.isNotEmpty;
    final isSpeaking = isOccupied && ref.watch(liveKitProvider).activeSpeakers.contains(seat.playerId);

    return GestureDetector(
      onTap: () {
        if (!isOccupied) {
          final user = ref.read(authProvider).profile;
          if (user != null) {
            ref.read(roomV2Provider.notifier).selectSeat(user.id, widget.roomId, index);
          }
        } else {
          // Show profile dialog
        }
      },
      child: Column(
        children: [
          Container(
            width: isHost ? 70 : 56,
            height: isHost ? 70 : 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isOccupied ? Colors.transparent : Colors.orangeAccent.withValues(alpha: 0.8),
              border: Border.all(
                color: isSpeaking 
                  ? Colors.greenAccent 
                  : (isHost ? Colors.amber : Colors.transparent), 
                width: isSpeaking ? 3 : 2
              ),
              boxShadow: isSpeaking 
                  ? [const BoxShadow(color: Colors.greenAccent, blurRadius: 8, spreadRadius: 2)] 
                  : null,
            ),
            child: isOccupied
                ? CircleAvatar(
                    backgroundImage: AssetImage('assets/avatars/avatar-${seat.avatarId}.png'),
                  )
                : const Center(
                    child: Text('SIT\nDOWN', textAlign: TextAlign.center, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
          ),
          const SizedBox(height: 4),
          Text(
            isOccupied ? seat.displayName : (isHost ? 'Host' : 'Seat ${index + 1}'),
            style: const TextStyle(color: Colors.white, fontSize: 10, shadows: [Shadow(color: Colors.black, blurRadius: 2)]),
          ),
        ],
      ),
    );
  }
}
