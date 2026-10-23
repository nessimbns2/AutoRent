import 'package:intl/intl.dart';

final _dateFormatter = DateFormat('dd/MM/yyyy');
final _isoDateFormatter = DateFormat('yyyy-MM-dd');

String formatDate(DateTime d) => _dateFormatter.format(d);
String toIsoDate(DateTime d) => _isoDateFormatter.format(d);
DateTime fromIsoDate(String s) => DateTime.parse(s);

/// Formats a TND amount: e.g. 120.000 DT
String formatMoney(double v) =>
    '${NumberFormat('#,##0.000').format(v)} DT';
