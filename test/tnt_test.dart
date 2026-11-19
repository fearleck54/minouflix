import 'package:flutter_test/flutter_test.dart';
import 'package:minouflix/names.dart';

void main() {
  test('tntSort : noms du fournisseur reconnus (HDR, CH2, C8…)', () {
    Chan c(String n) => Chan(n, n, '', 'tnt', '', const []);
    final l = tntSort([c('M6 FHD'), c('C8'), c('FRANCE CH2 HDR'), c('TF1 HD'), c('FRANCE 3'), c('CANAL+'), c('FRANCE 5'), c('ARTE')]);
    expect([for (final x in l) x.name], ['TF1 HD', 'FRANCE CH2 HDR', 'FRANCE 3', 'CANAL+', 'FRANCE 5', 'M6 FHD', 'ARTE', 'C8']);
  });
}
