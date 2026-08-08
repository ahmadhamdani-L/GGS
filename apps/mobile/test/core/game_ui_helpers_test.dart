import 'package:flutter_test/flutter_test.dart';
import 'package:ggs_werewolf/core/game_ui_helpers.dart';
import 'package:ggs_werewolf/models/player.dart';

void main() {
  group('GameUiHelpers', () {
    test('returns the correct night instruction for werewolf turn', () {
      expect(
        GameUiHelpers.nightTurnInstructions(role: Role.werewolf, turn: 'werewolf'),
        'Pilih pemain yang ingin kamu eliminasi',
      );
    });

    test('returns a retry-friendly voting instruction', () {
      expect(
        GameUiHelpers.voteInstruction(isRetry: true),
        '⚠️ Seri! Vote ulang antara pemain yang seri',
      );
    });
  });
}
