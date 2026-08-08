class LevelProgress {
  static const List<int> thresholds = [
    0,
    100,
    250,
    500,
    850,
    1300,
    1900,
    2600,
    3500,
    4600,
    5900,
    7500,
    9400,
    11600,
    14200,
    17200,
    20700,
    24700,
    29300,
    34500,
  ];

  static int thresholdAt(int level) {
    if (level <= 0) return 0;
    if (level < thresholds.length) return thresholds[level];
    return 34500 + (level - 19) * 5000;
  }

  static double progressForXp({required int level, required int xp}) {
    final current = level > 1 ? thresholdAt(level - 1) : 0;
    final next = thresholdAt(level);
    if (next <= current) return 1.0;
    return ((xp - current) / (next - current)).clamp(0.0, 1.0);
  }
}
