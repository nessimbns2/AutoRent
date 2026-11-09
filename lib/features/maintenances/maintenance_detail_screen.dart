import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../app/route_args.dart';
import '../../app/routes.dart';
import '../../app/theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/ui_helpers.dart';
import '../../core/widgets/shared_widgets.dart';
import '../../core/widgets/status_chips.dart';
import '../../models/enums.dart';
import '../../models/maintenance.dart';
import '../../models/vehicle.dart';
import '../../repositories/maintenance_repository.dart';
import '../../repositories/vehicle_repository.dart';

class MaintenanceDetailScreen extends StatefulWidget {
  final int maintenanceId;
  const MaintenanceDetailScreen({super.key, required this.maintenanceId});

  @override
  State<MaintenanceDetailScreen> createState() =>
      _MaintenanceDetailScreenState();
}

class _MaintenanceDetailScreenState extends State<MaintenanceDetailScreen> {
  final _maintenanceRepo = MaintenanceRepository();
  final _vehicleRepo = VehicleRepository();

  late Future<_Data> _future = _load();
  bool _didChange = false;

  Future<_Data> _load() async {
    final m = await _maintenanceRepo.getById(widget.maintenanceId);
    final v = m == null ? null : await _vehicleRepo.getById(m.vehicleId);
    return _Data(m, v);
  }

  void _reload() => setState(() { _future = _load(); });

  Future<void> _edit(Maintenance m) async {
    final saved = await Navigator.pushNamed(
      context,
      Routes.maintenanceForm,
      arguments:
          MaintenanceFormArgs(maintenanceId: m.id, vehicleId: m.vehicleId),
    );
    if (saved == true && mounted) {
      _didChange = true;
      _reload();
    }
  }

  Future<void> _delete(Maintenance m) async {
    final ok = await confirmDialog(
      context,
      title: 'Supprimer cet entretien ?',
      message: '${m.type} du ${formatDate(m.date)} sera supprimé.',
      confirmLabel: 'Supprimer',
    );
    if (ok != true || !mounted) return;
    await _maintenanceRepo.delete(m.id!);
    if (!mounted) return;
    showSnack(context, 'Entretien supprimé');
    Navigator.pop(context, true);
  }

  Future<void> _changeStatus(Maintenance m, MaintenanceStatus to) async {
    if (to == MaintenanceStatus.termine) {
      // Show completion dialog to capture final cost & mileage.
      final result = await _showCompletionDialog(m);
      if (result == null || !mounted) return;
      await _maintenanceRepo.complete(
        m.id!,
        costActual: result.$1,
        mileage: result.$2,
      );
      if (!mounted) return;
      _didChange = true;
      _reload();
      showSnack(context, 'Entretien terminé');
    } else {
      final ok = await confirmDialog(
        context,
        title: "Démarrer l'entretien ?",
        message:
            'Le véhicule sera indisponible à la location pendant l\'intervention.',
        icon: Icons.play_arrow_rounded,
      );
      if (ok != true || !mounted) return;
      await _maintenanceRepo.changeStatus(m.id!, to);
      if (!mounted) return;
      showSnack(context, 'Statut mis à jour');
    }
    _didChange = true;
    _reload();
  }

