import 'package:flutter_test/flutter_test.dart';
import 'package:ggs_werewolf/core/social_ui_helpers.dart';

void main() {
  group('SocialUiHelpers', () {
    test('formats leaderboard score labels correctly', () {
      expect(SocialUiHelpers.scoreLabel(boardType: 'charm', score: 120), '✨ 120');
      expect(SocialUiHelpers.scoreLabel(boardType: 'gift_sent', score: 8), '🎁 8 hadiah');
    });

    test('returns a friendly empty state message', () {
      expect(SocialUiHelpers.emptyStateMessage('gift_history'), 'Belum ada riwayat interaksi sosial.');
    });
  });
}
