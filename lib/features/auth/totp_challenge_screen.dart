import 'package:flutter/material.dart';

import '../../app/routes.dart';
import '../../core/session/session_manager.dart';
import '../../core/utils/auth_messages.dart';
import '../../core/utils/ui_helpers.dart';
import '../../core/widgets/shared_widgets.dart';
import '../../models/user.dart';
import '../../repositories/user_repository.dart';
import 'widgets/totp_code_field.dart';

/// Second login step for accounts with 2FA. The session is only created once
/// the code is accepted; going back just returns to the login form.
class TotpChallengeScreen extends StatefulWidget {
  final User user;
  const TotpChallengeScreen({super.key, required this.user});

  @override
  State<TotpChallengeScreen> createState() => _TotpChallengeScreenState();
}

class _TotpChallengeScreenState extends State<TotpChallengeScreen> {
  final _ctrl = TextEditingController();
  final _repo = UserRepository();
  bool _busy = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (_ctrl.text.length != 6) {
      showSnack(context, 'Entrez le code à 6 chiffres.');
      return;
    }
    setState(() => _busy = true);
    try {
      final res = await _repo.completeTotpLogin(widget.user.id!, _ctrl.text);
      if (!mounted) return;
      switch (res.status) {
        case AuthStatus.success:
          await SessionManager.instance.login(res.user!);
          if (!mounted) return;
          Navigator.pushNamedAndRemoveUntil(
              context, Routes.home, (_) => false);
        case AuthStatus.locked:
          showSnack(context, lockMessage(res.lockedFor ?? Duration.zero));
        case AuthStatus.invalid:
        case AuthStatus.totpRequired:
          _ctrl.clear();
          final left = res.attemptsLeft;
          showSnack(
              context,
              left != null && left <= 2
                  ? 'Code incorrect. Il vous reste '
                      '$left tentative${left > 1 ? 's' : ''}.'
                  : 'Code incorrect.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Vérification en deux étapes')),
      body: ResponsiveCenter(
        maxWidth: 420,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(Icons.phonelink_lock, size: 56, color: scheme.primary),
              const SizedBox(height: 16),
              Text(
                'Bonjour ${widget.user.firstName}',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              const Text(
                "Ouvrez votre application d'authentification et entrez le "
                'code à 6 chiffres affiché pour AutoRent.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              TotpCodeField(
                  controller: _ctrl, autofocus: true, onSubmitted: _verify),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _busy ? null : _verify,
                child: _busy
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Vérifier'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Retour'),
              ),
              const SizedBox(height: 8),
              Text(
                'Téléphone perdu ? Utilisez « Mot de passe oublié » avec votre '
                'clé de récupération, ou demandez à un collègue.',
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
