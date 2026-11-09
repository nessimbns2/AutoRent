import '../../models/rental.dart';

/// Agency business rules shared by the notifications, the rental screens
/// and the tests.
class BusinessRules {
  BusinessRules._();

  /// Late days are billed at the contract daily rate increased by 20 %.
  static const lateFeeMultiplier = 1.2;

  /// Reservations starting within this many days trigger a reminder.
  static const reservationReminderDays = 2;

  /// Planned maintenance within this many days triggers a reminder.
  static const maintenanceReminderDays = 3;

  /// Pending incidents older than this are escalated to "urgent".
  static const incidentEscalationDays = 2;

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Number of full days between the planned return date and [today].
  static int lateDays(DateTime endDate, [DateTime? today]) {
    final diff =
        _day(today ?? DateTime.now()).difference(_day(endDate)).inDays;
    return diff > 0 ? diff : 0;
  }

  /// Daily rate actually agreed in the contract.
  static double dailyRate(Rental r) => r.totalPrice / r.days;

  /// Late fee owed if the vehicle comes back [today].
  static double lateFee(Rental r, [DateTime? today]) =>
      lateDays(r.endDate, today) * dailyRate(r) * lateFeeMultiplier;

  /// Total price after extending the contract up to [newEnd]
  /// (same daily rate as the original contract).
  static double extendedTotal(Rental r, DateTime newEnd) {
    final days = _day(newEnd).difference(_day(r.startDate)).inDays;
    return (days < 1 ? 1 : days) * dailyRate(r);
  }
}
