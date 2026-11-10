import '../../core/services/pricing_service.dart';
import '../../core/session/session_manager.dart';
import '../../core/utils/formatters.dart';
import '../../models/enums.dart';
import '../../models/pricing_settings.dart';
import '../../repositories/dashboard_repository.dart';
import '../../repositories/pricing_repository.dart';
import '../../repositories/vehicle_repository.dart';
import '../vehicles/widgets/vehicle_card.dart';

/// Builds the system prompt of the AutoRent assistant: its role, the rules
/// of the agency and a fresh snapshot of the local SQLite data (fleet,
/// prices, pricing grid, activity), so Groq answers about *this* agency.
class AssistantContext {
  AssistantContext._();

  static String _pct(double v) => PricingService.percent(v);

  static String _grid(PricingSettings g) {
    final lines = <String>[];
    if (g.longStayEnabled) {
      lines.add(
        '- Remise longue durée : −${_pct(g.tier1Percent)} % dès '
        '${g.tier1Days} jours, −${_pct(g.tier2Percent)} % dès ${g.tier2Days} '
        'jours (seul le palier le plus élevé s\'applique).',
      );
    }
    if (g.seasonEnabled) {
      lines.add(
        '- Haute saison : +${_pct(g.seasonPercent)} % par jour du '
        '${formatMonthDay(g.seasonStartMonth, g.seasonStartDay)} au '
        '${formatMonthDay(g.seasonEndMonth, g.seasonEndDay)}.',
      );
    }
    if (g.weekendEnabled) {
      lines.add(
        '- Week-end : ${PricingService.signedPercent(g.weekendPercent)} '
        'par samedi et dimanche.',
      );
    }
    return lines.isEmpty
        ? '- Aucune règle : prix = jours × tarif journalier.'
        : lines.join('\n');
  }

  static Future<String> build() async {
    final user = SessionManager.instance.currentUser;
    final vehicles = await VehicleRepository().getAll(includeArchived: false);
    final repo = VehicleRepository();
    final fleet = StringBuffer();
    for (final v in vehicles) {
      final state = await repo.getAvailabilityState(v.id!);
      final specs = VehicleCard.specsLine(v);
      fleet.writeln(
        '- ${v.brand} ${v.model} (${v.plate})'
        '${specs.isEmpty ? '' : ' · $specs'}'
        ' · ${v.pricePerDay.toStringAsFixed(0)} DT/jour · ${state.label}',
      );
    }
    final grid = await PricingRepository().get();
    final d = await DashboardRepository().load();
    final today = DateTime.now();

    return '''
Tu es l'assistant virtuel de l'application AutoRent, une agence de location de voitures en Tunisie.
Tu aides ${user == null ? 'l\'agent' : '${user.firstName} (agent de l\'agence)'} à gérer la flotte, les locations, les entretiens et les incidents, et à répondre aux questions des clients.

Règles de réponse :
- Réponds toujours en français, de façon claire et courte (listes à puces si utile).
- Les montants sont en dinars tunisiens (DT).
- Appuie-toi UNIQUEMENT sur les données ci-dessous pour tout ce qui concerne la flotte, les prix et l'activité. Si une information manque, dis-le au lieu d'inventer.
- Tu ne peux pas modifier les données : explique où le faire dans l'application (onglets Accueil, Flotte, Locations, Suivi, Profil).
- Pour calculer un prix : pour chaque jour, tarif de base + majorations haute saison et week-end (calculées sur le tarif de base), puis remise longue durée sur le total.

Date du jour : ${formatLongDay(today)} ${today.year}.

Règles de l'agence :
- Une voiture dont l'assurance ou la visite technique est expirée (ou expire avant la fin de la location) ne peut pas être louée.
- Les jours de retard sont facturés au tarif journalier du contrat majoré de 20 %.

Grille tarifaire :
${_grid(grid)}

Flotte (${vehicles.length} véhicules) :
${fleet.toString().trim().isEmpty ? '- Aucun véhicule.' : fleet.toString().trim()}

Activité :
- Locations en cours : ${d.rentalsByStatus[RentalStatus.enCours] ?? 0}, réservations : ${d.rentalsByStatus[RentalStatus.reservee] ?? 0}, en retard : ${d.overdue}.
- Véhicules libres : ${d.fleet.available}/${d.fleet.total}.
- Incidents non résolus : ${d.pendingIncidents}, entretiens ouverts : ${d.openMaintenances}.
- Chiffre d'affaires du mois : ${formatMoneyShort(d.monthRevenue)}.
''';
  }
}
