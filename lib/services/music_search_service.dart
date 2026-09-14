import 'dart:convert';
import 'package:http/http.dart' as http;

class MusicSearchResult {
  const MusicSearchResult({
    required this.title,
    required this.artist,
    required this.previewUrl,
    required this.thumbnailUrl,
  });

  final String title;
  final String artist;
  final String previewUrl;
  final String thumbnailUrl;
}

class MusicSearchService {
  static Future<List<MusicSearchResult>> search(String query) async {
    final safeQuery = Uri.encodeComponent(query.trim());
    final url = Uri.parse('https://itunes.apple.com/search?term=$safeQuery&media=music&limit=10');

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) return const [];

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final results = body['results'] as List<dynamic>? ?? const [];

      return results.whereType<Map<String, dynamic>>().map((item) {
        final trackName = item['trackName']?.toString() ?? 'Unknown track';
        final artistName = item['artistName']?.toString() ?? 'Unknown artist';
        final previewUrl = item['previewUrl']?.toString() ?? '';
        final artwork = item['artworkUrl100']?.toString() ?? '';

        return MusicSearchResult(
          title: trackName,
          artist: artistName,
          previewUrl: previewUrl,
          thumbnailUrl: artwork,
        );
      }).where((item) => item.previewUrl.isNotEmpty).toList();
    } catch (_) {
      return const [];
    }
  }
}
