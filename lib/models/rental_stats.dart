import '../repositories/dashboard_repository.dart' show MonthRevenue;
import 'enums.dart';

/// One line of a ranking (vehicle, client or agent).
class RankedItem {
  final String label;
  final int count;
  final double revenue;
  const RankedItem(this.label, this.count, this.revenue);
}

/// Figures for the admin analytics page of the rentals module.
/// Revenue never includes cancelled contracts.
class RentalStats {
  final int total;
  final Map<RentalStatus, int> byStatus;
  final double revenue;
  final double revenueThisMonth;
  final double averageAmount;
  final double averageDays;
  final int overdue;

  /// Oldest to newest, the last 6 months.
  final List<MonthRevenue> monthly;
  final List<RankedItem> topVehicles;
  final List<RankedItem> topClients;
  final List<RankedItem> byAgent;

  const RentalStats({
    required this.total,
    required this.byStatus,
    required this.revenue,
    required this.revenueThisMonth,
    required this.averageAmount,
    required this.averageDays,
    required this.overdue,
    required this.monthly,
    required this.topVehicles,
    required this.topClients,
    required this.byAgent,
  });

  int count(RentalStatus s) => byStatus[s] ?? 0;

  /// Share of contracts that were cancelled (0 to 1).
  double get cancellationRate =>
      total == 0 ? 0 : count(RentalStatus.annulee) / total;
}
