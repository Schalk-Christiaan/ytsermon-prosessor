import 'package:flutter/material.dart';

import '../../core/channel.dart';
import '../../core/settings.dart';
import '../../l10n/app_localizations.dart';

/// "Jou YouTube-kanaal": a field that normalises what was typed, checks it with [validate] (one yt-dlp
/// call, on request) and only then keeps it in [settings]. [screen] names the control keys
/// (`ctl.<screen>.channel`, `.channel-check`); [onChanged] runs after a new channel was saved.
class ChannelField extends StatefulWidget {
  const ChannelField({
    super.key,
    required this.settings,
    required this.screen,
    this.validate = channelName,
    this.onChanged,
  });
  final AppSettings settings;
  final String screen;
  final Future<String> Function(String url) validate;
  final VoidCallback? onChanged;

  @override
  State<ChannelField> createState() => _ChannelFieldState();
}

class _ChannelFieldState extends State<ChannelField> {
  late final _text = TextEditingController(text: widget.settings.channelUrl);
  bool _busy = false;
  String? _found, _error;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _check(L l) async {
    final url = normalizeChannelUrl(_text.text);
    if (url == null) {
      setState(() {
        _found = null;
        _error = l.channelBadForm;
      });
      return;
    }
    setState(() {
      _busy = true;
      _found = _error = null;
    });
    try {
      final name = await widget.validate(url);
      if (!mounted) return;
      _text.text = url;
      _found = l.channelFound(name);
      if (url != widget.settings.channelUrl) {
        widget.settings
          ..channelUrl = url
          ..save();
        widget.onChanged?.call();
      }
    } on Object {
      if (!mounted) return;
      _error = l.channelNotFound;
    }
    setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final th = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                key: ValueKey('ctl.${widget.screen}.channel'),
                controller: _text,
                enabled: !_busy,
                decoration: InputDecoration(
                  labelText: l.channelLabel,
                  helperText: l.channelHelp,
                  border: const OutlineInputBorder(),
                ),
                onSubmitted: (_) => _check(l),
              ),
            ),
            const SizedBox(width: 12),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: OutlinedButton(
                key: ValueKey('ctl.${widget.screen}.channel-check'),
                onPressed: _busy ? null : () => _check(l),
                child: Text(l.channelCheck),
              ),
            ),
          ],
        ),
        if (_busy)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: LinearProgressIndicator(),
          ),
        if (_found != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: SelectableText(_found!, style: th.textTheme.titleSmall),
          ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: SelectableText(
              _error!,
              style: TextStyle(color: th.colorScheme.error),
            ),
          ),
      ],
    );
  }
}
