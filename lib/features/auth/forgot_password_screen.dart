import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/utils/ui_helpers.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/shared_widgets.dart';
import '../../repositories/user_repository.dart';
import 'widgets/auth_layout.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _repo = UserRepository();
  bool _saving = false;
  bool _obscure = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _reset() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final existing = await _repo.getByEmail(_emailCtrl.text.trim());
      if (!mounted) return;
      if (existing == null) {
        showSnack(context, 'Aucun compte avec cet email.');
        return;
      }
      await _repo.updatePassword(_emailCtrl.text.trim(), _passCtrl.text);
      if (!mounted) return;
      showSnack(context, 'Mot de passe réinitialisé.');
      Navigator.pop(context, _emailCtrl.text.trim());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      showBack: true,
      compactHeader: true,
      title: 'Mot de passe oublié',
      subtitle: 'Choisissez un nouveau mot de passe pour votre compte.',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const InfoBanner(
              icon: Icons.shield_outlined,
              color: AppColors.info,
              text:
                  'Application hors-ligne : la réinitialisation se fait directement sur cet appareil.',
            ),
            const SizedBox(height: 18),
            TextFormField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Email du compte',
                prefixIcon: Icon(Icons.alternate_email_rounded),
              ),
              validator: Validators.email,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _passCtrl,
              obscureText: _obscure,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: 'Nouveau mot de passe',
                prefixIcon: const Icon(Icons.key_rounded),
                suffixIcon: IconButton(
                  icon: Icon(_obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              validator: Validators.password,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _confirmCtrl,
              obscureText: _obscure,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _reset(),
              decoration: const InputDecoration(
                labelText: 'Confirmer le mot de passe',
                prefixIcon: Icon(Icons.lock_reset_rounded),
              ),
              validator: Validators.confirm(() => _passCtrl.text),
            ),
            const SizedBox(height: 24),
            PrimaryButton(
              label: 'Réinitialiser',
              icon: Icons.lock_reset_rounded,
              loading: _saving,
              onPressed: _reset,
            ),
          ],
        ),
      ),
    );
  }
}
