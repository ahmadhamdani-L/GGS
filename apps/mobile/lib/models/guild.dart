package models;

class Guild {
  final String id;
  final String name;
  final String tag;
  final String description;
  final String leaderId;
  final String avatarUrl;
  final int level;
  final int xp;
  final int maxMembers;
  final bool isPublic;
  final int memberCount;
  final DateTime createdAt;

  Guild({
    required this.id,
    required this.name,
    required this.tag,
    required this.description,
    required this.leaderId,
    required this.avatarUrl,
    required this.level,
    required this.xp,
    required this.maxMembers,
    required this.isPublic,
    required this.memberCount,
    required this.createdAt,
  });

  factory Guild.fromJson(Map<String, dynamic> json) {
    return Guild(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      tag: json['tag'] ?? '',
      description: json['description'] ?? '',
      leaderId: json['leaderId'] ?? '',
      avatarUrl: json['avatarUrl'] ?? '',
      level: json['level'] ?? 1,
      xp: json['xp'] ?? 0,
      maxMembers: json['maxMembers'] ?? 50,
      isPublic: json['isPublic'] ?? true,
      memberCount: json['memberCount'] ?? 1,
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : DateTime.now(),
    );
  }
}

class GuildMember {
  final String userId;
  final String displayName;
  final String role;
  final int level;
  final String joinedAt;

  GuildMember({
    required this.userId,
    required this.displayName,
    required this.role,
    required this.level,
    required this.joinedAt,
  });

  factory GuildMember.fromJson(Map<String, dynamic> json) {
    return GuildMember(
      userId: json['userId'] ?? '',
      displayName: json['displayName'] ?? '',
      role: json['role'] ?? '',
      level: json['level'] ?? 1,
      joinedAt: json['joinedAt'] ?? '',
    );
  }
}

class GuildChat {
  final String id;
  final String senderId;
  final String senderName;
  final String content;
  final DateTime createdAt;

  GuildChat({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.content,
    required this.createdAt,
  });

  factory GuildChat.fromJson(Map<String, dynamic> json) {
    return GuildChat(
      id: json['id'] ?? '',
      senderId: json['senderId'] ?? '',
      senderName: json['senderName'] ?? '',
      content: json['content'] ?? '',
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : DateTime.now(),
    );
  }
}
