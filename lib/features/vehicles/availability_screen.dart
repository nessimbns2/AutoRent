import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/shared_widgets.dart';
import '../../models/enums.dart';
import '../../repositories/rental_repository.dart';

/// Month view of the days a vehicle is booked (reserved or rented).
class AvailabilityScreen extends StatefulWidget {
  final int vehicleId;
  const AvailabilityScreen({super.key, required this.vehicleId});

  @override
  State<AvailabilityScreen> createState() => _AvailabilityScreenState();
}

class _AvailabilityScreenState extends State<AvailabilityScreen> {
  late final Future<Set<String>> _booked = _load();
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  Future<Set<String>> _load() async {
    final views = await RentalRepository().getViewsByVehicle(widget.vehicleId);
    final days = <String>{};
    for (final v in views) {
      final r = v.rental;
      if (r.status != RentalStatus.reservee &&
          r.status != RentalStatus.enCours) {
        continue;
      }
      for (var d = r.startDate;
          !d.isAfter(r.endDate);
          d = d.add(const Duration(days: 1))) {
        days.add(toIsoDate(d));
      }
    }
    return days;
  }

  void _shift(int by) =>
      setState(() => _month = DateTime(_month.year, _month.month + by));

  @override
  Widget build(BuildContext context) {
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final offset = _month.weekday - 1; // Monday first
    final today = toIsoDate(DateTime.now());
    return Scaffold(
      appBar: AppBar(title: const Text('Disponibilités')),
      body: FutureBuilder<Set<String>>(
        future: _booked,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const LoadingView();
          }
          final booked = snap.data ?? {};
          return ListView(padding: const EdgeInsets.all(20), children: [
            Row(children: [
              IconButton(
                  onPressed: () => _shift(-1),
                  icon: const Icon(Icons.chevron_left_rounded)),
              Expanded(
                child: Text('${monthLabel(_month.month)} ${_month.year}',
                    textAlign: TextAlign.center,
                    style: context.text.titleMedium),
              ),
              IconButton(
                  onPressed: () => _shift(1),
                  icon: const Icon(Icons.chevron_right_rounded)),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              for (final d in const ['L', 'M', 'M', 'J', 'V', 'S', 'D'])
                Expanded(
                    child:
                        Center(child: Text(d, style: context.text.labelSmall))),
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
                for (var day = 1; day <= daysInMonth; day++)
                  _Day(
                    day: day,
                    booked: booked.contains(
                        toIsoDate(DateTime(_month.year, _month.month, day))),
                    isToday: toIsoDate(
                            DateTime(_month.year, _month.month, day)) ==
                        today,
                  ),
              ],
            ),
            const SizedBox(height: 20),
            const Row(children: [
              _Legend(color: AppColors.danger, label: 'Réservé / loué'),
              SizedBox(width: 20),
              _Legend(color: AppColors.success, label: 'Libre'),
            ]),
          ]);
        },
      ),
    );
  }
}

class _Day extends StatelessWidget {
  final int day;
  final bool booked;
  final bool isToday;
  const _Day({required this.day, required this.booked, required this.isToday});

  @override
  Widget build(BuildContext context) {
    final color = booked ? AppColors.danger : AppColors.success;
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: isToday ? Border.all(color: color, width: 2) : null,
      ),
      child: Text('$day',
          style: TextStyle(color: color, fontWeight: FontWeight.w600)),
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
