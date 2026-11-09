import 'package:flutter/material.dart';

import '../../app/route_args.dart';
import '../../app/routes.dart';
import '../../app/theme.dart';
import '../../core/utils/app_exception.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/ui_helpers.dart';
import '../../core/widgets/shared_widgets.dart';
import '../../models/client.dart';
import '../../models/enums.dart';
import '../../models/rental.dart';
import '../../repositories/client_repository.dart';
import '../../repositories/rental_repository.dart';
import '../rentals/widgets/rental_tile.dart';

class ClientDetailScreen extends StatefulWidget {
  final int clientId;
  const ClientDetailScreen({super.key, required this.clientId});

  @override
  State<ClientDetailScreen> createState() => _ClientDetailScreenState();
}

class _ClientDetailScreenState extends State<ClientDetailScreen> {
  final _clientRepo = ClientRepository();
  final _rentalRepo = RentalRepository();

  late Future<_Data> _future = _load();
  bool _didChange = false;

  Future<_Data> _load() async {
    final client = await _clientRepo.getById(widget.clientId);
    final rentals =
        await _rentalRepo.queryViews('r.client_id = ?', [widget.clientId]);
    return _Data(client, rentals);
  }

  void _reload() => setState(() { _future = _load(); });

  Future<void> _push(String route, Object? args) async {
    final changed = await Navigator.pushNamed(context, route, arguments: args);
    if (changed == true && mounted) {
      _didChange = true;
      _reload();
    }
  }

  Future<void> _delete(Client client) async {
    final ok = await confirmDialog(
      context,
      title: 'Supprimer ce locataire ?',
      message: '${client.fullName} sera définitivement supprimé.',
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
          if (snap.hasError || snap.data?.client == null) {
            return Scaffold(
              appBar: AppBar(title: const Text('Locataire')),
              body: ErrorView(
                  error: snap.error ?? 'Locataire introuvable',
                  onRetry: _reload),
            );
          }
          final c = snap.data!.client!;
          final rentals = snap.data!.rentals;
          final spent = rentals
              .where((r) => r.rental.status != RentalStatus.annulee)
              .fold<double>(0, (a, r) => a + r.rental.totalPrice);
          final initials =
              '${c.firstName.isNotEmpty ? c.firstName[0] : ''}${c.lastName.isNotEmpty ? c.lastName[0] : ''}'
                  .toUpperCase();

          return Scaffold(
            appBar: AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => Navigator.pop(context, _didChange),
              ),
              title: const Text('Locataire'),
              actions: [
                DetailMenu(items: [
                  DetailMenuItem('Modifier', Icons.edit_rounded,
                      () => _push(Routes.clientForm, ClientFormArgs(clientId: c.id))),
                  DetailMenuItem('Supprimer', Icons.delete_outline_rounded,
                      () => _delete(c),
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
                    AvatarCircle(initials: initials, size: 76),
                    const SizedBox(height: 10),
                    Text(c.fullName, style: context.text.titleLarge),
                    Text('Client depuis le ${formatShortDate(c.createdAt)}',
                        style: context.text.bodySmall),
                    const SizedBox(height: 16),
                    Row(children: [
                      Expanded(
                        child: InfoTile(
                            icon: Icons.receipt_long_rounded,
                            label: 'Locations',
                            value: '${rentals.length}',
                            color: AppColors.info),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: InfoTile(
                            icon: Icons.savings_rounded,
                            label: 'Dépensé',
                            value: formatMoneyShort(spent),
                            color: AppColors.success),
                      ),
                    ]),
                  ]),
                ),
                SectionCard(
                  title: 'Coordonnées',
                  icon: Icons.contact_page_rounded,
                  children: [
                    LabeledRow(
                        icon: Icons.phone_rounded,
                        label: 'Téléphone',
                        value: c.phone.isEmpty ? 'Non renseigné' : c.phone),
                    LabeledRow(
                        icon: Icons.alternate_email_rounded,
                        label: 'Email',
                        value: c.email?.isNotEmpty == true
                            ? c.email!
                            : 'Non renseigné'),
                    LabeledRow(
                        icon: Icons.badge_outlined,
                        label: 'N° de permis',
                        value: c.licenseNumber),
                  ],
                ),
                SectionHeader(title: 'Historique (${rentals.length})'),
                if (rentals.isEmpty)
                  const AppCard(
                    child: Text('Aucune location enregistrée pour ce client.'),
                  )
                else
                  for (final r in rentals)
                    RentalTile(
                      view: r,
                      showClient: false,
                      onTap: () =>
                          _push(Routes.rentalDetail, IdArgs(r.rental.id!)),
                    ),
              ],
            ),
            bottomNavigationBar: BottomActionBar(
              child: PrimaryButton(
                label: 'Nouvelle location',
                icon: Icons.car_rental_rounded,
                onPressed: () =>
                    _push(Routes.rentalForm, RentalFormArgs(clientId: c.id)),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Data {
  final Client? client;
  final List<RentalView> rentals;
  const _Data(this.client, this.rentals);
}
