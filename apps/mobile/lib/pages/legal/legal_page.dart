import 'package:flutter/material.dart';
import '../../core/theme.dart';

enum LegalPageType { privacyPolicy, termsOfService }

class LegalPage extends StatelessWidget {
  final LegalPageType type;
  const LegalPage({required this.type, super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          type == LegalPageType.privacyPolicy
              ? 'Kebijakan Privasi'
              : 'Syarat & Ketentuan',
          style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w700),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: type == LegalPageType.privacyPolicy
            ? const _PrivacyPolicyContent()
            : const _TermsOfServiceContent(),
      ),
    );
  }
}

// ─── Privacy Policy ───────────────────────────────────────────

class _PrivacyPolicyContent extends StatelessWidget {
  const _PrivacyPolicyContent();

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _heading('Kebijakan Privasi GGS Werewolf'),
      _body('Terakhir diperbarui: 1 Agustus 2026'),
      _spacer(),

      _section('1. Data yang Kami Kumpulkan'),
      _body('Kami mengumpulkan data berikut saat kamu mendaftar dan menggunakan layanan GGS Werewolf:'),
      _bullet('Informasi akun: alamat email, nama tampilan, dan kata sandi (disimpan dengan enkripsi bcrypt).'),
      _bullet('Foto profil: jika kamu mengunggah foto avatar, foto tersebut disimpan di server kami.'),
      _bullet('Data permainan: statistik permainan, histori pertandingan, dan pencapaian.'),
      _bullet('Data sosial: interaksi Gift/Curse, Charm, dan Popularitas.'),
      _bullet('Transaksi Diamond: riwayat pembelian dan pengeluaran Diamond.'),
      _bullet('Token perangkat: token notifikasi push (FCM) untuk mengirim pemberitahuan.'),
      _spacer(),

      _section('2. Cara Kami Menggunakan Data'),
      _bullet('Menyediakan layanan permainan dan fitur sosial.'),
      _bullet('Mengirim notifikasi yang relevan (hadiah diterima, undangan game, reset misi).'),
      _bullet('Mendeteksi dan mencegah penyalahgunaan, kecurangan, dan konten tidak pantas.'),
      _bullet('Meningkatkan pengalaman bermain berdasarkan analitik penggunaan.'),
      _spacer(),

      _section('3. Penyimpanan dan Keamanan Data'),
      _body('Data disimpan di server yang dilindungi dengan enkripsi HTTPS/TLS. Kata sandi tidak disimpan dalam bentuk teks biasa. Data permainan aktif dapat dicadangkan untuk pemulihan setelah gangguan server.'),
      _spacer(),

      _section('4. Berbagi Data'),
      _body('Kami TIDAK menjual data pribadimu kepada pihak ketiga. Data dapat dibagikan hanya:'),
      _bullet('Kepada penyedia layanan teknis yang membantu operasional (hosting, CDN).'),
      _bullet('Jika diwajibkan oleh hukum yang berlaku.'),
      _spacer(),

      _section('5. Foto Avatar'),
      _body('Foto yang kamu unggah sebagai avatar disimpan di server kami dan ditampilkan kepada pemain lain. Foto dapat dihapus kapan saja melalui Pengaturan Profil. Kami berhak menghapus foto yang melanggar pedoman komunitas.'),
      _spacer(),

      _section('6. Hak Pengguna'),
      _bullet('Mengakses dan mengunduh data pribadimu.'),
      _bullet('Menghapus akun dan semua data terkait kapan saja.'),
      _bullet('Memperbarui informasi profil kapan saja.'),
      _body('Untuk menggunakan hak-hak ini, hubungi kami atau gunakan fitur Hapus Akun di Pengaturan.'),
      _spacer(),

      _section('7. Pengguna di Bawah Umur'),
      _body('GGS Werewolf ditujukan untuk pengguna berusia 13 tahun ke atas. Jika kami mengetahui bahwa anak di bawah 13 tahun telah mendaftar, akun akan segera dihapus.'),
      _spacer(),

      _section('8. Perubahan Kebijakan'),
      _body('Kebijakan ini dapat diperbarui sewaktu-waktu. Perubahan signifikan akan diberitahukan melalui notifikasi dalam aplikasi.'),
      _spacer(),

      _section('9. Kontak'),
      _body('Jika ada pertanyaan tentang kebijakan privasi ini, silakan hubungi kami di: privacy@ggs-werewolf.com'),
      const SizedBox(height: 40),
    ]);
  }
}

// ─── Terms of Service ─────────────────────────────────────────

