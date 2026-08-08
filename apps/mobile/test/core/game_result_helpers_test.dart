import 'package:flutter_test/flutter_test.dart';
import 'package:ggs_werewolf/core/game_result_helpers.dart';

void main() {
  group('GameResultHelpers', () {
    test('formats reward summary for a win', () {
      expect(
        GameResultHelpers.summaryLabel(xp: 40, coins: 25, won: true),
        'Kemenangan +40 XP • +25 Koin',
      );
    });

    test('formats a loss summary', () {
      expect(
        GameResultHelpers.summaryLabel(xp: 10, coins: 5, won: false),
        'Kalah +10 XP • +5 Koin',
      );
    });
  });
}
