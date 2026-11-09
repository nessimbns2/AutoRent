import 'package:flutter/material.dart';

import '../../app/routes.dart';
import '../../core/session/session_manager.dart';
import '../../core/utils/auth_messages.dart';
import '../../core/utils/ui_helpers.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/shared_widgets.dart';
import '../../repositories/user_repository.dart';
import 'totp_challenge_screen.dart';

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
      final res = await _repo.signIn(_emailCtrl.text.trim(), _passCtrl.text);
      if (!mounted) return;
      switch (res.status) {
        case AuthStatus.success:
          await SessionManager.instance.login(res.user!);
          if (!mounted) return;
          // The router guard shows the forced password change / recovery key
          // screens first when needed.
          Navigator.pushReplacementNamed(context, Routes.home);
        case AuthStatus.totpRequired:
          await Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => TotpChallengeScreen(user: res.user!)),
          );
          if (mounted) _passCtrl.clear();
        case AuthStatus.locked:
          showSnack(context, lockMessage(res.lockedFor ?? Duration.zero));
        case AuthStatus.invalid:
          final left = res.attemptsLeft;
          showSnack(
              context,
              left != null && left <= 2
                  ? 'Email ou mot de passe incorrect. '
                      'Il vous reste $left tentative${left > 1 ? 's' : ''}.'
                  : 'Email ou mot de passe incorrect.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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
    if (email is String && mounted) {
      _emailCtrl.text = email;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ResponsiveCenter(
          maxWidth: 460,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 40),
                  Icon(Icons.directions_car,
                      size: 72,
                      color: Theme.of(context).colorScheme.primary),
                  const SizedBox(height: 12),
                  Text('AutoRent',
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .headlineMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('Gestion de location de voitures',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 40),
                  TextFormField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.email_outlined)),
                    validator: Validators.email,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passCtrl,
                    obscureText: _obscure,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _login(),
                    decoration: InputDecoration(
                      labelText: 'Mot de passe',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                            _obscure ? Icons.visibility : Icons.visibility_off),
                        onPressed: () =>
                            setState(() => _obscure = !_obscure),
                      ),
                    ),
                    validator: Validators.password,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _loading ? null : _login,
                    child: _loading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Se connecter'),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TextButton(
                        onPressed: _openRegister,
                        child: const Text('Créer un compte'),
                      ),
                      const Text('·'),
                      TextButton(
                        onPressed: _openForgotPassword,
                        child: const Text('Mot de passe oublié ?'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
