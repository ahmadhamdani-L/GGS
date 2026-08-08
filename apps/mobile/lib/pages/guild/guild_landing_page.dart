import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/guild_provider.dart';
import '../../models/guild.dart';

class GuildLandingPage extends ConsumerStatefulWidget {
  const GuildLandingPage({super.key});

  @override
  ConsumerState<GuildLandingPage> createState() => _GuildLandingPageState();
}

class _GuildLandingPageState extends ConsumerState<GuildLandingPage> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(guildProvider.notifier).searchGuilds(""));
  }

  void _createGuildDialog() {
    final nameCtrl = TextEditingController();
    final tagCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text("Buat Guild Baru", style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: "Nama Guild (3-20 char)", labelStyle: TextStyle(color: Colors.white54)),
            ),
            TextField(
              controller: tagCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: "Tag (2-6 char)", labelStyle: TextStyle(color: Colors.white54)),
            ),
            TextField(
              controller: descCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: "Deskripsi", labelStyle: TextStyle(color: Colors.white54)),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Batal")),
          ElevatedButton(
            onPressed: () async {
              final success = await ref.read(guildProvider.notifier).createGuild(nameCtrl.text, tagCtrl.text, descCtrl.text);
              if (success && mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Guild berhasil dibuat!")));
                // Dashboard will automatically be pushed via routing listener later, or we can push it
              } else {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ref.read(guildProvider).error ?? "Gagal")));
              }
            },
            child: const Text("Buat"),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(guildProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0F1B3D),
      appBar: AppBar(
        title: const Text("Pencarian Guild"),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: "Cari nama atau tag...",
                      hintStyle: const TextStyle(color: Colors.white54),
                      prefixIcon: const Icon(Icons.search, color: Colors.white54),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.1),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onSubmitted: (val) {
                      ref.read(guildProvider.notifier).searchGuilds(val);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _createGuildDialog,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text("Buat", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          if (state.isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (state.searchResults.isEmpty)
            const Expanded(child: Center(child: Text("Tidak ada guild ditemukan.", style: TextStyle(color: Colors.white54))))
          else
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: state.searchResults.length,
                itemBuilder: (ctx, i) {
                  final g = state.searchResults[i];
                  return Card(
                    color: Colors.white.withOpacity(0.05),
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      title: Text(g.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      subtitle: Text("[${g.tag}] - Level ${g.level} - ${g.memberCount}/${g.maxMembers} Anggota", style: const TextStyle(color: Colors.white70)),
                      trailing: ElevatedButton(
                        onPressed: () async {
                          final success = await ref.read(guildProvider.notifier).joinGuild(g.id);
                          if (success && mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Berhasil bergabung!")));
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ref.read(guildProvider).error ?? "Gagal")));
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigoAccent,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text("Gabung", style: TextStyle(color: Colors.white)),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
