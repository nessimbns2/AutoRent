import 'package:flutter/material.dart';

import '../../app/route_args.dart';
import '../../app/routes.dart';
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

  void _reload() {
    setState(() {
      _future = _repo.getAll(search: _searchController.text);
    });
  }

  Future<void> _openForm({int? id}) async {
    final saved = await Navigator.pushNamed(
      context,
      Routes.userForm,
      arguments: id == null ? null : UserFormArgs(userId: id),
    );
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
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          SearchField(
            hint: 'Rechercher par nom ou email',
            onChanged: (_) => _reload(),
          ),
          Expanded(
            child: FutureBuilder<List<User>>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const LoadingView();
                }
                if (snap.hasError) {
                  return ErrorView(error: snap.error!, onRetry: _reload);
                }
                final users = snap.data ?? [];
                if (users.isEmpty) {
                  return const EmptyState(message: 'Aucun utilisateur trouvé.');
                }
                return RefreshIndicator(
                  onRefresh: () async => _reload(),
                  child: ResponsiveCenter(
                    maxWidth: 900,
                    child: ListView.separated(
                      itemCount: users.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final u = users[index];
                        final isCurrent = u.id == currentUserId;
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor:
                                Theme.of(context).colorScheme.primaryContainer,
                            child: Text(
                              u.initials,
                              style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onPrimaryContainer,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  u.fullName,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isCurrent) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primary
                                        .withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'Vous',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          subtitle: Text(u.email),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () async {
                            final changed = await Navigator.pushNamed(
                              context,
                              Routes.userDetail,
                              arguments: IdArgs(u.id!),
                            );
                            if (changed == true && mounted) _reload();
                          },
                        );
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