class _TermsOfServiceContent extends StatelessWidget {
  const _TermsOfServiceContent();

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _heading('Syarat & Ketentuan GGS Werewolf'),
      _body('Terakhir diperbarui: 1 Agustus 2026'),
      _spacer(),

      _section('1. Penerimaan Syarat'),
      _body('Dengan mengunduh, mendaftar, atau menggunakan GGS Werewolf ("Layanan"), kamu menyetujui syarat dan ketentuan ini. Jika tidak setuju, jangan gunakan Layanan.'),
      _spacer(),

      _section('2. Akun Pengguna'),
      _bullet('Kamu bertanggung jawab menjaga kerahasiaan kata sandi akun.'),
      _bullet('Satu pengguna hanya boleh memiliki satu akun aktif.'),
      _bullet('Akun tamu memiliki fitur terbatas dan dapat dihapus sewaktu-waktu.'),
      _spacer(),

      _section('3. Diamond dan Transaksi'),
      _bullet('Diamond adalah mata uang virtual premium dalam Layanan.'),
      _bullet('Pembelian Diamond bersifat final dan tidak dapat dikembalikan (kecuali diwajibkan hukum).'),
      _bullet('Diamond tidak memiliki nilai moneter dan tidak dapat ditukarkan dengan uang nyata.'),
      _bullet('Kami berhak menyesuaikan harga Diamond sewaktu-waktu.'),
      _spacer(),

      _section('4. Aturan Penggunaan'),
      _body('Pengguna DILARANG:'),
      _bullet('Menggunakan cheat, bot, atau perangkat lunak pihak ketiga untuk keuntungan tidak fair.'),
      _bullet('Melakukan pelecehan, perundungan, atau konten kebencian terhadap pemain lain.'),
      _bullet('Mengunggah foto atau konten yang tidak pantas sebagai avatar.'),
      _bullet('Mencoba mengeksploitasi bug atau celah keamanan Layanan.'),
      _bullet('Menjual, memindahtangankan, atau memperdagangkan akun.'),
      _spacer(),

      _section('5. Konten Pengguna'),
      _body('Dengan mengunggah konten (termasuk foto avatar, nama tampilan, pesan chat), kamu memberikan kami lisensi untuk menampilkan konten tersebut dalam Layanan. Kami berhak menghapus konten yang melanggar pedoman komunitas.'),
      _spacer(),

      _section('6. Penghentian Layanan'),
      _body('Kami berhak menangguhkan atau menghapus akun yang melanggar syarat ini tanpa pemberitahuan sebelumnya. Penghapusan akun berarti semua data, Diamond, dan progres permainan dihapus permanen.'),
      _spacer(),

      _section('7. Batasan Tanggung Jawab'),
      _body('GGS Werewolf disediakan "sebagaimana adanya". Kami tidak bertanggung jawab atas kerugian yang timbul dari gangguan layanan, kehilangan data, atau penggunaan yang tidak sah oleh pihak ketiga.'),
      _spacer(),

      _section('8. Perubahan Syarat'),
      _body('Kami dapat memperbarui syarat ini. Penggunaan berkelanjutan setelah perubahan berarti kamu menerima syarat yang diperbarui.'),
      _spacer(),

      _section('9. Hukum yang Berlaku'),
      _body('Syarat ini diatur oleh hukum Republik Indonesia. Sengketa diselesaikan melalui musyawarah atau pengadilan yang berwenang di Indonesia.'),
      const SizedBox(height: 40),
    ]);
  }
}

// ─── Shared helpers ───────────────────────────────────────────

Widget _heading(String text) => Padding(
  padding: const EdgeInsets.only(bottom: 8),
  child: Text(text, style: const TextStyle(
    color: AppColors.primary, fontSize: 18, fontWeight: FontWeight.w800)),
);

Widget _section(String text) => Padding(
  padding: const EdgeInsets.only(top: 16, bottom: 6),
  child: Text(text, style: const TextStyle(
    color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
);

Widget _body(String text) => Padding(
  padding: const EdgeInsets.only(bottom: 6),
  child: Text(text, style: const TextStyle(
    color: AppColors.textSecondary, fontSize: 13, height: 1.55)),
);

Widget _bullet(String text) => Padding(
  padding: const EdgeInsets.only(left: 12, bottom: 4),
  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const Text('• ', style: TextStyle(color: AppColors.primary, fontSize: 13)),
    Expanded(child: Text(text, style: const TextStyle(
      color: AppColors.textSecondary, fontSize: 13, height: 1.5))),
  ]),
);

Widget _spacer() => const SizedBox(height: 8);
