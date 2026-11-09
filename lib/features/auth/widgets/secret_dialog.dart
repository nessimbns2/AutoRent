import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Shows a secret (e.g. a new recovery key) that will not be shown again,
/// with a copy button. Not dismissible by tapping outside, so it cannot be
/// missed.
Future<void> showSecretDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String secret,
  String closeLabel = "C'est noté",
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _SecretDialog(
      title: title,
      message: message,
      secret: secret,
      closeLabel: closeLabel,
    ),
  );
}

class _SecretDialog extends StatefulWidget {
  final String title;
  final String message;
  final String secret;
  final String closeLabel;

  const _SecretDialog({
    required this.title,
    required this.message,
    required this.secret,
    required this.closeLabel,
  });

  @override
  State<_SecretDialog> createState() => _SecretDialogState();
}

class _SecretDialogState extends State<_SecretDialog> {
  bool _copied = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.secret));
    if (mounted) setState(() => _copied = true);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return PopScope(
      canPop: false,
      child: AlertDialog(
        title: Text(widget.title),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.message),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SelectableText(
                  widget.secret,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _copy,
                icon: const Icon(Icons.copy, size: 18),
                label: const Text('Copier'),
              ),
              if (_copied) ...[
                const SizedBox(height: 8),
                Text('Copié dans le presse-papiers.',
                    style: TextStyle(fontSize: 12, color: scheme.primary)),
              ],
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: Text(widget.closeLabel),
          ),
        ],
      ),
    );
  }
}
