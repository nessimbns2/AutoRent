/// "Trop de tentatives. Réessayez dans 1 min 20 s."
String lockMessage(Duration d) {
  var total = d.inSeconds;
  if (d.inMilliseconds % 1000 > 0) total++;
  if (total < 1) total = 1;
  final m = total ~/ 60;
  final s = total % 60;
  final t = m > 0 ? (s > 0 ? '$m min $s s' : '$m min') : '$s s';
  return 'Trop de tentatives. Réessayez dans $t.';
}
