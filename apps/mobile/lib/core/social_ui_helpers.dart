class SocialUiHelpers {
  static String scoreLabel({required String boardType, required int score}) {
    switch (boardType) {
      case 'charm':
        return '✨ $score';
      case 'popularity':
        return '🌟 $score';
      case 'gift_sent':
        return '🎁 $score hadiah';
      case 'gift_received':
        return '💝 $score hadiah';
      case 'legendary_sent':
        return '👑 $score legendary';
      case 'curse_sent':
        return '😈 $score curse';
      default:
        return '$score';
    }
  }

  static String emptyStateMessage(String contextKey) {
    switch (contextKey) {
      case 'gift_history':
        return 'Belum ada riwayat interaksi sosial.';
      case 'leaderboard':
        return 'Belum ada data leaderboard untuk periode ini.';
      default:
        return 'Belum ada data.';
    }
  }
}
