import '../../models/pricing_settings.dart';
import '../utils/formatters.dart';

enum PriceLineKind { base, season, weekend, discount }

/// One line of a price breakdown ("Haute saison +20 % · 3 j  +51 DT").
class PriceLine {
  final PriceLineKind kind;
  final String label;
  final String detail;
  final double amount;
  const PriceLine(this.kind, this.label, this.detail, this.amount);
}

/// Price of a rental computed with the agency pricing grid.
class PriceQuote {
  final double dailyRate;
  final int days;
  final int seasonDays;
  final int weekendDays;
  final double seasonPercent;
  final double weekendPercent;
  final double discountPercent;
  final int? discountFromDays;

  /// days × daily rate, before any rule.
  final double baseTotal;
  final double seasonSurcharge;
  final double weekendSurcharge;

  /// Long-stay discount amount (positive number, subtracted from the total).
  final double discount;
  final double total;

  const PriceQuote({
    required this.dailyRate,
    required this.days,
    required this.seasonDays,
    required this.weekendDays,
    required this.seasonPercent,
    required this.weekendPercent,
    required this.discountPercent,
    required this.discountFromDays,
    required this.baseTotal,
    required this.seasonSurcharge,
    required this.weekendSurcharge,
    required this.discount,
    required this.total,
  });

  double get subtotal => baseTotal + seasonSurcharge + weekendSurcharge;

  /// Average price per day actually charged (used for extensions and late
  /// fees, like any contract).
  double get averageDailyRate => total / days;

  /// Whether at least one rule changed the price.
  bool get isAdjusted =>
      seasonSurcharge != 0 || weekendSurcharge != 0 || discount != 0;

  /// Breakdown shown in the rental form and the pricing simulator.
  List<PriceLine> get lines => [
        PriceLine(PriceLineKind.base, 'Tarif de base',
            '$days j × ${formatMoneyShort(dailyRate)}', baseTotal),
        if (seasonSurcharge != 0)
          PriceLine(PriceLineKind.season,
              'Haute saison ${PricingService.signedPercent(seasonPercent)}',
              '$seasonDays j', seasonSurcharge),
        if (weekendSurcharge != 0)
          PriceLine(PriceLineKind.weekend,
              'Week-end ${PricingService.signedPercent(weekendPercent)}',
              '$weekendDays j (sam. et dim.)', weekendSurcharge),
        if (discount != 0)
          PriceLine(PriceLineKind.discount,
              'Remise longue durée ${PricingService.signedPercent(-discountPercent)}',
              'dès $discountFromDays jours', -discount),
      ];

  /// Short label for the bottom bar, e.g. "8 j · remise −10 %".
  String get summary {
    final parts = <String>['$days j'];
    if (discount != 0) {
      parts.add('remise ${PricingService.signedPercent(-discountPercent)}');
    }
    if (seasonSurcharge != 0) parts.add('saison');
    if (weekendSurcharge != 0) parts.add('week-end');
    if (parts.length == 1) return '$days j × ${dailyRate.toStringAsFixed(0)} DT';
    return parts.join(' · ');
  }
}

/// Pure price computation (no database access, easy to unit test).
///
/// For each rental day (from the start date up to the day before the
/// return), the base daily rate is increased by the high-season and the
/// weekend percentages (each computed on the base rate, so they add up).
/// The long-stay discount is then applied to that subtotal: only the
/// highest tier reached counts. Amounts are rounded to the millime.
class PricingService {
  PricingService._();

  static DateTime _utcDay(DateTime d) => DateTime.utc(d.year, d.month, d.day);

  /// Number of billed days (nights), at least 1. Computed in UTC so a
  /// daylight-saving change never loses a day.
  static int rentalDays(DateTime start, DateTime end) {
    final d = _utcDay(end).difference(_utcDay(start)).inDays;
    return d < 1 ? 1 : d;
  }

  static double roundMillimes(double v) => (v * 1000).roundToDouble() / 1000;

  /// "+20 %", "−10 %", "+12,5 %".
  static String signedPercent(double v) {
    final sign = v < 0 ? '−' : '+';
    return '$sign${percent(v.abs())} %';
  }

  /// "20", "12,5".
  static String percent(double v) => v == v.roundToDouble()
      ? v.toStringAsFixed(0)
      : v.toStringAsFixed(1).replaceAll('.', ',');

  static PriceQuote quote({
    required double dailyRate,
    required DateTime start,
    required DateTime end,
    PricingSettings settings = PricingSettings.defaults,
  }) {
    final days = rentalDays(start, end);
    var seasonDays = 0;
    var weekendDays = 0;
    for (var i = 0; i < days; i++) {
      final d = DateTime(start.year, start.month, start.day + i);
      if (settings.seasonEnabled &&
          settings.seasonPercent != 0 &&
          settings.isHighSeason(d)) {
        seasonDays++;
      }
      if (settings.weekendEnabled &&
          settings.weekendPercent != 0 &&
          PricingSettings.isWeekend(d)) {
        weekendDays++;
      }
    }

    final baseTotal = roundMillimes(days * dailyRate);
    final seasonSurcharge = roundMillimes(
        seasonDays * dailyRate * settings.seasonPercent / 100);
    final weekendSurcharge = roundMillimes(
        weekendDays * dailyRate * settings.weekendPercent / 100);
    final subtotal = baseTotal + seasonSurcharge + weekendSurcharge;

    final tier = settings.longStayTierFor(days);
    final discountPercent = tier?.$2 ?? 0;
    final discount = roundMillimes(subtotal * discountPercent / 100);
    final fromDays = tier?.$1;

    return PriceQuote(
      dailyRate: dailyRate,
      days: days,
      seasonDays: seasonDays,
      weekendDays: weekendDays,
      seasonPercent: settings.seasonPercent,
      weekendPercent: settings.weekendPercent,
      discountPercent: discountPercent,
      discountFromDays: fromDays,
      baseTotal: baseTotal,
      seasonSurcharge: seasonSurcharge,
      weekendSurcharge: weekendSurcharge,
      discount: discount,
      total: roundMillimes(subtotal - discount),
    );
  }
}
