import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/services/totp_service.dart';
import '../../core/session/session_manager.dart';
import '../../core/utils/app_exception.dart';
import '../../core/utils/ui_helpers.dart';
import '../../core/widgets/shared_widgets.dart';
import '../../repositories/user_repository.dart';
import '../auth/widgets/totp_code_field.dart';

/// Enables 2FA. The secret only exists in memory until the user proves their
/// authenticator app works by entering a valid code. Pops with true on success.
class TwoFactorSetupScreen extends StatefulWidget {
  const TwoFactorSetupScreen({super.key});

  @override
  State<TwoFactorSetupScreen> createState() => _TwoFactorSetupScreenState();
}

class _TwoFactorSetupScreenState extends State<TwoFactorSetupScreen> {
  final _repo = UserRepository();
  final String _secret = Totp.generateSecret();
  final _codeCtrl = TextEditingController();
  bool _busy = false;
  bool _copied = false;

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: _secret));
    if (mounted) setState(() => _copied = true);
  }

  Future<void> _activate() async {
    if (_codeCtrl.text.length != 6) {
      showSnack(context, 'Entrez le code à 6 chiffres.');
      return;
    }
    final session = SessionManager.instance;
    setState(() => _busy = true);
    try {
      await _repo.enableTotp(session.currentUser!.id!, _secret, _codeCtrl.text);
      await session.refresh();
      if (!mounted) return;
      Navigator.pop(context, true);
    } on AppException catch (e) {
      if (mounted) showSnack(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = SessionManager.instance.currentUser!;
    final scheme = Theme.of(context).colorScheme;
    final uri = Totp.otpauthUri(secret: _secret, account: user.email);
    return Scaffold(
      appBar: AppBar(title: const Text('Activer la double authentification')),
      body: ResponsiveCenter(
        maxWidth: 520,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '1. Installez une application d\'authentification (Google '
                'Authenticator, Microsoft Authenticator, Authy... ou une '
                'extension de navigateur sur PC).',
              ),
              const SizedBox(height: 16),
              const Text('2. Scannez ce QR code avec l\'application :'),
              const SizedBox(height: 12),
              Center(
                child: Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(12),
                  child: QrImageView(
                    data: uri,
                    size: 200,
                    backgroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Ou saisissez cette clé manuellement :'),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SelectableText(
                  Totp.formatSecret(_secret),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: _copy,
                  icon: const Icon(Icons.copy, size: 16),
                  label: Text(_copied ? 'Copié' : 'Copier la clé'),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                  '3. Entrez le code à 6 chiffres affiché pour confirmer :'),
              const SizedBox(height: 12),
              TotpCodeField(controller: _codeCtrl, onSubmitted: _activate),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _busy ? null : _activate,
                child: _busy
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Vérifier et activer'),
              ),
              const SizedBox(height: 12),
              Text(
                "Les codes dépendent de l'heure : l'heure de ce PC/téléphone "
                'doit être exacte (réglage automatique).',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
