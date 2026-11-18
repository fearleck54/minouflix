import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:minouflix/tmdb.dart';
import 'package:minouflix/xtream.dart';

void main() {
  test('playlist M3U : groupes, types, guide', () {
    const txt = '#EXTM3U url-tvg="http://exemple.fr/guide.xml"\n'
        '#EXTINF:-1 tvg-id="TF1.fr" tvg-logo="http://l/tf1.png" group-title="France",TF1 HD\n'
        'http://srv/live/u/p/1.m3u8\n'
        '#EXTINF:-1 group-title="Films",Le Film (2020)\n'
        'http://srv/movie/u/p/2.mp4\n'
        '#EXTINF:-1,Sans groupe\n'
        'http://srv/x/3.ts\n';
    final r = parseM3u(Uint8List.fromList(utf8.encode(txt)))!;
    expect(r.$2, 'http://exemple.fr/guide.xml');
    expect(r.$1[Kind.live.index]!['France']!.first.epg, 'tf1.fr');
    expect(r.$1[Kind.live.index]!['France']!.first.ext, 'http://srv/live/u/p/1.m3u8');
    expect(r.$1[Kind.vod.index]!['Films']!.length, 1);
    expect(r.$1[Kind.live.index]!['Sans groupe']!.length, 1);
    expect(parseM3u(Uint8List.fromList(utf8.encode('pas une playlist'))), isNull);
  });

  test('classification française', () {
    expect(certAge('U'), 0);
    expect(certAge('12'), 12);
    expect(certAge('-16'), 16);
    expect(certAge(''), -1);
  });

  test('adresse de rattrapage', () {
    final x = Xtream(const Creds('http://srv', 'u', 'p'));
    final u = x.timeshiftUrl(7, DateTime.utc(2026, 11, 14, 20, 5).millisecondsSinceEpoch ~/ 1000, DateTime.utc(2026, 11, 14, 21, 5).millisecondsSinceEpoch ~/ 1000);
    expect(u, 'http://srv/timeshift/u/p/90/2026-11-14:20-05/7.ts');
  });
}
