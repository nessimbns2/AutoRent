import 'package:flutter/material.dart';

import '../../app/route_args.dart';
import '../../app/routes.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/ui_helpers.dart';
import '../../core/widgets/shared_widgets.dart';
import '../../core/widgets/status_chips.dart';
import '../../models/enums.dart';
import '../../models/rental.dart';
import '../../repositories/rental_repository.dart';

class RentalDetailScreen extends StatefulWidget {
  final int rentalId;
  const RentalDetailScreen({super.key, required this.rentalId});

  @override
  State<RentalDetailScreen> createState() => _RentalDetailScreenState();
}

class _RentalDetailScreenState extends State<RentalDetailScreen> {
  final _repo = RentalRepository();
  late Future<RentalView?> _future = _repo.getViewById(widget.rentalId);
  bool _didChange = false;

  void _reload() {
    setState(() {
      _future = _repo.getViewById(widget.rentalId);
    });
  }

  Future<void> _edit(Rental r) async {
    final saved = await Navigator.pushNamed(
      context,
      Routes.rentalForm,
      arguments: RentalFormArgs(
        rentalId: r.id,
        vehicleId: r.vehicleId,
        clientId: r.clientId,
      ),
    );
    if (saved == true && mounted) {
      _didChange = true;
      _reload();
    }
  }

  Future<void> _delete(Rental r) async {
    final ok = await confirmDialog(
      context,
      title: 'Supprimer location',
      message: 'Voulez-vous vraiment supprimer définitivement ce contrat ?',
      confirmLabel: 'Supprimer',
    );
    if (ok != true || !mounted) return;

    await _repo.delete(r.id!);
    if (!mounted) return;
    showSnack(context, 'Location supprimée');
    Navigator.pop(context, true);
  }

  Future<void> _changeStatus(Rental r, RentalStatus newStatus, String label) async {
    final ok = await confirmDialog(
      context,
      title: label,
      message: 'Confirmer le passage à "${newStatus.label}" ?',
    );
    if (ok != true || !mounted) return;

    await _repo.changeStatus(r.id!, newStatus);
    if (!mounted) return;
    showSnack(context, 'Statut mis à jour');
    _didChange = true;
    _reload();
  }

  Future<void> _declareIncident(Rental r) async {
    final created = await Navigator.pushNamed(
      context,
      Routes.incidentForm,
      arguments: IncidentFormArgs(vehicleId: r.vehicleId, rentalId: r.id),
    );
    if (created == true && mounted) {
      showSnack(context, 'Incident enregistré');
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {},
      child: FutureBuilder<RentalView?>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Scaffold(body: LoadingView());
          }
          if (snap.hasError || snap.data == null) {
            return Scaffold(
              appBar: AppBar(title: const Text('Contrat de location')),
              body: ErrorView(
                error: snap.error ?? 'Location introuvable',
                onRetry: _reload,
              ),
            );
          }
          final view = snap.data!;
          final r = view.rental;
          final isEditable = r.status == RentalStatus.reservee ||
              r.status == RentalStatus.enCours;

          return Scaffold(
            appBar: AppBar(
              title: Text('Contrat #${r.id}'),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context, _didChange),
              ),
              actions: [
                if (isEditable)
                  IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () => _edit(r),
                    tooltip: 'Modifier',
                  ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _delete(r),
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
                    title: 'Détails du contrat',
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const CircleAvatar(child: Icon(Icons.person)),
                        title: Text(view.clientName),
                        subtitle: const Text('Locataire'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.pushNamed(
                          context,
                          Routes.clientDetail,
                          arguments: IdArgs(r.clientId),
                        ),
                      ),
                      const Divider(),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const CircleAvatar(
                            child: Icon(Icons.directions_car)),
                        title: Text(view.vehicleLabel),
                        subtitle: const Text('Véhicule loué'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.pushNamed(
                          context,
                          Routes.vehicleDetail,
                          arguments: IdArgs(r.vehicleId),
                        ),
                      ),
                      const Divider(),
                      LabeledRow(
                        label: 'Statut',
                        value: '',
                        trailing: rentalStatusChip(r.status),
                      ),
                      LabeledRow(
                        label: 'Période',
                        value:
                            '${formatDate(r.startDate)} au ${formatDate(r.endDate)}',
                      ),
                      LabeledRow(label: 'Durée', value: '${r.days} jour(s)'),
                      LabeledRow(
                        label: 'Montant total',
                        value: formatMoney(r.totalPrice),
                      ),
                      LabeledRow(
                        label: 'Enregistré par',
                        value: view.userName ?? 'Système',
                      ),
                      LabeledRow(
                        label: 'Créé le',
                        value: formatDate(r.createdAt),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (r.status == RentalStatus.reservee) ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Démarrer la location'),
                        onPressed: () => _changeStatus(
                          r,
                          RentalStatus.enCours,
                          'Démarrer la location',
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.cancel_outlined),
                        label: const Text('Annuler la réservation'),
                        style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red),
                        onPressed: () => _changeStatus(
                          r,
                          RentalStatus.annulee,
                          'Annuler la réservation',
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (r.status == RentalStatus.enCours) ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.done_all),
                        label: const Text('Terminer la location'),
                        onPressed: () => _changeStatus(
                          r,
                          RentalStatus.terminee,
                          'Terminer la location',
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.cancel_outlined),
                        label: const Text('Annuler la location'),
                        style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red),
                        onPressed: () => _changeStatus(
                          r,
                          RentalStatus.annulee,
                          'Annuler la location',
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.report_problem_outlined),
                      label: const Text('Déclarer un incident'),
                      onPressed: () => _declareIncident(r),
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
