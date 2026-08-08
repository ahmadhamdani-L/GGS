class GameResultHelpers {
  static String summaryLabel({required int xp, required int coins, required bool won}) {
    final result = won ? 'Kemenangan' : 'Kalah';
    return '$result +$xp XP • +$coins Koin';
  }
}
