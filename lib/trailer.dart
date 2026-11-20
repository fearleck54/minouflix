import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import 'journal.dart';

/// bande-annonce lue dans le lecteur de l'appli : adresse du flux YouTube (image, et son à part si besoin)
class Trailer {
  /// (image, son) ; son nul quand le flux contient déjà les deux. Nul si YouTube ne donne rien (l'appelant ouvre alors la page web).
  static Future<(String, String?)?> resolve(String id) async {
    final yt = YoutubeExplode();
    try {
      final m = await yt.videos.streamsClient.getManifest(id).timeout(const Duration(seconds: 25));
      // image H.264 jusqu'en 1080p + son AAC : bien plus net que le flux « tout en un » (360p)
      final v = m.videoOnly.where((s) => s.container == StreamContainer.mp4 && s.videoResolution.height <= 1080).toList()
        ..sort((a, b) => a.videoResolution.height.compareTo(b.videoResolution.height));
      final a = m.audioOnly.where((s) => s.container == StreamContainer.mp4).toList();
      if (v.isNotEmpty && a.isNotEmpty) return (v.last.url.toString(), a.withHighestBitrate().url.toString());
      if (m.muxed.isNotEmpty) return (m.muxed.withHighestBitrate().url.toString(), null);
    } catch (e) {
      Journal.add('Bande-annonce : flux YouTube non obtenu', e);
    } finally {
      yt.close();
    }
    return null;
  }
}
