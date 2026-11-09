import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/utils/app_exception.dart';
import '../../core/utils/ui_helpers.dart';
import '../../core/utils/password_policy.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/password_strength_meter.dart';
import '../../core/widgets/shared_widgets.dart';
import '../../models/user.dart';
import '../../repositories/user_repository.dart';
import 'widgets/auth_layout.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _lastNameCtrl = TextEditingController();
  final _firstNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _repo = UserRepository();
  bool _obscure = true;
  bool _saving = false;

  @override
  void dispose() {
    _lastNameCtrl.dispose();
    _firstNameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await _repo.insert(
        User(
          lastName: _lastNameCtrl.text.trim(),
          firstName: _firstNameCtrl.text.trim(),
          email: _emailCtrl.text.trim(),
          passwordHash: '',
          createdAt: DateTime.now(),
        ),
        _passCtrl.text,
      );
      if (!mounted) return;
      Navigator.pop(context, _emailCtrl.text.trim());
    } on AppException catch (e) {
      if (mounted) showSnack(context, e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      showBack: true,
      compactHeader: true,
      title: 'Créer un compte',
      subtitle: 'Rejoignez votre agence en quelques secondes.',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              Expanded(
                child: TextFormField(
                  controller: _firstNameCtrl,
                  textInputAction: TextInputAction.next,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Prénom'),
                  validator: (v) => Validators.required(v, 'Le prénom'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _lastNameCtrl,
                  textInputAction: TextInputAction.next,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Nom'),
                  validator: (v) => Validators.required(v, 'Le nom'),
                ),
              ),
            ]),
            const SizedBox(height: 14),
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
              controller: _passCtrl,
              obscureText: _obscure,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: 'Mot de passe',
                helperText: '8 caractères minimum, avec une lettre et un chiffre',
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
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _register(),
              decoration: const InputDecoration(
                labelText: 'Confirmer le mot de passe',
                prefixIcon: Icon(Icons.lock_reset_rounded),
              ),
              validator: Validators.confirm(() => _passCtrl.text),
            ),
            const SizedBox(height: 24),
            PrimaryButton(
              label: 'Créer mon compte',
              icon: Icons.person_add_alt_1_rounded,
              loading: _saving,
              onPressed: _register,
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                'Vos données restent enregistrées sur cet appareil\n(base SQLite, aucune connexion requise).',
                textAlign: TextAlign.center,
                style: context.text.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
