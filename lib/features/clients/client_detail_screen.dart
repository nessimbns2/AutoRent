import 'package:flutter/material.dart';

import '../../app/route_args.dart';
import '../../app/routes.dart';
import '../../core/utils/app_exception.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/ui_helpers.dart';
import '../../core/widgets/shared_widgets.dart';
import '../../core/widgets/status_chips.dart';
import '../../models/client.dart';
import '../../models/rental.dart';
import '../../repositories/client_repository.dart';
import '../../repositories/rental_repository.dart';

class ClientDetailScreen extends StatefulWidget {
  final int clientId;
  const ClientDetailScreen({super.key, required this.clientId});

  @override
  State<ClientDetailScreen> createState() => _ClientDetailScreenState();
}

class _ClientDetailScreenState extends State<ClientDetailScreen> {
  final _clientRepo = ClientRepository();
  final _rentalRepo = RentalRepository();

  late Future<_ClientDetailData> _future = _load();
  bool _didChange = false;

  Future<_ClientDetailData> _load() async {
    final client = await _clientRepo.getById(widget.clientId);
    final rentals = await _rentalRepo.getByClient(widget.clientId);
    return _ClientDetailData(client: client, rentals: rentals);
  }

  void _reload() {
    setState(() {
      _future = _load();
    });
  }

  Future<void> _edit(Client client) async {
    final saved = await Navigator.pushNamed(
      context,
      Routes.clientForm,
      arguments: ClientFormArgs(clientId: client.id),
    );
    if (saved == true && mounted) {
      _didChange = true;
      _reload();
    }
  }

  Future<void> _delete(Client client) async {
    final ok = await confirmDialog(
      context,
      title: 'Supprimer locataire',
      message: 'Voulez-vous vraiment supprimer ce locataire ?',
      confirmLabel: 'Supprimer',
    );
    if (ok != true || !mounted) return;

    try {
      await _clientRepo.delete(client.id!);
      if (!mounted) return;
      showSnack(context, 'Locataire supprimé');
      Navigator.pop(context, true);
    } on AppException catch (e) {
      if (mounted) showSnack(context, e.message);
    }
  }

  Future<void> _newRental(Client client) async {
    final changed = await Navigator.pushNamed(
      context,
      Routes.rentalForm,
      arguments: RentalFormArgs(clientId: client.id),
    );
    if (changed == true && mounted) {
      _didChange = true;
      _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {},
      child: FutureBuilder<_ClientDetailData>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Scaffold(body: LoadingView());
          }
          if (snap.hasError || snap.data?.client == null) {
            return Scaffold(
              appBar: AppBar(title: const Text('Détail locataire')),
              body: ErrorView(
                error: snap.error ?? 'Locataire introuvable',
                onRetry: _reload,
              ),
            );
          }
          final client = snap.data!.client!;
          final rentals = snap.data!.rentals;

          return Scaffold(
            appBar: AppBar(
              title: Text(client.fullName),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context, _didChange),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () => _edit(client),
                  tooltip: 'Modifier',
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _delete(client),
                  tooltip: 'Supprimer',
                ),
              ],
            ),
            body: ResponsiveCenter(
              maxWidth: 850,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionCard(
                    title: 'Coordonnées',
                    children: [
                      LabeledRow(label: 'Nom', value: client.lastName),
                      LabeledRow(label: 'Prénom', value: client.firstName),
                      LabeledRow(label: 'Téléphone', value: client.phone),
                      LabeledRow(
                        label: 'Email',
                        value: client.email?.isNotEmpty == true
                            ? client.email!
                            : 'Non renseigné',
                      ),
                      LabeledRow(
                        label: 'N° de permis',
                        value: client.licenseNumber,
                      ),
                      LabeledRow(
                        label: 'Inscrit le',
                        value: formatDate(client.createdAt),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text('Nouvelle location pour ce client'),
                      onPressed: () => _newRental(client),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Historique des locations (${rentals.length})',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  if (rentals.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        'Aucune location enregistrée pour ce client.',
                        style: TextStyle(fontStyle: FontStyle.italic),
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: rentals.length,
                      itemBuilder: (context, index) {
                        final r = rentals[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            title: Text(
                              '${formatDate(r.startDate)} → ${formatDate(r.endDate)} (${r.days} j)',
                            ),
                            subtitle: Text(formatMoney(r.totalPrice)),
                            trailing: rentalStatusChip(r.status),
                            onTap: () async {
                              final changed = await Navigator.pushNamed(
                                context,
                                Routes.rentalDetail,
                                arguments: IdArgs(r.id!),
                              );
                              if (changed == true && mounted) {
                                _didChange = true;
                                _reload();
                              }
                            },
                          ),
                        );
                      },
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

class _ClientDetailData {
  final Client? client;
  final List<Rental> rentals;
  _ClientDetailData({required this.client, required this.rentals});
}
