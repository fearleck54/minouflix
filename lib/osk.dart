import 'package:flutter/material.dart' hide Text;
import 'package:flutter/material.dart' as mat show Text;
import 'package:flutter/services.dart';
import 'perf.dart';
import 'l10n.dart';
import 'ui.dart';

/// champ de saisie : clavier du système sur téléphone et tablette ; sur télé, notre clavier à l'écran
/// (AZERTY en français, QWERTY en anglais) au lieu de celui, souvent pénible, de la télé
class AppField extends StatefulWidget {
  final TextEditingController controller;
  final InputDecoration decoration;
  final bool obscureText, autocorrect, autofocus;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final ValueChanged<String>? onSubmitted, onChanged;
  final TextStyle? style;
  final int? maxLength;
  final List<TextInputFormatter>? inputFormatters;
  final Iterable<String>? autofillHints;
  const AppField({
    super.key,
    required this.controller,
    this.decoration = const InputDecoration(),
    this.obscureText = false,
    this.autocorrect = true,
    this.autofocus = false,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.onSubmitted,
    this.onChanged,
    this.style,
    this.maxLength,
    this.inputFormatters,
    this.autofillHints,
  });
  @override
  State<AppField> createState() => _AppFieldState();
}

class _AppFieldState extends State<AppField> {
  @override
  void initState() {
    super.initState();
    if (Device.tv && widget.autofocus) WidgetsBinding.instance.addPostFrameCallback((_) => _open());
  }

  Future<void> _open() async {
    if (!mounted) return;
    final label = widget.decoration.labelText ?? widget.decoration.hintText ?? '';
    final r = await showDialog<String>(
      context: context,
      builder: (_) => TvKeyboard(initial: widget.controller.text, title: label, obscure: widget.obscureText, numeric: widget.keyboardType == TextInputType.number, max: widget.maxLength),
    );
    if (r == null || !mounted) return;
    widget.controller.text = r;
    widget.onChanged?.call(r);
    widget.onSubmitted?.call(r);
  }

  @override
  Widget build(BuildContext context) {
    if (!Device.tv) {
      return TextField(
        controller: widget.controller,
        decoration: widget.decoration,
        obscureText: widget.obscureText,
        autocorrect: widget.autocorrect,
        autofocus: widget.autofocus,
        keyboardType: widget.keyboardType,
        textCapitalization: widget.textCapitalization,
        onSubmitted: widget.onSubmitted,
        onChanged: widget.onChanged,
        style: widget.style,
        maxLength: widget.maxLength,
        inputFormatters: widget.inputFormatters,
        autofillHints: widget.autofillHints,
      );
    }
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (_, __) {
        final t = widget.controller.text;
        final shown = widget.obscureText ? '•' * t.length : t;
        final d = widget.decoration.copyWith(
          labelText: widget.decoration.labelText == null ? null : L.tr(widget.decoration.labelText!),
          hintText: widget.decoration.hintText == null ? null : L.tr(widget.decoration.hintText!),
        );
        return FocusCard(
          radius: 12,
          onTap: _open,
          child: d.isCollapsed == true
              ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                  decoration: BoxDecoration(color: kGlass, borderRadius: BorderRadius.circular(12)),
                  child: Row(children: [
                    if (d.prefixIcon != null) ...[d.prefixIcon!, const SizedBox(width: 10)],
                    Expanded(child: mat.Text(t.isEmpty ? (d.hintText ?? '') : shown, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.isEmpty ? (d.hintStyle ?? T(17, w: 400, color: kMut)) : (widget.style ?? T(17, w: 500)))),
                  ]),
                )
              : InputDecorator(decoration: d, isEmpty: t.isEmpty, child: mat.Text(shown, maxLines: 1, overflow: TextOverflow.ellipsis, style: widget.style ?? T(17, w: 500))),
        );
      },
    );
  }
}

/// clavier de salon : touches larges, navigation à la télécommande
class TvKeyboard extends StatefulWidget {
  final String initial, title;
  final bool obscure, numeric;
  final int? max;
  const TvKeyboard({super.key, this.initial = '', this.title = '', this.obscure = false, this.numeric = false, this.max});
  @override
  State<TvKeyboard> createState() => _TvKeyboardState();
}

class _TvKeyboardState extends State<TvKeyboard> {
  late String t = widget.initial;
  bool shift = false;

  static const _digits = '1234567890';
  static const _azerty = ['azertyuiop', 'qsdfghjklm', 'wxcvbn'];
  static const _qwerty = ['qwertyuiop', 'asdfghjkl', 'zxcvbnm'];
  static const _sym = ".,@-_/:?=&'!";

  void _add(String c) {
    if (widget.max != null && t.length >= widget.max!) return;
    setState(() {
      t += shift ? c.toUpperCase() : c;
      if (shift) shift = false;
    });
  }

