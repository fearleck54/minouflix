import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'l10n.dart';
import 'ui.dart';

/// bouton micro de la recherche : dicte le titre, l'acteur… (reconnaissance du système, rien n'est enregistré par l'appli)
class VoiceButton extends StatefulWidget {
  final ValueChanged<String> onResult;
  const VoiceButton({super.key, required this.onResult});
  @override
  State<VoiceButton> createState() => _VoiceButtonState();
}

class _VoiceButtonState extends State<VoiceButton> {
  final _stt = SpeechToText();
  bool _ok = false, _on = false;

  Future<void> _toggle() async {
    if (_on) {
      await _stt.stop();
      if (mounted) setState(() => _on = false);
      return;
    }
    try {
      if (!_ok) _ok = await _stt.initialize(onStatus: (s) {
        if ((s == 'done' || s == 'notListening') && mounted) setState(() => _on = false);
      }, onError: (_) {
        if (mounted) setState(() => _on = false);
      });
      if (!_ok) throw 'indisponible';
      setState(() => _on = true);
      await _stt.listen(
        localeId: L.tmdb.replaceAll('-', '_'),
        listenFor: const Duration(seconds: 10),
        pauseFor: const Duration(seconds: 2),
        onResult: (r) {
          if (r.recognizedWords.isEmpty) return;
          widget.onResult(r.recognizedWords);
        },
      );
    } catch (_) {
      if (mounted) {
        setState(() => _on = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(L.tr('Recherche vocale indisponible sur cet appareil.'))));
      }
    }
  }

  @override
  void dispose() {
    _stt.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) return const SizedBox.shrink();
    return FocusCard(
      radius: 99,
      onTap: _toggle,
      child: Padding(padding: const EdgeInsets.all(10), child: Icon(_on ? Icons.mic_rounded : Icons.mic_none_rounded, size: 24, color: _on ? Colors.redAccent : kMut)),
    );
  }
}
