import 'package:flutter_test/flutter_test.dart';
import 'package:ggs_werewolf/core/constants.dart';

void main() {
  group('AppConstants', () {
    test('avatar count is correct', () {
      expect(AppConstants.avatarCount, 12);
    });

    test('avatar path format is correct', () {
      // avatarPath is 1-based
      expect(AppConstants.avatarPath(1), 'assets/avatars/avatar-1.png');
      expect(AppConstants.avatarPath(2), 'assets/avatars/avatar-2.png');
      expect(AppConstants.avatarPath(3), 'assets/avatars/avatar-3.png');
      expect(AppConstants.avatarPath(4), 'assets/avatars/avatar-4.png');
    });

    test('avatar path clamps for out-of-range index', () {
      // Index 0 should clamp to first avatar
      expect(AppConstants.avatarPath(0), 'assets/avatars/avatar-1.png');
      // Index 13+ should clamp to last avatar
      expect(AppConstants.avatarPath(13), 'assets/avatars/avatar-12.png');
    });

    test('avatarPathFromName returns correct path', () {
      expect(AppConstants.avatarPathFromName('boy'), 'assets/avatars/avatar-1.png');
      expect(AppConstants.avatarPathFromName('girl'), 'assets/avatars/avatar-3.png');
      expect(AppConstants.avatarPathFromName('boyS'), 'assets/avatars/avatar-2.png');
      expect(AppConstants.avatarPathFromName('girlS'), 'assets/avatars/avatar-4.png');
    });

    test('avatarPathFromName handles legacy avatar-N format', () {
      expect(AppConstants.avatarPathFromName('avatar-1'), 'assets/avatars/avatar-1.png');
      expect(AppConstants.avatarPathFromName('avatar-2'), 'assets/avatars/avatar-2.png');
      expect(AppConstants.avatarPathFromName('avatar-3'), 'assets/avatars/avatar-3.png');
    });

    test('avatarPathFromName handles null/empty', () {
      expect(AppConstants.avatarPathFromName(null), 'assets/avatars/avatar-1.png');
      expect(AppConstants.avatarPathFromName(''), 'assets/avatars/avatar-1.png');
    });

    test('getPlayerAvatar prefers avatarId when valid', () {
      expect(AppConstants.getPlayerAvatar('girl', 1), 'assets/avatars/avatar-1.png');
      expect(AppConstants.getPlayerAvatar('boy', 3), 'assets/avatars/avatar-3.png');
    });

    test('getPlayerAvatar falls back to name when avatarId invalid', () {
      expect(AppConstants.getPlayerAvatar('girl', 0), 'assets/avatars/avatar-3.png');
      expect(AppConstants.getPlayerAvatar('boyS', 99), 'assets/avatars/avatar-2.png');
    });
  });

  group('Game Constants', () {
    test('min players is reasonable', () {
      expect(AppConstants.minPlayers, greaterThanOrEqualTo(4));
      expect(AppConstants.minPlayers, lessThanOrEqualTo(8));
    });

    test('max players is reasonable', () {
      expect(AppConstants.maxPlayers, greaterThanOrEqualTo(12));
      expect(AppConstants.maxPlayers, lessThanOrEqualTo(20));
    });

    test('max players is greater than min players', () {
      expect(AppConstants.maxPlayers, greaterThan(AppConstants.minPlayers));
    });
  });

  group('Timer Constants', () {
    test('timer durations are positive', () {
      expect(AppConstants.defaultDiscussionTimer, greaterThan(0));
      expect(AppConstants.defaultVotingTimer, greaterThan(0));
      expect(AppConstants.defaultNightActionTimer, greaterThan(0));
    });

    test('discussion time is longest', () {
      expect(AppConstants.defaultDiscussionTimer, greaterThanOrEqualTo(AppConstants.defaultVotingTimer));
    });
  });

  group('Clothing', () {
    test('clothing items exist', () {
      expect(AppConstants.tops.isNotEmpty, true);
      expect(AppConstants.bottoms.isNotEmpty, true);
    });

    test('findClothingById returns correct item', () {
      final dres = AppConstants.findClothingById('dres');
      expect(dres, isNotNull);
      expect(dres!.name, 'Dress');
      expect(dres.category, ClothingCategory.top);
    });

    test('findClothingById returns null for unknown id', () {
      expect(AppConstants.findClothingById('unknown'), isNull);
      expect(AppConstants.findClothingById(null), isNull);
    });
  });
}
