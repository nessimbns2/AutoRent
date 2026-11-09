import 'package:flutter/material.dart';

import '../../app/route_args.dart';
import '../../app/routes.dart';
import '../../core/services/image_storage.dart';
import '../../core/session/session_manager.dart';
import '../../core/utils/app_exception.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/password_policy.dart';
import '../../core/utils/ui_helpers.dart';
import '../../core/widgets/password_strength_meter.dart';
import '../../core/widgets/shared_widgets.dart';
import '../../models/user.dart';
import '../../models/user_activity.dart';
import '../profile/activity_list.dart';
import 'user_report_actions.dart';
import '../../repositories/user_repository.dart';

class UserDetailScreen extends StatefulWidget {
  final int userId;
  const UserDetailScreen({super.key, required this.userId});

  @override
  State<UserDetailScreen> createState() => _UserDetailScreenState();
}

class _UserDetailScreenState extends State<UserDetailScreen> {
  final _repo = UserRepository();
  late Future<User?> _future = _repo.getById(widget.userId);
  late Future<List<UserActivity>> _activity =
      _repo.getActivity(widget.userId, limit: 5);
  bool _didChange = false;

  void _reload() {
    setState(() {
      _future = _repo.getById(widget.userId);
      _activity = _repo.getActivity(widget.userId, limit: 5);
    });
  }

  Future<void> _edit(User user) async {
    final saved = await Navigator.pushNamed(
      context,
      Routes.userForm,
      arguments: UserFormArgs(userId: user.id),
    );
    if (saved == true && mounted) {
      _didChange = true;
      _reload();
    }
  }