  void _del() {
    if (t.isNotEmpty) setState(() => t = t.characters.skipLast(1).toString());
  }

  Widget _key(String label, VoidCallback onTap, {int flex = 1, bool autofocus = false, Color? fill, IconData? icon}) => Expanded(
        flex: flex,
        child: Padding(
          padding: const EdgeInsets.all(2.5),
          child: FocusCard(
            radius: 10,
            autofocus: autofocus,
            onTap: onTap,
            child: Container(
              height: 44,
              alignment: Alignment.center,
              color: fill ?? const Color(0x1FFFFFFF),
              child: icon != null ? Icon(icon, size: 22, color: Colors.white) : mat.Text(label, style: T(19, w: 600)),
            ),
          ),
        ),
      );

  Widget _row(String keys, {int pad = 0, bool first = false}) => Row(children: [
        if (pad > 0) Spacer(flex: pad),
        for (final (i, c) in keys.split('').indexed) _key(shift ? c.toUpperCase() : c, () => _add(c), flex: 2, autofocus: first && i == 0),
        if (pad > 0) Spacer(flex: pad),
      ]);

  /// pavé numérique comme sur un téléphone : 1-2-3 / 4-5-6 / 7-8-9 / effacer-0-OK
  Widget _pad() {
    Widget k(String label, VoidCallback onTap, {bool focus = false, Color? fill, IconData? icon}) => Expanded(
          child: Padding(
            padding: const EdgeInsets.all(5),
            child: FocusCard(
              radius: 18,
              autofocus: focus,
              onTap: onTap,
              child: Container(height: 62, alignment: Alignment.center, color: fill ?? const Color(0x1FFFFFFF), child: icon != null ? Icon(icon, size: 26, color: Colors.white) : mat.Text(label, style: T(28, w: 600))),
            ),
          ),
        );
    Widget row(List<String> ds) => Row(children: [for (final d in ds) k(d, () => _add(d), focus: d == '1')]);
    return Dialog(
      backgroundColor: kBg2,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 340),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (widget.title.isNotEmpty) Text(widget.title, textAlign: TextAlign.center, style: T(15, w: 600, color: kMut)),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(color: const Color(0x1AFFFFFF), borderRadius: BorderRadius.circular(14)),
              child: mat.Text(widget.obscure ? '•' * t.length : t, textAlign: TextAlign.center, maxLines: 1, style: T(26, w: 600, ls: 0.2)),
            ),
            const SizedBox(height: 8),
            row(['1', '2', '3']),
            row(['4', '5', '6']),
            row(['7', '8', '9']),
            Row(children: [
              k('', _del, icon: Icons.backspace_outlined),
              k('0', () => _add('0')),
              k('OK', () => Navigator.pop(context, t), fill: const Color(0xFF3B6FE0)),
            ]),
            TextButton(onPressed: () => Navigator.pop(context), child: mat.Text(L.en ? 'Cancel' : 'Annuler', style: T(15, w: 600, color: kMut))),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.numeric) return _pad();
    final rows = L.azerty ? _azerty : _qwerty;
    final shown = widget.obscure ? '•' * t.length : t;
    return Dialog(
      backgroundColor: kBg2,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (widget.title.isNotEmpty) Align(alignment: Alignment.centerLeft, child: Text(widget.title, style: T(14, w: 600, color: kMut))),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(color: const Color(0x1AFFFFFF), borderRadius: BorderRadius.circular(12)),
              child: mat.Text('$shown▏', maxLines: 1, overflow: TextOverflow.ellipsis, style: T(21, w: 500)),
            ),
            const SizedBox(height: 8),
            _row(_digits),
            ...[
              _row(rows[0], first: true),
              _row(rows[1], pad: 10 - rows[1].length),
              _row(rows[2], pad: 10 - rows[2].length),
              _row(_sym, pad: 0),
            ],
            Row(children: [
              _key('', () => setState(() => shift = !shift), flex: 3, icon: shift ? CupertinoIconsFallback.shiftOn : CupertinoIconsFallback.shiftOff, fill: shift ? const Color(0x59FFFFFF) : null),
              _key(L.en ? 'space' : 'espace', () => _add(' '), flex: 8),
              _key('', _del, flex: 3, icon: Icons.backspace_outlined),
              _key(L.en ? 'Cancel' : 'Annuler', () => Navigator.pop(context), flex: 4),
              _key('OK', () => Navigator.pop(context, t), flex: 4, fill: const Color(0xFF3B6FE0)),
            ]),
          ]),
        ),
      ),
    );
  }
}

class CupertinoIconsFallback {
  static const shiftOff = Icons.arrow_upward_rounded;
  static const shiftOn = Icons.keyboard_capslock_rounded;
}
