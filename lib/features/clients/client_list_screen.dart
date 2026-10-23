import 'package:flutter/material.dart';

import '../../app/route_args.dart';
import '../../app/routes.dart';
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

  void _reload() {
    setState(() {
      _future = _repo.getAll(search: _searchController.text);
    });
  }

  Future<void> _openForm({int? id}) async {
    final saved = await Navigator.pushNamed(
      context,
      Routes.clientForm,
      arguments: id == null ? null : ClientFormArgs(clientId: id),
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
    return Scaffold(
      appBar: AppBar(title: const Text('Locataires')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          SearchField(
            hint: 'Rechercher par nom, téléphone, permis',
            onChanged: (_) => _reload(),
          ),
          Expanded(
            child: FutureBuilder<List<Client>>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const LoadingView();
                }
                if (snap.hasError) {
                  return ErrorView(error: snap.error!, onRetry: _reload);
                }
                final clients = snap.data ?? [];
                if (clients.isEmpty) {
                  return const EmptyState(message: 'Aucun locataire trouvé.');
                }
                return RefreshIndicator(
                  onRefresh: () async => _reload(),
                  child: ResponsiveCenter(
                    maxWidth: 900,
                    child: ListView.separated(
                      itemCount: clients.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final c = clients[index];
                        return ListTile(
                          leading: CircleAvatar(
                            child: Text(
                              c.firstName.isNotEmpty
                                  ? c.firstName[0].toUpperCase()
                                  : 'C',
                            ),
                          ),
                          title: Text(c.fullName),
                          subtitle: Text('${c.phone} • Permis: ${c.licenseNumber}'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () async {
                            final changed = await Navigator.pushNamed(
                              context,
                              Routes.clientDetail,
                              arguments: IdArgs(c.id!),
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
