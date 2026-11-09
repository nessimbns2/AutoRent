import 'package:flutter/material.dart';

import '../../app/theme.dart';

import '../../core/services/recovery_key.dart';
import '../../core/utils/auth_messages.dart';
import '../../core/utils/password_policy.dart';
import '../../core/utils/ui_helpers.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/password_strength_meter.dart';
import '../../core/widgets/shared_widgets.dart';
import '../../repositories/user_repository.dart';
import 'widgets/auth_layout.dart';
import 'widgets/secret_dialog.dart';

/// Offline password reset: email + recovery key + new password.
/// Pops with the email on success so the login screen can prefill it.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _keyCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _repo = UserRepository();
  bool _obscure = true;
  bool _busy = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _keyCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _reset() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final email = _emailCtrl.text.trim();
      final res = await _repo.resetWithRecoveryKey(
        email: email,
        recoveryKey: _keyCtrl.text,
        newPassword: _passCtrl.text,
      );
      if (!mounted) return;
      switch (res.status) {
        case AuthStatus.success:
          final newKey = res.newRecoveryKey!;
          await showSecretDialog(
            context,
            title: 'Mot de passe réinitialisé',
            message: 'Votre clé de récupération a été utilisée. Voici votre '
                'NOUVELLE clé : conservez-la, elle ne sera plus affichée.'
                '${res.totpDisabled ? '\n\nLa double authentification a été désactivée : réactivez-la depuis Profil > Sécurité du compte.' : ''}',
            secret: newKey,
          );
          if (!mounted) return;
          Navigator.pop(context, email);
        case AuthStatus.locked:
          showSnack(context, lockMessage(res.lockedFor ?? Duration.zero));
        case AuthStatus.invalid:
        case AuthStatus.totpRequired:
          final left = res.attemptsLeft;
          showSnack(
              context,
              left != null && left <= 2
                  ? 'Email ou clé de récupération incorrect. '
                      'Il vous reste $left tentative${left > 1 ? 's' : ''}.'
                  : 'Email ou clé de récupération incorrect.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      showBack: true,
      compactHeader: true,
      title: 'Mot de passe oublié',
      subtitle: 'Entrez votre email et la clé de récupération sauvegardée.',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const InfoBanner(
              icon: Icons.wifi_off_rounded,
              color: AppColors.info,
              text: 'Aucune connexion internet n\'est nécessaire.',
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.alternate_email_rounded),
              ),
              validator: Validators.email,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _keyCtrl,
              textCapitalization: TextCapitalization.characters,
              autocorrect: false,
              enableSuggestions: false,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Clé de récupération',
                hintText: 'XXXX-XXXX-XXXX-XXXX',
                prefixIcon: Icon(Icons.key_rounded),
              ),
              validator: (v) => RecoveryKey.looksValid(v ?? '')
                  ? null
                  : 'La clé comporte 16 caractères',
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _passCtrl,
              obscureText: _obscure,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: 'Nouveau mot de passe',
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(
                  icon: Icon(_obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              validator: PasswordPolicy.validate,
            ),
            PasswordStrengthMeter(controller: _passCtrl),
            const SizedBox(height: 14),
            TextFormField(
              controller: _confirmCtrl,
              obscureText: _obscure,
              decoration: const InputDecoration(
                labelText: 'Confirmer le mot de passe',
                prefixIcon: Icon(Icons.lock_outline_rounded),
              ),
              validator: Validators.confirm(() => _passCtrl.text),
            ),
            const SizedBox(height: 22),
            PrimaryButton(
              label: 'Réinitialiser',
              icon: Icons.lock_reset_rounded,
              loading: _busy,
              onPressed: _reset,
            ),
            const SizedBox(height: 16),
            Text(
              'Clé perdue ? Demandez à un collègue de réinitialiser votre '
              'mot de passe depuis la liste des utilisateurs.',
              textAlign: TextAlign.center,
              style: context.text.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
