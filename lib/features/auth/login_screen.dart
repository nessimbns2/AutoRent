import 'package:flutter/material.dart';

import '../../app/routes.dart';
import '../../app/theme.dart';
import '../../core/session/session_manager.dart';
import '../../core/utils/ui_helpers.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/shared_widgets.dart';
import '../../repositories/user_repository.dart';
import 'widgets/auth_layout.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _repo = UserRepository();
  bool _obscure = true;
  bool _loading = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final user =
          await _repo.authenticate(_emailCtrl.text.trim(), _passCtrl.text);
      if (!mounted) return;
      if (user == null) {
        showSnack(context, 'Email ou mot de passe incorrect.');
      } else {
        await SessionManager.instance.login(user);
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, Routes.home);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Fills the form with the seeded demo account (see DatabaseHelper._seed).
  void _useDemo() {
    _emailCtrl.text = 'agent@autorent.tn';
    _passCtrl.text = 'Agent123!';
    showSnack(context, 'Compte de démonstration pré-rempli');
  }

  Future<void> _openRegister() async {
    final email = await Navigator.pushNamed(context, Routes.register);
    if (email is String && mounted) {
      _emailCtrl.text = email;
      showSnack(context, 'Compte créé. Connectez-vous.');
    }
  }

  Future<void> _openForgotPassword() async {
    final email = await Navigator.pushNamed(context, Routes.forgotPassword);
    if (email is String && mounted) _emailCtrl.text = email;
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      title: 'Bon retour !',
      subtitle: 'Connectez-vous pour gérer votre agence.',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
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
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.password],
              onFieldSubmitted: (_) => _login(),
              decoration: InputDecoration(
                labelText: 'Mot de passe',
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(
                  icon: Icon(_obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              validator: Validators.password,
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _openForgotPassword,
                child: const Text('Mot de passe oublié ?'),
              ),
            ),
            const SizedBox(height: 6),
            PrimaryButton(
              label: 'Se connecter',
              icon: Icons.login_rounded,
              loading: _loading,
              onPressed: _login,
            ),
            const SizedBox(height: 18),
            Row(children: [
              Expanded(child: Divider(color: context.palette.border)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text('ou', style: context.text.bodySmall),
              ),
              Expanded(child: Divider(color: context.palette.border)),
            ]),
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: _useDemo,
              icon: const Icon(Icons.bolt_rounded, color: AppColors.brand),
              label: const Text('Utiliser le compte démo'),
            ),
            const SizedBox(height: 22),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Pas encore de compte ?', style: context.text.bodyMedium),
                TextButton(
                  onPressed: _openRegister,
                  child: const Text('Créer un compte'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
