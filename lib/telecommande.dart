import 'dart:async';
import 'package:flutter/material.dart' hide Text;
import 'connect.dart';
import 'ui.dart';

/// le téléphone commande la télé du même compte : recherche au clavier du téléphone, pause, ±30 s, arrêt
class TelecommandeScreen extends StatefulWidget {
  const TelecommandeScreen({super.key});
  @override
  State<TelecommandeScreen> createState() => _TelecommandeState();
}

class _TelecommandeState extends State<TelecommandeScreen> {
  final _q = TextEditingController();
  Timer? _deb;
  String _msg = '';

  @override
  void dispose() {
    _deb?.cancel();
    _q.dispose();
    super.dispose();
  }

  Future<void> _send(Map<String, dynamic> c) async {
    final ok = await Connect.send(c);
    if (mounted) setState(() => _msg = ok ? '' : 'Envoi impossible : même compte sur la télé, MinouFlix ouvert.');
  }

  Widget _btn(IconData i, String label, String op) => Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5),
          child: FocusCard(
            radius: 18,
            onTap: () => _send({'a': 'ctl', 'op': op}),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 18),
              decoration: BoxDecoration(color: kGlass, borderRadius: BorderRadius.circular(18), border: Border.all(color: kEdge, width: 0.8)),
              child: Column(children: [Icon(i, size: 28), const SizedBox(height: 6), Text(label, style: T(13, w: 600, color: kMut))]),
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) => DsBg(child: Scaffold(backgroundColor: Colors.transparent, 
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: ListView(padding: const EdgeInsets.fromLTRB(20, 14, 20, 40), children: [
                Row(children: [
                  RoundButton(size: 44, onTap: () => Navigator.pop(context), child: const Ic('back', size: 20)),
                  const SizedBox(width: 14),
                  Text('Télécommande', style: T(26, w: 800, ls: -0.03)),
                ]),
                const SizedBox(height: 10),
                Text('Commande la télé connectée au même compte (MinouFlix doit y être ouvert).', style: T(14, color: kMut, h: 1.4)),
                const SizedBox(height: 22),
                Text('Chercher sur la télé', style: T(16, w: 700)),
                const SizedBox(height: 10),
                TextField(
                  controller: _q,
                  autofocus: true,
                  textInputAction: TextInputAction.search,
                  decoration: const InputDecoration(hintText: 'Tape ici, ça s\'écrit sur la télé', border: OutlineInputBorder(), prefixIcon: Icon(Icons.search_rounded)),
                  onChanged: (v) {
                    _deb?.cancel();
                    _deb = Timer(const Duration(milliseconds: 500), () => _send({'a': 'search', 'q': v}));
                  },
                ),
                const SizedBox(height: 28),
                Text('Lecture', style: T(16, w: 700)),
                const SizedBox(height: 10),
                Row(children: [_btn(Icons.replay_30_rounded, '−30 s', 'back'), _btn(Icons.play_arrow_rounded, 'Pause / lecture', 'toggle'), _btn(Icons.forward_30_rounded, '+30 s', 'fwd')]),
                const SizedBox(height: 10),
                Row(children: [_btn(Icons.stop_rounded, 'Arrêter', 'stop')]),
                if (_msg.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 16), child: Text(_msg, style: T(14, color: const Color(0xFFFF6B7A)))),
              ]),
            ),
          ),
        ),
      ));
}
