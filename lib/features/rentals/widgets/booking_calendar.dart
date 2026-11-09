import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/ui_helpers.dart';

/// Month grid showing a vehicle's booked days. With [onChanged] it also lets
/// the user pick a range: tap the start day, then the return day. Booked days
/// and ranges that cross them are refused. Without it, it is read-only.
class BookingCalendar extends StatefulWidget {
  /// Booked days as `yyyy-MM-dd`.
  final Set<String> booked;
  final DateTime? start;
  final DateTime? end;
  final DateTime firstDay;
  final void Function(DateTime start, DateTime end)? onChanged;

  const BookingCalendar({
    super.key,
    required this.booked,
    required this.firstDay,
    this.start,
    this.end,
    this.onChanged,
  });

  @override
  State<BookingCalendar> createState() => _BookingCalendarState();
}

class _BookingCalendarState extends State<BookingCalendar> {
  late DateTime _month = DateTime((widget.start ?? DateTime.now()).year,
      (widget.start ?? DateTime.now()).month);
  DateTime? _anchor; // first tap, waiting for the return day

  bool _isBooked(DateTime d) => widget.booked.contains(toIsoDate(d));

  void _shift(int by) =>
      setState(() => _month = DateTime(_month.year, _month.month + by));

  void _tap(DateTime day) {
    if (widget.onChanged == null) return;
    final anchor = _anchor;
    if (anchor == null || !day.isAfter(anchor)) {
      setState(() => _anchor = day);
      return;
    }
    for (var d = anchor; !d.isAfter(day); d = d.add(const Duration(days: 1))) {
      if (_isBooked(d)) {
        showSnack(context, 'Cette période contient des jours déjà réservés');
        return;
      }
    }
    setState(() => _anchor = null);
    widget.onChanged!(anchor, day);
  }

  @override
  Widget build(BuildContext context) {
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final offset = DateTime(_month.year, _month.month).weekday - 1; // Mon first
    final today = DateUtils.dateOnly(DateTime.now());
    final start = _anchor ?? widget.start;
    final end = _anchor != null ? null : widget.end;

    return Column(children: [
      Row(children: [
        IconButton(
            onPressed: () => _shift(-1),
            icon: const Icon(Icons.chevron_left_rounded)),
        Expanded(
          child: Text('${monthLabel(_month.month)} ${_month.year}',
              textAlign: TextAlign.center, style: context.text.titleMedium),
        ),
        IconButton(
            onPressed: () => _shift(1),
            icon: const Icon(Icons.chevron_right_rounded)),
      ]),
      Row(children: [
        for (final d in const ['L', 'M', 'M', 'J', 'V', 'S', 'D'])
          Expanded(child: Center(child: Text(d, style: context.text.labelSmall))),
      ]),
      const SizedBox(height: 8),
      GridView.count(
        crossAxisCount: 7,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 6,
        crossAxisSpacing: 6,
        children: [
          for (var i = 0; i < offset; i++) const SizedBox(),
          for (var n = 1; n <= daysInMonth; n++)
            _cell(DateTime(_month.year, _month.month, n), today, start, end),
        ],
      ),
      const SizedBox(height: 12),
      const Row(children: [
        _Legend(color: AppColors.danger, label: 'Réservé / loué'),
        SizedBox(width: 16),
        _Legend(color: AppColors.success, label: 'Libre'),
        SizedBox(width: 16),
        _Legend(color: AppColors.info, label: 'Sélection'),
      ]),
    ]);
  }

  Widget _cell(DateTime day, DateTime today, DateTime? start, DateTime? end) {
    final booked = _isBooked(day);
    final past = day.isBefore(widget.firstDay);
    final isEdge = (start != null && DateUtils.isSameDay(day, start)) ||
        (end != null && DateUtils.isSameDay(day, end));
    final inRange = start != null &&
        end != null &&
        day.isAfter(start) &&
        day.isBefore(end);
    final color = booked
        ? AppColors.danger
        : (isEdge || inRange)
            ? AppColors.info
            : AppColors.success;
    final disabled = past && !booked;
    return GestureDetector(
      onTap: booked || past ? null : () => _tap(day),
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: disabled
              ? Colors.transparent
              : isEdge && !booked
                  ? color
                  : color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
          border: DateUtils.isSameDay(day, today)
              ? Border.all(color: color, width: 2)
              : null,
        ),
        child: Text('${day.day}',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: disabled
                  ? context.palette.muted
                  : isEdge && !booked
                      ? Colors.white
                      : color,
            )),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  const _Legend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) => Row(children: [
        Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(4))),
        const SizedBox(width: 6),
        Text(label, style: context.text.bodySmall),
      ]);
}
