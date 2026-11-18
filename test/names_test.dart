import 'package:flutter_test/flutter_test.dart';
import 'package:minouflix/names.dart';
import 'package:minouflix/xtream.dart';

/// noms des fournisseurs : chaînes (qualité, secours) et titres (année, 4K, préfixe de langue)
void main() {
  group('splitChannel', () {
    test('préfixe de pays et qualité retirés', () {
      final r = splitChannel('FR| TF1 HD');
      expect(r.$1, 'TF1');
      expect(r.$2, 'tf1');
      expect(r.$3, 2);
      expect(r.$4, 'HD');
    });
    test('4K et le + de Canal+', () {
      final r = splitChannel('FR| CANAL+ 4K');
      expect(r.$1, 'CANAL+');
      expect(r.$2, 'canalplus');
      expect(r.$3, 4);
      expect(r.$4, '4K');
    });
    test('FHD', () {
      final r = splitChannel('|FR| FRANCE 2 FHD');
      expect(r.$1, 'FRANCE 2');
      expect(r.$4, 'FHD');
    });
    test('flux de secours (« B » final)', () {
      final r = splitChannel('TF1 B');
      expect(r.$1, 'TF1');
      expect(r.$4, 'HD · secours');
    });
  });

  group('parseTitle', () {
    test('préfixe de langue et année', () {
      final p = parseTitle('FR - Inception (2010)', Kind.vod);
      expect(p.title, 'Inception');
      expect(p.year, '2010');
      expect(p.q, '');
      expect(p.key, 'inception');
    });
    test('qualité 4K en tête', () {
      final p = parseTitle('4K - Dune (2021)', Kind.vod);
      expect(p.title, 'Dune');
      expect(p.year, '2021');
      expect(p.q, '4K');
    });
    test('année et étiquette de langue en fin', () {
      final p = parseTitle('Le Parrain - 1972 MULTI', Kind.vod);
      expect(p.title, 'Le Parrain');
      expect(p.year, '1972');
    });
  });

  group('dédoublonnage', () {
    test('même titre, même catégorie : la version avec affiche gagne', () {
      final l = dedupeItems([
        Item(1, 'Inception (2010)', '', 'mp4', 'c1', Kind.vod, added: 10),
        Item(2, 'FR - Inception (2010)', 'http://exemple.org/i.jpg', 'mkv', 'c1', Kind.vod, added: 5),
        Item(3, 'Dune (2021)', '', 'mp4', 'c1', Kind.vod, added: 20),
      ]);
      expect(l.length, 2);
      expect(l.first.id, 3);     // plus récent d'abord
      expect(l.last.id, 2);
    });
    test('un seul exemplaire par titre, toutes catégories', () {
      final l = uniqueTitles([
        Item(1, 'Inception (2010)', '', 'mp4', 'c1', Kind.vod),
        Item(2, 'Inception (2010)', '', 'mp4', 'c2', Kind.vod),
      ]);
      expect(l.length, 1);
    });
  });
}
