import 'package:flutter/material.dart';

import '../../app/route_args.dart';
import '../../app/routes.dart';
import '../../app/theme.dart';
import '../../core/session/session_manager.dart';
import '../../core/widgets/shared_widgets.dart';
import '../../models/user.dart';
import '../../repositories/user_repository.dart';

class UserListScreen extends StatefulWidget {
  const UserListScreen({super.key});

  @override
  State<UserListScreen> createState() => _UserListScreenState();
}

class _UserListScreenState extends State<UserListScreen> {
  final _repo = UserRepository();
  final _searchController = TextEditingController();
  late Future<List<User>> _future = _repo.getAll();

  void _reload() => setState(() { _future = _repo.getAll(search: _searchController.text); });

  Future<void> _open(String route, [Object? args]) async {
    final saved = await Navigator.pushNamed(context, route, arguments: args);
    if (saved == true && mounted) _reload();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = SessionManager.instance.currentUser?.id;

    return Scaffold(
      appBar: AppBar(title: const Text('Utilisateurs')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _open(Routes.userForm),
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Agent'),
      ),
      body: Column(children: [
        SearchField(
          controller: _searchController,
          hint: 'Nom ou email',
          onChanged: (_) => _reload(),
        ),
        Expanded(
          child: FutureBuilder<List<User>>(
            future: _future,
            builder: (context, snap) {
              if (snap.hasError) {
                return ErrorView(error: snap.error!, onRetry: _reload);
              }
              if (!snap.hasData) return const LoadingView();
              final users = snap.data!;
              if (users.isEmpty) {
                return const EmptyState(
                  icon: Icons.manage_accounts_outlined,
                  title: 'Aucun utilisateur',
                  message: 'Aucun compte ne correspond à la recherche.',
                );
              }
              return RefreshIndicator(
                onRefresh: () async => _reload(),
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 96),
                  itemCount: users.length,
                  itemBuilder: (context, i) {
                    final u = users[i];
                    final isCurrent = u.id == currentUserId;
                    return AppCard(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      onTap: () => _open(Routes.userDetail, IdArgs(u.id!)),
                      child: Row(children: [
                        AvatarCircle(
                            initials: u.initials,
                            photoFile: u.photoFile,
                            size: 46),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                Flexible(
                                  child: Text(u.fullName,
                                      style: context.text.titleSmall,
                                      overflow: TextOverflow.ellipsis),
                                ),
                                if (isCurrent) ...[
                                  const SizedBox(width: 8),
                                  const StatusChip(
                                      label: 'Vous', color: AppColors.brand),
                                ],
                              ]),
                              Text(u.email,
                                  style: context.text.bodySmall,
                                  overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded,
                            color: context.palette.muted),
                      ]),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ]),
    );
  }
}
