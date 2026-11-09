import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/route_args.dart';
import '../../app/routes.dart';
import '../../app/theme.dart';
import '../../models/maintenance.dart';
import '../../models/rental.dart';
import '../../repositories/rental_repository.dart';
import '../constants/business_rules.dart';
import '../database/database_helper.dart';
import '../utils/formatters.dart';

/// Priority group of an alert.
enum AlertLevel {
  urgent('Urgent'),
  today("Aujourd'hui"),
  upcoming('À venir');

  const AlertLevel(this.label);
  final String label;
}

class AppAlert {
  final String id;
  final AlertLevel level;
  final IconData icon;
  final Color color;
  final String title;
  final String message;
  final DateTime date;
  final String route;
  final Object args;
  final bool read;

  const AppAlert({
    required this.id,
    required this.level,
    required this.icon,
    required this.color,
    required this.title,
    required this.message,
    required this.date,
    required this.route,
    required this.args,
    this.read = false,
  });

  AppAlert asRead() => AppAlert(
        id: id,
        level: level,
        icon: icon,
        color: color,
        title: title,
        message: message,
        date: date,
        route: route,
        args: args,
        read: true,
      );
}

/// Business notifications computed from the local SQLite data.
///
/// Every alert has a stable id that includes the date it depends on, so an
/// alert marked as read comes back if the situation changes (e.g. a rental
/// is extended and becomes late again).
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  static const _kRead = 'alerts_read';

  /// Number of unread alerts (drives the bell badge).
  final ValueNotifier<int> unread = ValueNotifier(0);

  /// Number of unread urgent alerts.
  final ValueNotifier<int> urgentUnread = ValueNotifier(0);

  final _rentals = RentalRepository();

  Future<Set<String>> _readIds() async {
    final p = await SharedPreferences.getInstance();
    return (p.getStringList(_kRead) ?? const []).toSet();
  }

  Future<void> _saveReadIds(Set<String> ids) async {
    final p = await SharedPreferences.getInstance();
    await p.setStringList(_kRead, ids.toList());
  }

  /// Recomputes the alerts and updates the unread counters.
  Future<List<AppAlert>> refresh() async {
    final alerts = await _compute();
    final read = await _readIds();
    // Forget read flags of alerts that no longer exist.
    final live = alerts.map((a) => a.id).toSet();
    final kept = read.intersection(live);
    if (kept.length != read.length) await _saveReadIds(kept);

    final result = [
      for (final a in alerts) kept.contains(a.id) ? a.asRead() : a
    ];
    unread.value = result.where((a) => !a.read).length;
    urgentUnread.value =
        result.where((a) => !a.read && a.level == AlertLevel.urgent).length;
    return result;
  }

  Future<void> markRead(Iterable<String> ids) async {
    final read = await _readIds()..addAll(ids);
    await _saveReadIds(read);
    await refresh();
  }

  // ── Business rules ─────────────────────────────────────────────────────────

  Future<List<AppAlert>> _compute() async {
    final db = await DatabaseHelper.instance.database;
    final today = DateUtils.dateOnly(DateTime.now());
    final t = toIsoDate(today);
    String inDays(int n) => toIsoDate(today.add(Duration(days: n)));
    final out = <AppAlert>[];

    String vehicle(RentalView v) {
      final i = v.vehicleLabel.lastIndexOf(' · ');
      return i < 0 ? v.vehicleLabel : v.vehicleLabel.substring(0, i);
    }

    AppAlert rentalAlert(RentalView v, String key, AlertLevel level,
            IconData icon, Color color, String title, String message,
            DateTime date) =>
        AppAlert(
          id: '$key-${v.rental.id}-${toIsoDate(date)}',
          level: level,
          icon: icon,
          color: color,
          title: title,
          message: message,
          date: date,
          route: Routes.rentalDetail,
          args: IdArgs(v.rental.id!),
        );

    // 1. Late returns
    for (final v in await _rentals.queryViews(
        "r.statut = 'en_cours' AND r.date_fin < ?", [t],
        orderBy: 'r.date_fin ASC')) {
      final r = v.rental;
      final days = BusinessRules.lateDays(r.endDate);
      out.add(rentalAlert(
        v, 'late', AlertLevel.urgent, Icons.schedule_rounded, AppColors.danger,
        'Retour en retard · ${vehicle(v)}',
        '${v.clientName} devait rendre le véhicule le ${formatShortDate(r.endDate)} '
            '($days j de retard, ≈ ${formatMoneyShort(BusinessRules.lateFee(r))} de frais).',
        r.endDate,
      ));
    }

    // 2. Reservations not picked up (no-show)
    for (final v in await _rentals.queryViews(
        "r.statut = 'reservee' AND r.date_debut < ?", [t],
        orderBy: 'r.date_debut ASC')) {
      out.add(rentalAlert(
        v, 'noshow', AlertLevel.urgent, Icons.person_off_rounded,
        AppColors.danger, 'Réservation non retirée · ${vehicle(v)}',
        '${v.clientName} devait prendre le véhicule le ${formatShortDate(v.rental.startDate)}. '
            'Démarrez ou annulez la réservation.',
        v.rental.startDate,
      ));
    }

    // 3. Reserved vehicle currently under maintenance (conflict)
    for (final v in await _rentals.queryViews(
        "r.statut = 'reservee' AND r.date_debut <= ? AND EXISTS ("
        "SELECT 1 FROM maintenances m WHERE m.vehicle_id = r.vehicle_id "
        "AND m.statut = 'en_cours')",
        [inDays(BusinessRules.maintenanceReminderDays)],
        orderBy: 'r.date_debut ASC')) {
      out.add(rentalAlert(
        v, 'conflict', AlertLevel.urgent, Icons.build_circle_rounded,
        AppColors.danger, 'Conflit · ${vehicle(v)} en entretien',
        'Réservé par ${v.clientName} à partir du ${formatShortDate(v.rental.startDate)} '
            'alors que le véhicule est en atelier. Terminez l\'entretien ou changez de véhicule.',
        v.rental.startDate,
      ));
    }

    // 4. Returns today / tomorrow
    for (final v in await _rentals.queryViews(
        "r.statut = 'en_cours' AND r.date_fin BETWEEN ? AND ?",
        [t, inDays(1)],
        orderBy: 'r.date_fin ASC')) {
      final isToday = DateUtils.isSameDay(v.rental.endDate, today);
      out.add(rentalAlert(
        v, 'return', isToday ? AlertLevel.today : AlertLevel.upcoming,
        Icons.assignment_return_rounded, AppColors.info,
        '${isToday ? "Retour aujourd'hui" : 'Retour demain'} · ${vehicle(v)}',
        'Préparez l\'état des lieux avec ${v.clientName}.',
        v.rental.endDate,
      ));
    }

    // 5. Pick-ups today and reservations to prepare
    for (final v in await _rentals.queryViews(
        "r.statut = 'reservee' AND r.date_debut BETWEEN ? AND ?",
        [t, inDays(BusinessRules.reservationReminderDays)],
        orderBy: 'r.date_debut ASC')) {
      final isToday = DateUtils.isSameDay(v.rental.startDate, today);
      out.add(rentalAlert(
        v, 'pickup', isToday ? AlertLevel.today : AlertLevel.upcoming,
        Icons.key_rounded, AppColors.warning,
        isToday
            ? 'Départ aujourd\'hui · ${vehicle(v)}'
            : 'Réservation ${relativeDay(v.rental.startDate).toLowerCase()} · ${vehicle(v)}',
        isToday
            ? 'Remettez les clés à ${v.clientName}.'
            : 'Préparez le véhicule pour ${v.clientName}.',
        v.rental.startDate,
      ));
    }

    // 6. Planned maintenance: overdue or soon
    final mRows = await db.rawQuery('''
      SELECT m.*, v.marque || ' ' || v.modele AS vehicle_name
      FROM maintenances m JOIN vehicles v ON v.id = m.vehicle_id
      WHERE m.statut = 'planifie' AND m.date <= ?
      ORDER BY m.date ASC
    ''', [inDays(BusinessRules.maintenanceReminderDays)]);
    for (final row in mRows) {
      final m = Maintenance.fromMap(row);
      final name = row['vehicle_name'] as String;
      final late = DateUtils.dateOnly(m.date).isBefore(today);
      final isToday = DateUtils.isSameDay(m.date, today);
      out.add(AppAlert(
        id: 'maint-${m.id}-${toIsoDate(m.date)}',
        level: late
            ? AlertLevel.urgent
            : isToday
                ? AlertLevel.today
                : AlertLevel.upcoming,
        icon: Icons.handyman_rounded,
        color: late ? AppColors.danger : AppColors.teal,
        title: late
            ? 'Entretien en retard · $name'
            : '${m.type} ${relativeDay(m.date).toLowerCase()} · $name',
        message: late
            ? 'Intervention « ${m.type} » prévue le ${formatShortDate(m.date)}, toujours non démarrée.'
            : 'Intervention « ${m.type} » planifiée le ${formatShortDate(m.date)}.',
        date: m.date,
        route: Routes.maintenanceDetail,
        args: IdArgs(m.id!),
      ));
    }

    // 7. Incidents waiting to be handled
    final iRows = await db.rawQuery('''
      SELECT i.id, i.type, i.date, i.lieu, v.marque || ' ' || v.modele AS vehicle_name
      FROM incidents i JOIN vehicles v ON v.id = i.vehicle_id
      WHERE i.statut = 'en_attente'
      ORDER BY i.date ASC
    ''');
    for (final row in iRows) {
      final date = DateTime.parse(row['date'] as String);
      final age = BusinessRules.lateDays(date);
      final escalate = age >= BusinessRules.incidentEscalationDays;
      final type = row['type'] == 'accident' ? 'Accident' : 'Panne';
      out.add(AppAlert(
        id: 'incident-${row['id']}-${escalate ? 'late' : 'new'}',
        level: escalate ? AlertLevel.urgent : AlertLevel.today,
        icon: row['type'] == 'accident'
            ? Icons.car_crash_rounded
            : Icons.car_repair_rounded,
        color: escalate ? AppColors.danger : AppColors.warning,
        title: '$type à prendre en charge · ${row['vehicle_name']}',
        message: age == 0
            ? 'Déclaré aujourd\'hui à ${row['lieu']}.'
            : 'Déclaré il y a $age j à ${row['lieu']}, toujours en attente.',
        date: date,
        route: Routes.incidentDetail,
        args: IdArgs(row['id'] as int),
      ));
    }

    out.sort((a, b) {
      final l = a.level.index.compareTo(b.level.index);
      return l != 0 ? l : a.date.compareTo(b.date);
    });
    return out;
  }
}
