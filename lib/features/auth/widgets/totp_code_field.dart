import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Big centered 6-digit input for authenticator codes.
class TotpCodeField extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback? onSubmitted;
  final bool autofocus;

  const TotpCodeField({
    super.key,
    required this.controller,
    this.onSubmitted,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      autofocus: autofocus,
      keyboardType: TextInputType.number,
      textAlign: TextAlign.center,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(6),
      ],
      style: const TextStyle(
        fontFamily: 'monospace',
        fontSize: 28,
        fontWeight: FontWeight.bold,
        letterSpacing: 8,
      ),
      decoration: const InputDecoration(
        hintText: '000000',
        labelText: 'Code à 6 chiffres',
        counterText: '',
      ),
      onSubmitted: (_) => onSubmitted?.call(),
    );
  }
}

/// Asks for a 6-digit code in a dialog. Returns the code, or null if cancelled.
Future<String?> showTotpCodeDialog(
  BuildContext context, {
  required String title,
  required String message,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _TotpCodeDialog(title: title, message: message),
  );
}

class _TotpCodeDialog extends StatefulWidget {
  final String title;
  final String message;
  const _TotpCodeDialog({required this.title, required this.message});

  @override
  State<_TotpCodeDialog> createState() => _TotpCodeDialogState();
}

class _TotpCodeDialogState extends State<_TotpCodeDialog> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (_ctrl.text.length == 6) Navigator.pop(context, _ctrl.text);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.message),
          const SizedBox(height: 16),
          TotpCodeField(
              controller: _ctrl, autofocus: true, onSubmitted: _submit),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Valider')),
      ],
    );
  }
}
