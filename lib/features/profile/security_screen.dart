import 'package:flutter/material.dart';

import '../../app/routes.dart';
import '../../core/session/session_manager.dart';
import '../../core/utils/ui_helpers.dart';
import '../../core/widgets/shared_widgets.dart';
import '../../models/user_activity.dart';
import '../../repositories/user_repository.dart';
import '../auth/widgets/totp_code_field.dart';
import '../users/user_report_actions.dart';
import 'activity_list.dart';
import 'two_factor_setup_screen.dart';

/// "Sécurité du compte": recovery key status, lockout rules, activity log.
class SecurityScreen extends StatefulWidget {
  const SecurityScreen({super.key});

  @override
  State<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends State<SecurityScreen> {
  final _repo = UserRepository();
  late Future<List<UserActivity>> _activity = _loadActivity();

  Future<List<UserActivity>> _loadActivity() =>
      _repo.getActivity(SessionManager.instance.currentUser!.id!);

  Future<void> _regenerate() async {
    final ok = await confirmDialog(
      context,
      title: 'Nouvelle clé de récupération',
      message: 'Votre ancienne clé cessera de fonctionner. Continuer ?',
      confirmLabel: 'Générer',
    );
    if (ok != true || !mounted) return;
    final done = await Navigator.pushNamed(context, Routes.recoveryKey);
    if (!mounted) return;
    setState(() => _activity = _loadActivity());
    if (done == true) showSnack(context, 'Clé de récupération mise à jour.');
  }

  Future<void> _enableTwoFactor() async {
    final done = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const TwoFactorSetupScreen()),
    );
    if (!mounted) return;
    setState(() => _activity = _loadActivity());
    if (done == true) showSnack(context, 'Double authentification activée.');
  }

  Future<void> _disableTwoFactor() async {
    final code = await showTotpCodeDialog(
      context,
      title: 'Désactiver la 2FA',
      message: "Entrez un code de votre application d'authentification "
          'pour confirmer.',
    );
    if (code == null || !mounted) return;
    final user = SessionManager.instance.currentUser!;
    if (!await _repo.checkTotpCode(user.id!, code)) {
      if (mounted) showSnack(context, 'Code incorrect.');
      return;
    }
    await _repo.disableTotp(user.id!);
    await SessionManager.instance.refresh();
    if (!mounted) return;
    setState(() => _activity = _loadActivity());
    showSnack(context, 'Double authentification désactivée.');
  }

  @override
  Widget build(BuildContext context) {
    final user = SessionManager.instance.currentUser!;
    final hasKey = user.recoveryKeyHash != null;
    return Scaffold(
      appBar: AppBar(title: const Text('Sécurité du compte')),
      body: ResponsiveCenter(
        maxWidth: 850,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              SectionCard(
                title: 'Clé de récupération',
                children: [
                  LabeledRow(
                    label: 'Statut',
                    value: hasKey ? 'Active' : 'Non définie',
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Permet de réinitialiser votre mot de passe sans internet. '
                    'En cas de perte, un collègue peut aussi le réinitialiser '
                    'depuis la liste des utilisateurs.',
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _regenerate,
                    icon: const Icon(Icons.key),
                    label: Text(hasKey
                        ? 'Générer une nouvelle clé'
                        : 'Générer ma clé'),
                  ),
                ],
              ),
              SectionCard(
                title: 'Double authentification (2FA)',
                children: [
                  LabeledRow(
                    label: 'Statut',
                    value: user.totpEnabled ? 'Activée' : 'Désactivée',
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'À la connexion, un code à 6 chiffres généré par une '
                    "application d'authentification (sur votre téléphone) "
                    'est demandé en plus du mot de passe. Fonctionne sans '
                    'internet.',
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed:
                        user.totpEnabled ? _disableTwoFactor : _enableTwoFactor,
                    icon: Icon(user.totpEnabled
                        ? Icons.lock_open
                        : Icons.phonelink_lock),
                    label: Text(user.totpEnabled
                        ? 'Désactiver la 2FA'
                        : 'Activer la 2FA'),
                  ),
                ],
              ),
              SectionCard(
                title: 'Protection contre les tentatives',
                children: [
                  Text(
                    'Après ${UserRepository.maxAttempts} échecs de connexion '
                    "consécutifs (mot de passe, clé ou code 2FA), le compte est "
                    "verrouillé 1 minute, puis la durée double à chaque nouvel "
                    "échec (maximum 15 minutes).",
                  ),
                ],
              ),
              SectionCard(
                title: "Journal d'activité",
                children: [
                  ActivityList(future: _activity),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () async {
                      await exportUserReport(context, user);
                      if (mounted) setState(() => _activity = _loadActivity());
                    },
                    icon: const Icon(Icons.picture_as_pdf),
                    label: const Text('Exporter mon rapport (PDF)'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
