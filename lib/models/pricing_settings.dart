/// Agency pricing grid, stored as the single row of `pricing_settings`.
///
/// - Long-stay discount: −[tier1Percent] % from [tier1Days] days,
///   −[tier2Percent] % from [tier2Days] days (only the highest tier applies).
/// - High season: +[seasonPercent] % for every rental day between
///   [seasonStartMonth]/[seasonStartDay] and [seasonEndMonth]/[seasonEndDay]
///   (the period may span the new year, e.g. 15 Dec → 15 Jan).
/// - Weekend: +[weekendPercent] % for every Saturday and Sunday (a negative
///   value turns it into a weekend discount).
class PricingSettings {
  final bool longStayEnabled;
  final int tier1Days;
  final double tier1Percent;
  final int tier2Days;
  final double tier2Percent;

  final bool seasonEnabled;
  final int seasonStartMonth;
  final int seasonStartDay;
  final int seasonEndMonth;
  final int seasonEndDay;
  final double seasonPercent;

  final bool weekendEnabled;
  final double weekendPercent;

  final DateTime? updatedAt;

  const PricingSettings({
    this.longStayEnabled = true,
    this.tier1Days = 7,
    this.tier1Percent = 10,
    this.tier2Days = 30,
    this.tier2Percent = 25,
    this.seasonEnabled = true,
    this.seasonStartMonth = 7,
    this.seasonStartDay = 1,
    this.seasonEndMonth = 8,
    this.seasonEndDay = 31,
    this.seasonPercent = 20,
    this.weekendEnabled = true,
    this.weekendPercent = 10,
    this.updatedAt,
  });

  /// Agency defaults (also the values of a fresh database).
  static const defaults = PricingSettings();

  /// Grid with every rule switched off: price = days × daily rate.
  static const flat = PricingSettings(
    longStayEnabled: false,
    seasonEnabled: false,
    weekendEnabled: false,
  );

  bool get anyEnabled => longStayEnabled || seasonEnabled || weekendEnabled;

  static int _key(int month, int day) => month * 100 + day;

  /// Whether [d] falls in the high-season period (bounds included).
  bool isHighSeason(DateTime d) {
    final k = _key(d.month, d.day);
    final s = _key(seasonStartMonth, seasonStartDay);
    final e = _key(seasonEndMonth, seasonEndDay);
    return s <= e ? (k >= s && k <= e) : (k >= s || k <= e);
  }

  /// Saturday and Sunday (the Tunisian weekend).
  static bool isWeekend(DateTime d) =>
      d.weekday == DateTime.saturday || d.weekday == DateTime.sunday;

  /// Long-stay tier reached by a rental of [days] days, as
  /// (minimum days, discount in %), or null when none applies.
  (int, double)? longStayTierFor(int days) {
    if (!longStayEnabled) return null;
    if (days >= tier2Days && tier2Percent > 0) return (tier2Days, tier2Percent);
    if (days >= tier1Days && tier1Percent > 0) return (tier1Days, tier1Percent);
    return null;
  }

  /// Long-stay discount (in %) for a rental of [days] days, 0 when none.
  double longStayPercentFor(int days) => longStayTierFor(days)?.$2 ?? 0;

  static String _md(int month, int day) =>
      '${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';

  static (int, int) _parseMd(String? s, (int, int) fallback) {
    final parts = (s ?? '').split('-');
    if (parts.length != 2) return fallback;
    final m = int.tryParse(parts[0]);
    final d = int.tryParse(parts[1]);
    if (m == null || d == null || m < 1 || m > 12 || d < 1 || d > 31) {
      return fallback;
    }
    return (m, d);
  }

  factory PricingSettings.fromMap(Map<String, Object?> m) {
    double pct(String col, double fallback) =>
        (m[col] as num?)?.toDouble() ?? fallback;
    final (sm, sd) = _parseMd(m['saison_debut'] as String?, (7, 1));
    final (em, ed) = _parseMd(m['saison_fin'] as String?, (8, 31));
    return PricingSettings(
      longStayEnabled: (m['longue_duree'] as int? ?? 1) == 1,
      tier1Days: m['palier1_jours'] as int? ?? 7,
      tier1Percent: pct('palier1_remise', 10),
      tier2Days: m['palier2_jours'] as int? ?? 30,
      tier2Percent: pct('palier2_remise', 25),
      seasonEnabled: (m['haute_saison'] as int? ?? 1) == 1,
      seasonStartMonth: sm,
      seasonStartDay: sd,
      seasonEndMonth: em,
      seasonEndDay: ed,
      seasonPercent: pct('saison_majoration', 20),
      weekendEnabled: (m['week_end'] as int? ?? 1) == 1,
      weekendPercent: pct('week_end_majoration', 10),
      updatedAt: m['updated_at'] == null
          ? null
          : DateTime.tryParse(m['updated_at'] as String),
    );
  }

  Map<String, Object?> toMap() => {
        'id': 1,
        'longue_duree': longStayEnabled ? 1 : 0,
        'palier1_jours': tier1Days,
        'palier1_remise': tier1Percent,
        'palier2_jours': tier2Days,
        'palier2_remise': tier2Percent,
        'haute_saison': seasonEnabled ? 1 : 0,
        'saison_debut': _md(seasonStartMonth, seasonStartDay),
        'saison_fin': _md(seasonEndMonth, seasonEndDay),
        'saison_majoration': seasonPercent,
        'week_end': weekendEnabled ? 1 : 0,
        'week_end_majoration': weekendPercent,
        'updated_at': (updatedAt ?? DateTime.now()).toIso8601String(),
      };

  PricingSettings copyWith({
    bool? longStayEnabled,
    int? tier1Days,
    double? tier1Percent,
    int? tier2Days,
    double? tier2Percent,
    bool? seasonEnabled,
    int? seasonStartMonth,
    int? seasonStartDay,
    int? seasonEndMonth,
    int? seasonEndDay,
    double? seasonPercent,
    bool? weekendEnabled,
    double? weekendPercent,
    DateTime? updatedAt,
  }) =>
      PricingSettings(
        longStayEnabled: longStayEnabled ?? this.longStayEnabled,
        tier1Days: tier1Days ?? this.tier1Days,
        tier1Percent: tier1Percent ?? this.tier1Percent,
        tier2Days: tier2Days ?? this.tier2Days,
        tier2Percent: tier2Percent ?? this.tier2Percent,
        seasonEnabled: seasonEnabled ?? this.seasonEnabled,
        seasonStartMonth: seasonStartMonth ?? this.seasonStartMonth,
        seasonStartDay: seasonStartDay ?? this.seasonStartDay,
        seasonEndMonth: seasonEndMonth ?? this.seasonEndMonth,
        seasonEndDay: seasonEndDay ?? this.seasonEndDay,
        seasonPercent: seasonPercent ?? this.seasonPercent,
        weekendEnabled: weekendEnabled ?? this.weekendEnabled,
        weekendPercent: weekendPercent ?? this.weekendPercent,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}
