import 'dart:io';
import 'package:flutter/material.dart';
import '../utils/constants.dart';
import 'package:on_audio_query/on_audio_query.dart';

class MusicSectionScreen extends StatelessWidget {
  final String title;
  final List<SongModel>? songs;
  final List<Map<String, String>>? downloadedEntries;
  final List<String>? folders;

  const MusicSectionScreen({
    super.key,
    required this.title,
    this.songs,
    this.downloadedEntries,
    this.folders,
  });

  @override
  Widget build(BuildContext context) {
    final isFolderList = folders != null;
    final isDownloaded = downloadedEntries != null;
    final listCount = isFolderList
        ? folders!.length
        : isDownloaded
            ? downloadedEntries!.length
            : songs?.length ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: const Color(0xFF0D1E36),
      ),
      backgroundColor: const Color(0xFF08101D),
      body: listCount == 0
          ? const Center(
              child: Text('No items', style: TextStyle(color: Colors.white54)),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: listCount,
              separatorBuilder: (_, __) => const Divider(color: Colors.white12),
              itemBuilder: (context, index) {
                if (isFolderList) {
                  final folder = folders![index];
                  return ListTile(
                    title: Text(folder, style: const TextStyle(color: Colors.white)),
                    subtitle: const Text('Folder', style: TextStyle(color: Colors.white54)),
                    trailing: const Icon(Icons.chevron_right, color: Colors.white54),
                    onTap: () => Navigator.pop(context, folder),
                  );
                }

                if (isDownloaded) {
                  final item = downloadedEntries![index];
                  return ListTile(
                    leading: const Icon(Icons.download_done_rounded, color: kNeonGreen),
                    title: Text(item['title'] ?? 'Downloaded', style: const TextStyle(color: Colors.white)),
                    subtitle: Text(item['artist'] ?? '', style: const TextStyle(color: Colors.white54)),
                    onTap: () async {
                      final file = File(item['path'] ?? '');
                      if (!file.existsSync()) return;
                      // return path to caller
                      Navigator.pop(context, file.path);
                    },
                  );
                }

                final song = songs![index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.white12,
                    child: Text(
                      (song.title.isNotEmpty ? song.title[0] : '♪').toUpperCase(),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  title: Text(song.title, style: const TextStyle(color: Colors.white)),
                  subtitle: Text(song.artist ?? '', style: const TextStyle(color: Colors.white54)),
                  onTap: () => Navigator.pop(context, song),
                );
              },
            ),
    );
  }
}
