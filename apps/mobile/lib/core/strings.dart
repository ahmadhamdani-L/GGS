/// GGS Werewolf — String Constants (i18n foundation)
/// 
/// All user-facing strings should be defined here for future
/// internationalization (i18n/l10n) support.
/// 
/// Migration path to full i18n:
/// 1. Current: Static strings in this file (Indonesian)
/// 2. Phase 2: Use flutter_localizations + .arb files
/// 3. Phase 3: Server-driven strings for dynamic content
///
/// Usage: import 'package:ggs_werewolf/core/strings.dart';
///        Text(S.loginTitle)
///
class S {
  S._();

  // ─── Auth ───────────────────────────────────────────────
  static const loginTitle = 'Selamat datang kembali, Wolves! 🐺';
  static const registerTitle = 'Buat akun baru, Bergabunglah dengan Wolves!';
  static const loginButton = 'Login';
  static const registerButton = 'Daftar';
  static const forgotPassword = 'Lupa password?';
  static const guestButton = 'Main sebagai Tamu';
  static const socialComingSoon = 'Segera hadir!';
  static const termsText = 'Dengan mendaftar, kamu setuju dengan\nSyarat & Ketentuan dan Kebijakan Privasi';

  // ─── Home ──────────────────────────────────────────────
  static const playNow = 'Main Sekarang';
  static const playWithBot = 'Main dengan Bot';
  static const createRoom = 'Buat Room';
  static const joinRoom = 'Join Room';

  // ─── Lobby ─────────────────────────────────────────────
  static const startGame = 'MULAI GAME';
  static const ready = 'Siap';
  static const waiting = 'Waiting';
  static const invite = 'Invite';
  static const roomCode = 'ROOM CODE';

  // ─── Game ──────────────────────────────────────────────
  static const nightPhase = 'MALAM';
  static const dayPhase = 'HARI';
  static const discussionPhase = 'Waktu Diskusi';
  static const votingPhase = 'VOTE';
  static const eliminatedBadge = 'TERELIMINASI';
  static const skipVote = 'Skip Vote';
  static const submitVote = 'KIRIM VOTE';
  static const voteCountLabel = 'SUDAH MEMILIH';
  static const roleRevealTitle = 'PERANMU';
  static const tapToContinue = 'Tap untuk lanjut';
  static const voteResultTitle = 'HASIL VOTE';
  static const continueToNight = 'Game akan dilanjutkan ke malam hari.';
  static const noOneEliminated = 'Tidak ada yang tereliminasi';

  // ─── Roles ─────────────────────────────────────────────
  static const roleWerewolf = 'Werewolf';
  static const roleSeer = 'Seer';
  static const roleDoctor = 'Doctor';
  static const roleWitch = 'Witch';
  static const roleVillager = 'Villager';

  // ─── Chat ──────────────────────────────────────────────
  static const chatRoom = 'Chat Room';
  static const chatNight = 'Chat Night';
  static const typePlaceholder = 'Ketik pesan...';
  static const expand = 'Perbesar';
  static const collapse = 'Tutup';

  // ─── Settings ──────────────────────────────────────────
  static const settings = 'Pengaturan';
  static const music = 'Musik';
  static const sfx = 'Efek Suara';
  static const logout = 'Keluar';
  static const deleteAccount = 'Hapus Akun Permanen';

  // ─── Social ────────────────────────────────────────────
  static const friends = 'Teman';
  static const addFriend = 'Tambah Teman';
  static const sendGift = 'Kirim Gift';
  static const sendCurse = 'Kirim Kutuk';
  static const inventory = 'Inventory';
  static const shop = 'Toko';
  static const achievements = 'Achievements';
  static const leaderboard = 'Leaderboard';

  // ─── Errors ────────────────────────────────────────────
  static const networkError = 'Koneksi terputus. Periksa internet kamu.';
  static const timeout = 'Koneksi timeout — coba lagi';
  static const serverError = 'Terjadi kesalahan server';
  static const notEnoughPlayers = 'Butuh minimal 2 pemain untuk mulai';
}