  Future<void> _exportPdf(Maintenance m, Vehicle? vehicle) async {
    final doc = pw.Document();
    final repo = MaintenanceRepository();
    final days = (m.startedAt != null && m.endedAt != null)
        ? repo.immoDays(m.startedAt!, m.endedAt!)
        : 0;
    final lost = days * (vehicle?.pricePerDay ?? 0.0);

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (pw.Context ctx) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'AutoRent',
                        style: pw.TextStyle(
                          fontSize: 24,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blue900,
                        ),
                      ),
                      pw.Text(
                        'Fiche d\'intervention d\'entretien',
                        style: const pw.TextStyle(
                          fontSize: 13,
                          color: PdfColors.grey700,
                        ),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'Ref: #ENT-${m.id}',
                        style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        formatDate(m.date),
                        style: const pw.TextStyle(
                          fontSize: 11,
                          color: PdfColors.grey600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              pw.Divider(thickness: 1.5, color: PdfColors.blue900),
              pw.SizedBox(height: 16),

              // Section 1: Véhicule
              pw.Text(
                '1. VEHICULE CONCERNE',
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue800,
                ),
              ),
              pw.SizedBox(height: 6),
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      vehicle != null
                          ? '${vehicle.brand} ${vehicle.model}'
                          : 'Vehicule ID: ${m.vehicleId}',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                    pw.Text(
                      vehicle?.plate ?? '-',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                    if (m.mileage != null)
                      pw.Text('${m.mileage} km'),
                  ],
                ),
              ),
              pw.SizedBox(height: 16),

              // Section 2: Intervention
              pw.Text(
                '2. DETAILS DE L\'INTERVENTION',
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue800,
                ),
              ),
              pw.SizedBox(height: 6),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300),
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('Type d\'intervention',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(m.type),
                      ),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('Statut',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('Termine'),
                      ),
                    ],
                  ),
                  if (m.garage != null && m.garage!.isNotEmpty)
                    pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('Garage / Prestataire',
                              style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(m.garage!),
                        ),
                      ],
                    ),
                  if (m.mileage != null)
                    pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('Kilometrage releve',
                              style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('${m.mileage} km'),
                        ),
                      ],
                    ),
                ],
              ),
              pw.SizedBox(height: 16),

              // Section 3: Bilan financier & Atelier
              pw.Text(
                '3. BILAN FINANCIER & ATELIER',
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue800,
                ),
              ),
              pw.SizedBox(height: 6),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300),
                children: [
                  if (m.costEstimated != null)
                    pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('Cout estime'),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('${m.costEstimated!.toStringAsFixed(2)} DT'),
                        ),
                      ],
                    ),
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('Cout reel paye',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          m.costActual != null
                              ? '${m.costActual!.toStringAsFixed(2)} DT'
                              : 'Non renseigne',
                          style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.green800),
                        ),
                      ),
                    ],
                  ),
                  if (days > 0)
                    pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('Duree d\'immobilisation'),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('$days jour${days > 1 ? 's' : ''} en atelier'),
                        ),
                      ],
                    ),
                  if (lost > 0)
                    pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('Manque a gagner estime'),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            '${lost.toStringAsFixed(2)} DT (${vehicle?.pricePerDay.toStringAsFixed(0)} DT/jour)',
                            style: const pw.TextStyle(color: PdfColors.red800),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              pw.SizedBox(height: 16),

              // Section 4: Observations
              if (m.description != null && m.description!.isNotEmpty) ...[
                pw.Text(
                  '4. OBSERVATIONS & NOTES',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue800,
                  ),
                ),
                pw.SizedBox(height: 6),
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey100,
                    borderRadius: pw.BorderRadius.circular(6),
                    border: pw.Border.all(color: PdfColors.grey300),
                  ),
                  child: pw.Text(m.description!),
                ),
                pw.SizedBox(height: 16),
              ],

              pw.Spacer(),

              // Signatures & footer
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Signature Responsable Flotte :'),
                      pw.SizedBox(height: 40),
                      pw.Container(
                        width: 150,
                        decoration: const pw.BoxDecoration(
                          border: pw.Border(top: pw.BorderSide(color: PdfColors.grey400)),
                        ),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Cachet du Garage :'),
                      pw.SizedBox(height: 40),
                      pw.Container(
                        width: 150,
                        decoration: const pw.BoxDecoration(
                          border: pw.Border(top: pw.BorderSide(color: PdfColors.grey400)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 16),
              pw.Divider(color: PdfColors.grey300),
              pw.Center(
                child: pw.Text(
                  'Fiche generee automatiquement par AutoRent - Application de gestion de flotte',
                  style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey500),
                ),
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
      name: 'fiche_entretien_${m.id}.pdf',
    );
  }

  /// Dialog shown when completing a maintenance — asks for final cost & mileage.
  Future<(double?, int?)?> _showCompletionDialog(Maintenance m) async {
    final costCtrl =
        TextEditingController(text: m.costEstimated?.toStringAsFixed(0) ?? '');
    final mileageCtrl =
        TextEditingController(text: m.mileage?.toString() ?? '');

    return showDialog<(double?, int?)>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Terminer l'entretien"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Renseignez le coût réel et le kilométrage final.'),
            const SizedBox(height: 14),
            TextField(
              controller: costCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Coût réel (DT)',
                prefixIcon: Icon(Icons.payments_outlined),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: mileageCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Kilométrage (km)',
                prefixIcon: Icon(Icons.speed_rounded),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          FilledButton.icon(
            onPressed: () {
              final cost = double.tryParse(costCtrl.text.trim());
              final km = int.tryParse(mileageCtrl.text.trim());
              Navigator.pop(ctx, (cost, km));
            },
            icon: const Icon(Icons.task_alt_rounded),
            label: const Text('Terminer'),
          ),
        ],
      ),
    );
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
          if (snap.hasError || snap.data?.maintenance == null) {
            return Scaffold(
              appBar: AppBar(title: const Text('Entretien')),
              body: ErrorView(
                  error: snap.error ?? 'Entretien introuvable',
                  onRetry: _reload),
            );
          }
          final m = snap.data!.maintenance!;
          final vehicle = snap.data!.vehicle;
          final color = maintenanceStatusColor(m.status);

          return Scaffold(
            appBar: AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => Navigator.pop(context, _didChange),
              ),
              title: const Text('Entretien'),
              actions: [
                if (m.status == MaintenanceStatus.termine)
                  IconButton(
                    icon: const Icon(Icons.picture_as_pdf_rounded),
                    tooltip: 'Exporter en PDF',
                    onPressed: () => _exportPdf(m, vehicle),
                  ),
                DetailMenu(items: [
                  DetailMenuItem(
                      'Modifier', Icons.edit_rounded, () => _edit(m)),
                  DetailMenuItem('Supprimer', Icons.delete_outline_rounded,
                      () => _delete(m),
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
                    IconBadge(
                        icon: maintenanceTypeIcon(m.type),
                        color: color,
                        size: 72),
                    const SizedBox(height: 12),
                    Text(m.type, style: context.text.headlineSmall),
                    const SizedBox(height: 6),
                    maintenanceStatusChip(m.status),
                    const SizedBox(height: 12),
                    Text(
                        '${formatLongDay(m.date)} ${m.date.year} · ${relativeDay(m.date)}',
                        style: context.text.bodySmall),
                  ]),
                ),
                if (vehicle != null)
                  AppCard(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.all(12),
                    onTap: () => Navigator.pushNamed(
                        context, Routes.vehicleDetail,
                        arguments: IdArgs(vehicle.id!)),
                    child: Row(children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        child: CarImage(
                          fileName: vehicle.photos.isNotEmpty
                              ? vehicle.photos.first
                              : null,
                          seed: vehicle.id ?? 0,
                          width: 64,
                          height: 48,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${vehicle.brand} ${vehicle.model}',
                                style: context.text.titleSmall),
                            Text(vehicle.plate, style: context.text.bodySmall),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded,
                          color: context.palette.muted),
                    ]),
                  ),
                SectionCard(
                  title: 'Informations',
                  icon: Icons.info_rounded,
                  iconColor: AppColors.info,
                  children: [
                    LabeledRow(
                        icon: Icons.category_outlined,
                        label: "Type d'intervention",
                        value: m.type),
                    LabeledRow(
                        icon: Icons.event_rounded,
                        label: 'Date prévue',
                        value: formatDate(m.date)),
                    if (m.garage != null && m.garage!.isNotEmpty)
                      LabeledRow(
                          icon: Icons.store_rounded,
                          label: 'Garage',
                          value: m.garage!),
                    if (m.mileage != null)
                      LabeledRow(
                          icon: Icons.speed_rounded,
                          label: 'Kilométrage',
                          value: '${m.mileage} km'),
                    LabeledRow(
                        icon: Icons.history_toggle_off_rounded,
                        label: 'Créé le',
                        value: formatDate(m.createdAt)),
                    if (m.description != null &&
                        m.description!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: context.palette.surfaceAlt,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        child: Text(m.description!,
                            style: context.text.bodyMedium),
                      ),
                    ],
                  ],
                ),
                if (m.costEstimated != null || m.costActual != null)
                  SectionCard(
                    title: 'Coûts',
                    icon: Icons.payments_rounded,
                    iconColor: AppColors.success,
                    children: [
                      if (m.costEstimated != null)
                        LabeledRow(
                            icon: Icons.payments_outlined,
                            label: 'Coût estimé',
                            value: '${m.costEstimated!.toStringAsFixed(0)} DT'),
                      if (m.costActual != null)
                        LabeledRow(
                            icon: Icons.receipt_long_rounded,
                            label: 'Coût réel',
                            value: '${m.costActual!.toStringAsFixed(0)} DT'),
                    ],
                  ),
                // Immobilisation section — only shown when both timestamps exist.
                if (m.startedAt != null && m.endedAt != null)
                  _ImmoSection(m: m, vehicle: vehicle),
              ],
            ),
            bottomNavigationBar: switch (m.status) {
              MaintenanceStatus.planifie => BottomActionBar(
                  child: PrimaryButton(
                    label: "Démarrer l'entretien",
                    icon: Icons.play_arrow_rounded,
                    onPressed: () =>
                        _changeStatus(m, MaintenanceStatus.enCours),
                  ),
                ),
              MaintenanceStatus.enCours => BottomActionBar(
                  child: PrimaryButton(
                    label: "Terminer l'entretien",
                    icon: Icons.task_alt_rounded,
                    color: AppColors.success,
                    onPressed: () =>
                        _changeStatus(m, MaintenanceStatus.termine),
                  ),
                ),
              MaintenanceStatus.termine => BottomActionBar(
                  child: PrimaryButton(
                    label: 'Exporter la fiche (PDF)',
                    icon: Icons.picture_as_pdf_rounded,
                    onPressed: () => _exportPdf(m, vehicle),
                  ),
                ),
            },
          );
        },
      ),
    );
  }
}

class _Data {
  final Maintenance? maintenance;
  final Vehicle? vehicle;
  const _Data(this.maintenance, this.vehicle);
}

/// Shows immobilisation duration and estimated lost revenue when the
/// maintenance has both started_at and ended_at timestamps.
class _ImmoSection extends StatelessWidget {
  final Maintenance m;
  final Vehicle? vehicle;
  const _ImmoSection({required this.m, required this.vehicle});

  @override
  Widget build(BuildContext context) {
    final repo = MaintenanceRepository();
    final days = repo.immoDays(m.startedAt!, m.endedAt!);
    final dailyRate = vehicle?.pricePerDay ?? 0.0;
    final lost = days * dailyRate;

    return SectionCard(
      title: 'Immobilisation',
      icon: Icons.garage_rounded,
      iconColor: AppColors.warning,
      children: [
        LabeledRow(
          icon: Icons.timer_outlined,
          label: 'Durée en atelier',
          value: '$days jour${days > 1 ? 's' : ''}',
        ),
        if (dailyRate > 0)
          LabeledRow(
            icon: Icons.trending_down_rounded,
            label: 'Manque à gagner estimé',
            value: '${lost.toStringAsFixed(0)} DT',
          ),
      ],
    );
  }
}
