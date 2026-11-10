import 'package:flutter/material.dart';

import '../../app/route_args.dart';
import '../../app/routes.dart';
import '../../app/theme.dart';
import '../../core/widgets/shared_widgets.dart';
import '../../models/client.dart';
import '../../repositories/client_repository.dart';

class ClientListScreen extends StatefulWidget {
  const ClientListScreen({super.key});

  @override
  State<ClientListScreen> createState() => _ClientListScreenState();
}

class _ClientListScreenState extends State<ClientListScreen> {
  final _repo = ClientRepository();
  final _searchController = TextEditingController();
  late Future<List<Client>> _future = _repo.getAll();

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

  String _initials(Client c) =>
      '${c.firstName.isNotEmpty ? c.firstName[0] : ''}${c.lastName.isNotEmpty ? c.lastName[0] : ''}'
          .toUpperCase();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Locataires')),
      floatingActionButton: GradientFab(
        onPressed: () => _open(Routes.clientForm),
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Locataire'),
      ),
      body: Column(children: [
        SearchField(
          controller: _searchController,
          hint: 'Nom, téléphone ou n° de permis',
          onChanged: (_) => _reload(),
        ),
        Expanded(
          child: FutureBuilder<List<Client>>(
            future: _future,
            builder: (context, snap) {
              if (snap.hasError) {
                return ErrorView(error: snap.error!, onRetry: _reload);
              }
              if (!snap.hasData) return const LoadingView();
              final clients = snap.data!;
              if (clients.isEmpty) {
                return EmptyState(
                  icon: Icons.people_alt_outlined,
                  title: 'Aucun locataire',
                  message: _searchController.text.isEmpty
                      ? 'Ajoutez votre premier client.'
                      : 'Aucun locataire ne correspond à la recherche.',
                );
              }
              return RefreshIndicator(
                onRefresh: () async => _reload(),
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 96),
                  itemCount: clients.length,
                  itemBuilder: (context, i) {
                    final c = clients[i];
                    return AppCard(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      onTap: () =>
                          _open(Routes.clientDetail, IdArgs(c.id!)),
                      child: Row(children: [
                        AvatarCircle(initials: _initials(c), size: 46),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(c.fullName, style: context.text.titleSmall),
                              const SizedBox(height: 2),
                              Row(children: [
                                Icon(Icons.phone_rounded,
                                    size: 13, color: context.palette.muted),
                                const SizedBox(width: 4),
                                Text(c.phone.isEmpty ? '—' : c.phone,
                                    style: context.text.bodySmall),
                                const SizedBox(width: 10),
                                Icon(Icons.badge_outlined,
                                    size: 13, color: context.palette.muted),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(c.licenseNumber,
                                      style: context.text.bodySmall,
                                      overflow: TextOverflow.ellipsis),
                                ),
                              ]),
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
