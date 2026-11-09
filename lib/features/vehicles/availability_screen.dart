import 'package:flutter/material.dart';

import '../../core/widgets/shared_widgets.dart';
import '../../repositories/rental_repository.dart';
import '../rentals/widgets/booking_calendar.dart';

/// Read-only month view of the days a vehicle is booked.
class AvailabilityScreen extends StatelessWidget {
  final int vehicleId;
  const AvailabilityScreen({super.key, required this.vehicleId});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Disponibilités')),
        body: FutureBuilder<Set<String>>(
          future: RentalRepository().bookedDays(vehicleId),
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const LoadingView();
            }
            return ListView(padding: const EdgeInsets.all(20), children: [
              BookingCalendar(
                booked: snap.data ?? {},
                firstDay: DateUtils.dateOnly(DateTime.now()),
              ),
            ]);
          },
        ),
      );
}
