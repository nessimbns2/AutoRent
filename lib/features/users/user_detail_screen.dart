import 'package:flutter/material.dart';

import '../../app/route_args.dart';
import '../../app/routes.dart';
import '../../app/theme.dart';
import '../../core/session/session_manager.dart';
import '../../core/utils/app_exception.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/password_policy.dart';
import '../../core/utils/ui_helpers.dart';
import '../../core/widgets/password_strength_meter.dart';
import '../../core/widgets/shared_widgets.dart';
import '../../models/user.dart';
import '../../models/user_activity.dart';
import '../../repositories/user_repository.dart';
import '../profile/activity_list.dart';
import 'user_report_actions.dart';

class UserDetailScreen extends StatefulWidget {
  final int userId;
  const UserDetailScreen({super.key, required this.userId});

  @override
  State<UserDetailScreen> createState() => _UserDetailScreenState();
}

class _UserDetailScreenState extends State<UserDetailScreen> {
  final _repo = UserRepository();
  late Future<_Data> _future = _load();
  bool _didChange = false;

  Future<_Data> _load() async {
    final u = await _repo.getById(widget.userId);
    final a = u == null ? (0, 0.0, 0) : await _repo.activity(u.id!);
    return _Data(u, a);
  }

  late Future<List<UserActivity>> _activity =
      _repo.getActivity(widget.userId, limit: 5);

  void _reload() => setState(() {
        _future = _load();
        _activity = _repo.getActivity(widget.userId, limit: 5);
      });

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
        icon: const IconBadge(
            icon: Icons.lock_reset_rounded, color: AppColors.violet, size: 56),
        title: const Text('Nouveau mot de passe', textAlign: TextAlign.center),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Pour ${user.fullName}',
                    style: Theme.of(dialogCtx).textTheme.bodySmall),
                const SizedBox(height: 14),
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
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        actions: [
          Row(children: [
            Expanded(
              child: OutlinedButton(
                style:
                    OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
                onPressed: () => Navigator.pop(dialogCtx, false),
                child: const Text('Annuler'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
                onPressed: () {
                  if (formKey.currentState!.validate()) {
                    Navigator.pop(dialogCtx, true);
                  }
                },
                child: const Text('Valider'),
              ),
            ),
          ]),
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
    final ok = await confirmDialog(
      context,
      title: 'Supprimer ce compte ?',
      message: isCurrent
          ? 'Attention : vous allez supprimer votre propre compte et être déconnecté.'
          : 'Le compte de ${user.fullName} sera supprimé.',
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
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _didChange);
      },
      child: FutureBuilder<_Data>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Scaffold(body: LoadingView());
          }
          if (snap.hasError || snap.data?.user == null) {
            return Scaffold(
              appBar: AppBar(title: const Text('Utilisateur')),
              body: ErrorView(
                  error: snap.error ?? 'Utilisateur introuvable',
                  onRetry: _reload),
            );
          }
          final user = snap.data!.user!;
          final a = snap.data!.activity;
          final isCurrent = user.id == SessionManager.instance.currentUser?.id;

          return Scaffold(
            appBar: AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => Navigator.pop(context, _didChange),
              ),
              title: const Text('Utilisateur'),
              actions: [
                DetailMenu(items: [
                  DetailMenuItem(
                      'Modifier', Icons.edit_rounded, () => _edit(user)),
                  if (!isCurrent)
                    DetailMenuItem('Réinitialiser le mot de passe',
                        Icons.lock_reset_rounded, () => _resetPassword(user)),
                  if (!isCurrent && user.totpEnabled)
                    DetailMenuItem('Désactiver sa 2FA',
                        Icons.phonelink_erase_rounded,
                        () => _disableTwoFactor(user)),
                  DetailMenuItem(
                      'Exporter le rapport (PDF)',
                      Icons.picture_as_pdf_rounded,
                      () async {
                        await exportUserReport(context, user);
                        if (mounted) {
                          setState(() => _activity =
                              _repo.getActivity(widget.userId, limit: 5));
                        }
                      }),
                  DetailMenuItem('Supprimer', Icons.delete_outline_rounded,
                      () => _delete(user),
                      destructive: true),
                ]),
                const SizedBox(width: 8),
              ],
            ),
            body: ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              children: [
                AppCard(
                  padding: const EdgeInsets.all(20),
                  margin: const EdgeInsets.only(bottom: 14),
                  child: Column(children: [
                    AvatarCircle(
                        initials: user.initials,
                        photoFile: user.photoFile,
                        size: 84),
                    const SizedBox(height: 10),
                    Text(user.fullName, style: context.text.titleLarge),
                    Text(user.email, style: context.text.bodySmall),
                    if (isCurrent) ...[
                      const SizedBox(height: 8),
                      const StatusChip(
                          label: 'Session actuelle',
                          color: AppColors.success,
                          icon: Icons.circle),
                    ],
                    const SizedBox(height: 16),
                    Row(children: [
                      Expanded(
                        child: InfoTile(
                            icon: Icons.receipt_long_rounded,
                            label: 'Locations',
                            value: '${a.$1}',
                            color: AppColors.info),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: InfoTile(
                            icon: Icons.savings_rounded,
                            label: 'Générés',
                            value: formatMoneyShort(a.$2),
                            color: AppColors.success),
                      ),
                    ]),
                  ]),
                ),
                SectionCard(
                  title: 'Informations du compte',
                  icon: Icons.manage_accounts_rounded,
                  iconColor: AppColors.violet,
                  children: [
                    LabeledRow(
                        icon: Icons.person_outline_rounded,
                        label: 'Prénom',
                        value: user.firstName),
                    LabeledRow(
                        icon: Icons.badge_outlined,
                        label: 'Nom',
                        value: user.lastName),
                    LabeledRow(
                        icon: Icons.report_outlined,
                        label: 'Incidents déclarés',
                        value: '${a.$3}'),
                    LabeledRow(
                        icon: Icons.event_rounded,
                        label: 'Inscrit le',
                        value: formatDate(user.createdAt)),
                    LabeledRow(
                        icon: Icons.verified_user_outlined,
                        label: '2FA',
                        value: user.totpEnabled ? 'Activée' : 'Désactivée'),
                  ],
                ),
                const SizedBox(height: 14),
                SectionCard(
                  title: 'Activité récente',
                  icon: Icons.history_rounded,
                  iconColor: AppColors.info,
                  children: [ActivityList(future: _activity)],
                ),
              ],
            ),
            bottomNavigationBar: BottomActionBar(
              child: Row(children: [
                // Own password: use the profile screen (needs the old one).
                if (!isCurrent) ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 54)),
                      onPressed: () => _resetPassword(user),
                      icon: const Icon(Icons.lock_reset_rounded),
                      label: const Text('Mot de passe'),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: PrimaryButton(
                    label: 'Modifier',
                    icon: Icons.edit_rounded,
                    onPressed: () => _edit(user),
                  ),
                ),
              ]),
            ),
          );
        },
      ),
    );
  }
}

class _Data {
  final User? user;
  final (int, double, int) activity;
  const _Data(this.user, this.activity);
}
