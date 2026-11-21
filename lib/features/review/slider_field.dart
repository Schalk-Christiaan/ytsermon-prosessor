// @stelsel slider_field
//   soort: module
//   wanneer: Hersien-skerm (eienskappe-paneel en vervoerbalk)
//   groep: features | Skerms
//   skryf: —
//   doel: 'n slider met 'n syferveld langsaan: sleep werk die veld by, tik (23:04) werk die slider by; 'n ongeldige invoer wys 'n fout by die veld en verander niks
//   status: bou
import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

/// A slider and its number field. [id] gives the keys `ctl.hersien.<id>` and `ctl.hersien.<id>-field`.
class SliderField extends StatefulWidget {
  const SliderField({
    super.key,
    required this.id,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.format,
    required this.parse,
    required this.onChanged,
    this.onCommit,
    this.fieldWidth = 76,
    this.showLabel = true,
  });

  final String id, label;
  final double value, min, max, fieldWidth;

  /// False when the label is clear from the neighbours (the zoom in the transport bar); it stays for screen readers.
  final bool showLabel;
  final String Function(double) format;
  final double? Function(String) parse;

  /// Called on every drag tick and when a typed value is accepted.
  final ValueChanged<double> onChanged;

  /// Called when the drag ends or a typed value was accepted (the point to save); none = nothing to save.
  final VoidCallback? onCommit;

  @override
  State<SliderField> createState() => _SliderFieldState();
}

class _SliderFieldState extends State<SliderField> {
  late final _text = TextEditingController(text: widget.format(widget.value));
  final _node = FocusNode();
  bool _bad = false;

  @override
  void initState() {
    super.initState();
    _node.addListener(() {
      if (!_node.hasFocus) _submit(_text.text);
    });
  }

  @override
  void didUpdateWidget(SliderField old) {
    super.didUpdateWidget(old);
    if (!_node.hasFocus && old.value != widget.value) {
      _text.text = widget.format(widget.value);
      _bad = false;
    }
  }

  @override
  void dispose() {
    _text.dispose();
    _node.dispose();
    super.dispose();
  }

  void _submit(String s) {
    final v = widget.parse(s);
    if (v == null) {
      setState(() => _bad = true);
      return;
    }
    setState(() => _bad = false);
    final c = v.clamp(widget.min, widget.max).toDouble();
    if (c != widget.value) {
      widget.onChanged(c);
      widget.onCommit?.call();
    }
    _text.text = widget.format(c);
  }

  @override
  Widget build(BuildContext context) {
    final th = Theme.of(context);
    final l = L.of(context);
    final v = widget.value.clamp(widget.min, widget.max).toDouble();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.showLabel)
          Text(widget.label, style: th.textTheme.labelLarge),
        Row(
          children: [
            Expanded(
              child: Slider(
                key: ValueKey('ctl.hersien.${widget.id}'),
                semanticFormatterCallback: (_) =>
                    '${widget.label} ${widget.format(widget.value)}',
                min: widget.min,
                max: widget.max > widget.min ? widget.max : widget.min + 1,
                value: v,
                onChanged: widget.onChanged,
                onChangeEnd: (_) => widget.onCommit?.call(),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: widget.fieldWidth,
              child: Semantics(
                label: widget.label,
                textField: true,
                child: TextField(
                  key: ValueKey('ctl.hersien.${widget.id}-field'),
                  controller: _text,
                  focusNode: _node,
                  textAlign: TextAlign.center,
                  style: th.textTheme.bodyMedium?.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    border: const OutlineInputBorder(),
                    errorText: _bad ? '' : null,
                    errorStyle: const TextStyle(height: 0, fontSize: 0),
                  ),
                  onSubmitted: _submit,
                ),
              ),
            ),
          ],
        ),
        if (_bad)
          Text(
            l.timeFieldError,
            style: th.textTheme.labelMedium?.copyWith(
              color: th.colorScheme.error,
            ),
          ),
      ],
    );
  }
}
