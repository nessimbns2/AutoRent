import 'enums.dart';

/// One status change of an incident (from `incident_history`).
/// [fromStatus] is null for the declaration itself.
class IncidentHistoryEntry {
  final int incidentId;
  final IncidentStatus? fromStatus;
  final IncidentStatus toStatus;
  final String? userName;
  final DateTime changedAt;

  const IncidentHistoryEntry({
    required this.incidentId,
    required this.fromStatus,
    required this.toStatus,
    required this.userName,
    required this.changedAt,
  });

  bool get isDeclaration => fromStatus == null;

  factory IncidentHistoryEntry.fromMap(Map<String, Object?> m) =>
      IncidentHistoryEntry(
        incidentId: m['incident_id'] as int,
        fromStatus: m['from_statut'] == null
            ? null
            : IncidentStatus.fromValue(m['from_statut'] as String),
        toStatus: IncidentStatus.fromValue(m['to_statut'] as String),
        userName: m['user_name'] as String?,
        changedAt: DateTime.parse(m['changed_at'] as String),
      );
}

/// A history entry with enough context to be shown in a global activity feed.
class IncidentActivity {
  final IncidentHistoryEntry entry;
  final IncidentType type;
  final String vehicleLabel;

  const IncidentActivity({
    required this.entry,
    required this.type,
    required this.vehicleLabel,
  });
}

class VehicleIncidentCount {
  final int vehicleId;
  final String vehicleLabel;
  final int count;
  const VehicleIncidentCount({
    required this.vehicleId,
    required this.vehicleLabel,
    required this.count,
  });
}

/// Aggregated figures for the incidents follow-up dashboard.
class IncidentStats {
  final Map<IncidentStatus, int> byStatus;
  final Map<IncidentType, int> byType;

  /// Incidents declared during the last 30 days.
  final int last30Days;

  /// Average time between declaration and resolution, for resolved incidents
  /// (null when none is resolved).
  final Duration? averageResolution;

  final List<VehicleIncidentCount> topVehicles;
  final List<IncidentActivity> recentActivity;

  const IncidentStats({
    required this.byStatus,
    required this.byType,
    required this.last30Days,
    required this.averageResolution,
    required this.topVehicles,
    required this.recentActivity,
  });

  int get total => byStatus.values.fold(0, (a, b) => a + b);

  /// Share of incidents resolved, 0..1 (0 when there is no incident).
  double get resolutionRate =>
      total == 0 ? 0 : (byStatus[IncidentStatus.resolu] ?? 0) / total;

  /// Incidents still to handle (waiting + in progress).
  int get open =>
      (byStatus[IncidentStatus.enAttente] ?? 0) +
      (byStatus[IncidentStatus.enCours] ?? 0);
}
