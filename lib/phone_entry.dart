import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart' hide Text;
import 'package:qr_flutter/qr_flutter.dart';
import 'ui.dart';

/// saisie depuis le téléphone : petit formulaire servi sur le réseau local, protégé par un code ; l'écran affiche un QR code à scanner
class PhoneEntry {
  final List<(String, String, bool)> fields;      // (nom, libellé, secret)
  final void Function(Map<String, String>) onData;
  PhoneEntry(this.fields, this.onData);

  HttpServer? _srv;
  String? url;
  final pin = '${100000 + Random.secure().nextInt(900000)}';
  int _fails = 0;
  static String _esc(String s) => s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;');

  Future<void> start(VoidCallback changed) async {
    if (kIsWeb) return;
    try {
      final ip = (await NetworkInterface.list(type: InternetAddressType.IPv4)).expand((n) => n.addresses).map((a) => a.address).firstWhere((a) => a.startsWith('192.168.') || a.startsWith('10.') || a.startsWith('172.'), orElse: () => '');
      if (ip.isEmpty) return;
      final srv = await HttpServer.bind(InternetAddress.anyIPv4, 8080, shared: true);
      _srv = srv;
      url = 'http://$ip:8080';
      changed();
      srv.listen((r) async {
        r.response.headers.contentType = ContentType.html;
        if (r.method == 'POST') {
          final f = r.contentLength > 4096 ? <String, String>{} : Uri.splitQueryString(await utf8.decoder.bind(r).join());
          if (_fails >= 5 || f['pin'] != pin) {
            if (f['pin'] != pin) _fails++;
            r.response.write(_page(_fails >= 5 ? 'Trop d\'essais : relance l\'écran sur la télé.' : 'Code incorrect.', ''));
          } else {
            onData(f);
            r.response.write(_page('Envoyé ✓ — regarde la télé.', ''));
          }
        } else {
          r.response.write(_page('', _esc(r.uri.queryParameters['p'] ?? '')));
        }
        await r.response.close();
      });
    } catch (_) {}
  }

  void stop() => _srv?.close(force: true);

  static const _st = 'display:block;width:100%;box-sizing:border-box;padding:14px;margin:10px 0;border-radius:12px;border:1px solid #444;background:#1a1c22;color:#fff;font-size:17px';

  String _page(String msg, String p) => '<!doctype html><meta name=viewport content="width=device-width,initial-scale=1"><body style="font:17px -apple-system,sans-serif;background:#0b0c10;color:#fff;padding:24px;max-width:420px;margin:auto"><h2>MinouFlix</h2><p style="color:#9fb">$msg</p><form method=post>'
      '<input name=pin value="$p" placeholder="Code affiché sur la télé" inputmode=numeric style="$_st">'
      '${fields.map((f) => '<input name=${f.$1} type=${f.$3 ? 'password' : 'text'} placeholder="${f.$2}" autocapitalize=off autocomplete=off style="$_st">').join()}'
      '<button style="$_st;background:#fff;color:#000;font-weight:700">Envoyer</button></form>';

  /// carte à poser dans l'écran : QR code + adresse + code
  Widget card({double qr = 110}) {
    final u = url;
    if (u == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: const Color(0x1AFFFFFF), borderRadius: BorderRadius.circular(16)),
      child: Row(children: [
        Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)), child: QrImageView(data: '$u/?p=$pin', size: qr, padding: EdgeInsets.zero, backgroundColor: Colors.white)),
        const SizedBox(width: 14),
        Expanded(child: Text('Plus simple : scanne ce code avec ton téléphone (même Wi-Fi)\nou ouvre $u\net saisis $pin', style: T(14, w: 600))),
      ]),
    );
  }
}