  /// Colleague reset: another agent types a new password for this user
  /// (forgotten password and no recovery key). Works fully offline.
  Future<void> _resetPassword(User user) async {
    final actor = SessionManager.instance.currentUser;
    if (actor?.id == null) return;
    final passwordController = TextEditingController();
    final confirmController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text('Mot de passe de ${user.firstName}'),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: passwordController,
                  obscureText: true,
                  decoration:
                      const InputDecoration(labelText: 'Nouveau mot de passe'),
                  validator: PasswordPolicy.validate,
                ),
                PasswordStrengthMeter(controller: passwordController),
                const SizedBox(height: 12),
                TextFormField(
                  controller: confirmController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Confirmation'),
                  validator: (v) => v != passwordController.text
                      ? 'Les mots de passe ne correspondent pas'
                      : null,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(dialogCtx, true);
              }
            },
            child: const Text('Valider'),
          ),
        ],
      ),
    );

    final newPassword = passwordController.text;
    passwordController.dispose();
    confirmController.dispose();
    if (ok != true || !mounted) return;
    try {
      await _repo.resetByColleague(
          targetId: user.id!, actorId: actor!.id!, newPassword: newPassword);
      if (!mounted) return;
      setState(() => _activity = _repo.getActivity(widget.userId, limit: 5));
      showSnack(context, 'Mot de passe réinitialisé avec succès');
    } on AppException catch (e) {
      if (mounted) showSnack(context, e.message);
    }
  }

  /// A colleague switches off 2FA for a user who lost their phone.
  Future<void> _disableTwoFactor(User user) async {
    final actor = SessionManager.instance.currentUser;
    if (actor?.id == null) return;
    final ok = await confirmDialog(
      context,
      title: 'Désactiver la 2FA',
      message: 'Désactiver la double authentification de ${user.fullName} ? '
          'Il pourra la réactiver depuis son profil.',
      confirmLabel: 'Désactiver',
    );
    if (ok != true || !mounted) return;
    try {
      await _repo.disableTotpByColleague(
          targetId: user.id!, actorId: actor!.id!);
      if (!mounted) return;
      _didChange = true;
      _reload();
      showSnack(context, 'Double authentification désactivée.');
    } on AppException catch (e) {
      if (mounted) showSnack(context, e.message);
    }
  }

  Future<void> _delete(User user) async {
    final isCurrent = user.id == SessionManager.instance.currentUser?.id;
    final msg = isCurrent
        ? 'Attention : vous allez supprimer votre propre compte et être déconnecté.'
        : 'Voulez-vous vraiment supprimer cet utilisateur ?';

    final ok = await confirmDialog(
      context,
      title: 'Supprimer utilisateur',
      message: msg,
      confirmLabel: 'Supprimer',
    );
    if (ok != true || !mounted) return;

    try {
      await _repo.delete(user.id!);
      if (!mounted) return;
      if (isCurrent) {
        await SessionManager.instance.logout();
        if (!mounted) return;
        Navigator.pushNamedAndRemoveUntil(context, Routes.login, (_) => false);
      } else {
        showSnack(context, 'Utilisateur supprimé');
        Navigator.pop(context, true);
      }
    } on AppException catch (e) {
      if (mounted) showSnack(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {},
      child: FutureBuilder<User?>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Scaffold(body: LoadingView());
          }
          if (snap.hasError || snap.data == null) {
            return Scaffold(
              appBar: AppBar(title: const Text('Détail utilisateur')),
              body: ErrorView(
                error: snap.error ?? 'Utilisateur introuvable',
                onRetry: _reload,
              ),
            );
          }
          final user = snap.data!;
          final isCurrent = user.id == SessionManager.instance.currentUser?.id;

          return Scaffold(
            appBar: AppBar(
              title: Text(user.fullName),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context, _didChange),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () => _edit(user),
                  tooltip: 'Modifier',
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _delete(user),
                  tooltip: 'Supprimer',
                ),
              ],
            ),
            body: ResponsiveCenter(
              maxWidth: 850,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                children: [
                  Center(
                    child: CircleAvatar(
                      radius: 48,
                      backgroundColor:
                          Theme.of(context).colorScheme.primaryContainer,
                      backgroundImage: user.photoFile != null
                          ? FileImage(ImageStorage.fileFor(user.photoFile!))
                              as ImageProvider
                          : null,
                      child: user.photoFile == null
                          ? Text(
                              user.initials,
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onPrimaryContainer,
                              ),
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    user.fullName,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  Text(
                    user.email,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 24),
                  SectionCard(
                    title: 'Informations du compte',
                    children: [
                      LabeledRow(label: 'Nom', value: user.lastName),
                      LabeledRow(label: 'Prénom', value: user.firstName),
                      LabeledRow(label: 'Email', value: user.email),
                      LabeledRow(
                        label: 'Inscrit le',
                        value: formatDate(user.createdAt),
                      ),
                      LabeledRow(
                        label: '2FA',
                        value: user.totpEnabled ? 'Activée' : 'Désactivée',
                      ),
                      if (isCurrent)
                        const LabeledRow(
                          label: 'Statut',
                          value: 'Votre session actuelle',
                        ),
                    ],
                  ),
                  SectionCard(
                    title: 'Activité récente',
                    children: [ActivityList(future: _activity)],
                  ),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      icon: const Icon(Icons.picture_as_pdf),
                      label: const Text('Exporter le rapport (PDF)'),
                      onPressed: () async {
                        await exportUserReport(context, user);
                        if (mounted) {
                          setState(() => _activity =
                              _repo.getActivity(widget.userId, limit: 5));
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (!isCurrent)
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.lock_reset),
                        label: const Text('Réinitialiser le mot de passe'),
                        onPressed: () => _resetPassword(user),
                      ),
                    )
                  else
                    const Text(
                      'Pour votre propre mot de passe, utilisez « Mon profil ».',
                      textAlign: TextAlign.center,
                    ),
                  if (!isCurrent && user.totpEnabled) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.phonelink_erase),
                        label: const Text('Désactiver sa 2FA (téléphone perdu)'),
                        onPressed: () => _disableTwoFactor(user),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
      ),
    );
  }
}
