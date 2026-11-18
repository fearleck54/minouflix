import 'package:flutter_test/flutter_test.dart';
import 'package:minouflix/journal.dart';

/// journal : jamais d'identifiants (les flux Xtream les portent dans l'adresse)
void main() {
  test('adresse réduite au serveur', () {
    expect(scrub('Failed to open http://user:pw@host.com:8080/live/u/p/1.m3u8.'), 'Failed to open http://host.com:8080/…');
    expect(scrub('https://exemple.org/movie/u/p/12.mkv'), 'https://exemple.org/…');
  });
  test('paramètres sensibles masqués', () {
    expect(scrub('player_api.php?username=abc&password=def&action=x'), 'player_api.php?username=…&password=…&action=x');
  });
  test('e-mail masqué', () {
    expect(scrub('compte romain@example.fr'), 'compte e-mail…');
  });
}
