import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/guild.dart';
import '../services/api_service.dart';
import 'auth_provider.dart';

final apiServiceProvider = Provider<ApiService>((ref) {
  final apiService = ApiService();
  final token = ref.watch(authProvider).token;
  apiService.setToken(token);
  return apiService;
});

final guildProvider = StateNotifierProvider<GuildNotifier, GuildState>((ref) {
  return GuildNotifier(ref.read(apiServiceProvider));
});

class GuildState {
  final Guild? currentGuild;
  final List<Guild> searchResults;
  final List<GuildMember> members;
  final List<GuildChat> chats;
  final bool isLoading;
  final String? error;

  GuildState({
    this.currentGuild,
    this.searchResults = const [],
    this.members = const [],
    this.chats = const [],
    this.isLoading = false,
    this.error,
  });

  GuildState copyWith({
    Guild? currentGuild,
    List<Guild>? searchResults,
    List<GuildMember>? members,
    List<GuildChat>? chats,
    bool? isLoading,
    String? error,
  }) {
    return GuildState(
      currentGuild: currentGuild ?? this.currentGuild,
      searchResults: searchResults ?? this.searchResults,
      members: members ?? this.members,
      chats: chats ?? this.chats,
      isLoading: isLoading ?? false, // default reset to false unless specified
      error: error,
    );
  }
}

class GuildNotifier extends StateNotifier<GuildState> {
  final ApiService _api;

  GuildNotifier(this._api) : super(GuildState());

  Future<void> fetchMyGuild(String guildId) async {
    if (guildId.isEmpty) return;
    state = state.copyWith(isLoading: true);
    final res = await _api.getGuild(guildId);
    if (res.isSuccess && res.data != null) {
      state = state.copyWith(
        currentGuild: Guild.fromJson(res.data!),
        isLoading: false,
      );
      // Fetch members and chats in background
      fetchMembers(guildId);
      fetchChats(guildId);
    } else {
      state = state.copyWith(error: res.error, isLoading: false);
    }
  }

  Future<bool> createGuild(String name, String tag, String description) async {
    state = state.copyWith(isLoading: true);
    final res = await _api.createGuild(name, tag, description);
    if (res.isSuccess && res.data != null) {
      final newGuild = Guild.fromJson(res.data!);
      state = state.copyWith(currentGuild: newGuild, isLoading: false);
      return true;
    } else {
      state = state.copyWith(error: res.error, isLoading: false);
      return false;
    }
  }

  Future<bool> joinGuild(String guildId) async {
    state = state.copyWith(isLoading: true);
    final res = await _api.joinGuild(guildId);
    if (res.isSuccess) {
      await fetchMyGuild(guildId);
      return true;
    } else {
      state = state.copyWith(error: res.error, isLoading: false);
      return false;
    }
  }

  Future<bool> leaveGuild() async {
    state = state.copyWith(isLoading: true);
    final res = await _api.leaveGuild();
    if (res.isSuccess) {
      state = GuildState(); // reset completely
      return true;
    } else {
      state = state.copyWith(error: res.error, isLoading: false);
      return false;
    }
  }

  Future<void> searchGuilds(String query) async {
    state = state.copyWith(isLoading: true);
    final res = await _api.searchGuilds(query);
    if (res.isSuccess && res.data != null) {
      final list = res.data!.map((e) => Guild.fromJson(e)).toList();
      state = state.copyWith(searchResults: list, isLoading: false);
    } else {
      state = state.copyWith(error: res.error, isLoading: false);
    }
  }

  Future<void> fetchMembers(String guildId) async {
    final res = await _api.getGuildMembers(guildId);
    if (res.isSuccess && res.data != null) {
      final list = res.data!.map((e) => GuildMember.fromJson(e)).toList();
      state = state.copyWith(members: list);
    }
  }

  Future<void> fetchChats(String guildId) async {
    final res = await _api.getGuildChat(guildId);
    if (res.isSuccess && res.data != null) {
      final list = res.data!.map((e) => GuildChat.fromJson(e)).toList();
      state = state.copyWith(chats: list);
    }
  }

  Future<bool> sendChat(String guildId, String content) async {
    final res = await _api.sendGuildChat(guildId, content);
    if (res.isSuccess) {
      // Re-fetch chats
      await fetchChats(guildId);
      return true;
    }
    return false;
  }
}
