import '../../models/rental.dart';
import '../../models/vehicle_document.dart';

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

  /// Documents expiring within this many days are flagged "bientôt expiré".
  static const documentWarningDays = 30;

  /// Documents expiring within this many days trigger a same-day alert.
  static const documentUrgentDays = 7;

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Days from [today] until [date] (negative when in the past).
  static int daysUntil(DateTime date, [DateTime? today]) =>
      _day(date).difference(_day(today ?? DateTime.now())).inDays;

  /// Validity of an administrative document expiring on [expiresOn].
  static DocumentStatus documentStatus(DateTime? expiresOn,
      [DateTime? today]) {
    if (expiresOn == null) return DocumentStatus.missing;
    final d = daysUntil(expiresOn, today);
    if (d < 0) return DocumentStatus.expired;
    if (d <= documentWarningDays) return DocumentStatus.expiringSoon;
    return DocumentStatus.valid;
  }

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
