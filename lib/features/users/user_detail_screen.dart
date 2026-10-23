import 'package:flutter/material.dart';

import '../../app/route_args.dart';
import '../../app/routes.dart';
import '../../core/services/image_storage.dart';
import '../../core/session/session_manager.dart';
import '../../core/utils/app_exception.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/ui_helpers.dart';
import '../../core/widgets/shared_widgets.dart';
import '../../models/user.dart';
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
  bool _didChange = false;

  void _reload() {
    setState(() {
      _future = _repo.getById(widget.userId);
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

  Future<void> _resetPassword(User user) async {
    final passwordController = TextEditingController();
    final confirmController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Réinitialiser le mot de passe'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: passwordController,
                obscureText: true,
                decoration:
                    const InputDecoration(labelText: 'Nouveau mot de passe'),
                validator: (v) => (v == null || v.length < 6)
                    ? 'Minimum 6 caractères'
                    : null,
              ),
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

    if (ok == true && mounted) {
      await _repo.updatePassword(user.email, passwordController.text);
      if (mounted) {
        showSnack(context, 'Mot de passe réinitialisé avec succès');
      }
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
                      if (isCurrent)
                        const LabeledRow(
                          label: 'Statut',
                          value: 'Votre session actuelle',
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.lock_reset),
                      label: const Text('Réinitialiser le mot de passe'),
                      onPressed: () => _resetPassword(user),
                    ),
                  ),
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
