import '../models/player.dart';

class GameUiHelpers {
  static String nightTurnInstructions({required Role role, required String turn}) {
    if (turn.isEmpty) {
      return role == Role.werewolf
          ? 'Pilih pemain yang ingin kamu eliminasi'
          : 'Pilih aksi yang ingin kamu lakukan';
    }

    return switch (role) {
      Role.werewolf => 'Pilih pemain yang ingin kamu eliminasi',
      Role.doctor => 'Pilih pemain yang ingin kamu lindungi',
      Role.seer => 'Pilih pemain yang ingin kamu selidiki',
      _ => 'Pilih aksi yang ingin kamu lakukan',
    };
  }

  static String voteInstruction({required bool isRetry}) {
    return isRetry
        ? '⚠️ Seri! Vote ulang antara pemain yang seri'
        : 'Pilih pemain yang menurutmu adalah Werewolf!';
  }
}
