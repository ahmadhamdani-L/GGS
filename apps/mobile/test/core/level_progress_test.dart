import 'package:flutter_test/flutter_test.dart';
import 'package:ggs_werewolf/core/level_progress.dart';

void main() {
  group('LevelProgress', () {
    test('returns the expected threshold for early levels', () {
      expect(LevelProgress.thresholdAt(0), 0);
      expect(LevelProgress.thresholdAt(1), 100);
      expect(LevelProgress.thresholdAt(3), 500);
    });

    test('returns a capped progress for levels above 20', () {
      expect(LevelProgress.progressForXp(level: 1, xp: 50), closeTo(0.5, 0.0001));
      expect(LevelProgress.progressForXp(level: 2, xp: 220), closeTo(0.8, 0.0001));
      expect(LevelProgress.progressForXp(level: 20, xp: 100000), 1.0);
    });
  });
}
