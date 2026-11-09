import 'package:intl/intl.dart';

final _dateFormatter = DateFormat('dd/MM/yyyy');
final _isoDateFormatter = DateFormat('yyyy-MM-dd');
final _moneyFormatter = NumberFormat('#,##0.000');
final _compactMoney = NumberFormat('#,##0');

const _months = [
  'janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin',
  'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.',
];
const _monthsLong = [
  'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
  'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre',
];
const _weekdays = [
  'lundi', 'mardi', 'mercredi', 'jeudi', 'vendredi', 'samedi', 'dimanche',
];

String formatDate(DateTime d) => _dateFormatter.format(d);
String toIsoDate(DateTime d) => _isoDateFormatter.format(d);
DateTime fromIsoDate(String s) => DateTime.parse(s);

/// e.g. "12 nov."
String formatDayMonth(DateTime d) => '${d.day} ${_months[d.month - 1]}';

/// e.g. "12 nov. 2026"
String formatShortDate(DateTime d) =>
    '${d.day} ${_months[d.month - 1]} ${d.year}';

/// e.g. "dimanche 8 novembre"
String formatLongDay(DateTime d) =>
    '${_weekdays[d.weekday - 1]} ${d.day} ${_monthsLong[d.month - 1]}';

/// Short month label for charts, e.g. "nov."
String monthLabel(int month) => _months[month - 1];

/// Formats a TND amount: e.g. 1,120.000 DT
String formatMoney(double v) => '${_moneyFormatter.format(v)} DT';

/// Compact amount without millimes: e.g. 1,120 DT
String formatMoneyShort(double v) => '${_compactMoney.format(v)} DT';

/// "Aujourd'hui", "Demain", "Hier", "Dans 3 j", "Il y a 5 j"
String relativeDay(DateTime d) {
  final today = DateTime.now();
  final a = DateTime(today.year, today.month, today.day);
  final b = DateTime(d.year, d.month, d.day);
  final diff = b.difference(a).inDays;
  if (diff == 0) return "Aujourd'hui";
  if (diff == 1) return 'Demain';
  if (diff == -1) return 'Hier';
  if (diff > 1) return 'Dans $diff j';
  return 'Il y a ${-diff} j';
}

/// "à l'instant", "il y a 5 min", "il y a 2 h", or a date.
String timeAgo(DateTime d) {
  final diff = DateTime.now().difference(d);
  if (diff.inSeconds < 45) return "à l'instant";
  if (diff.inMinutes < 60) return 'il y a ${diff.inMinutes} min';
  if (diff.inHours < 24) return 'il y a ${diff.inHours} h';
  return 'le ${formatDate(d)} à ${DateFormat('HH:mm').format(d)}';
}
