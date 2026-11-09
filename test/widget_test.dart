import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:autorent/app/theme.dart';
import 'package:autorent/core/utils/formatters.dart';
import 'package:autorent/core/widgets/shared_widgets.dart';
import 'package:autorent/core/widgets/status_chips.dart';
import 'package:autorent/models/enums.dart';
import 'package:autorent/models/rental.dart';

Widget _wrap(Widget child, {ThemeData? theme}) => MaterialApp(
      theme: theme ?? buildTheme(),
      home: Scaffold(body: child),
    );

void main() {
  group('Theme', () {
    test('light and dark themes build with the AutoRent palette', () {
      final light = buildTheme();
      final dark = buildDarkTheme();
      expect(light.colorScheme.primary, AppColors.brand);
      expect(dark.brightness, Brightness.dark);
      expect(light.extension<AppPalette>(), isNotNull);
      expect(dark.extension<AppPalette>(), isNotNull);
    });
  });

  group('UI kit', () {
    testWidgets('EmptyState shows its message and action', (tester) async {
      var tapped = false;
      await tester.pumpWidget(_wrap(EmptyState(
        title: 'Aucun véhicule',
        message: 'Ajoutez votre premier véhicule.',
        actionLabel: 'Ajouter',
        onAction: () => tapped = true,
      )));
      expect(find.text('Aucun véhicule'), findsOneWidget);
      await tester.tap(find.text('Ajouter'));
      expect(tapped, isTrue);
    });

    testWidgets('PillTabs reports the selected value', (tester) async {
      RentalStatus? picked;
      await tester.pumpWidget(_wrap(PillTabs<RentalStatus>(
        selected: RentalStatus.enCours,
        onChanged: (s) => picked = s,
        tabs: [
          for (final s in RentalStatus.values) PillTab(s, s.label, count: 1),
        ],
      )));
      await tester.tap(find.text('Réservée'));
      expect(picked, RentalStatus.reservee);
    });

    testWidgets('UI kit renders in dark mode', (tester) async {
      await tester.pumpWidget(_wrap(
        const Column(children: [
          StatusChip(label: 'Disponible', color: AppColors.success),
          InfoBanner(icon: Icons.info, text: 'Info'),
          CarImage(seed: 3, width: 80, height: 60),
        ]),
        theme: buildDarkTheme(),
      ));
      expect(find.text('Disponible'), findsOneWidget);
      expect(find.byIcon(Icons.directions_car_filled_rounded), findsOneWidget);
    });
  });

  group('Business helpers', () {
    Rental rental(RentalStatus s, DateTime end) => Rental(
          clientId: 1,
          vehicleId: 1,
          startDate: end.subtract(const Duration(days: 3)),
          endDate: end,
          totalPrice: 300,
          status: s,
          createdAt: DateTime.now(),
        );

    test('a running rental past its end date is overdue', () {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      expect(isRentalOverdue(rental(RentalStatus.enCours, yesterday)), isTrue);
      expect(isRentalOverdue(rental(RentalStatus.terminee, yesterday)), isFalse);
      expect(
          isRentalOverdue(rental(RentalStatus.enCours,
              DateTime.now().add(const Duration(days: 2)))),
          isFalse);
    });

    test('French date helpers', () {
      final today = DateTime.now();
      expect(relativeDay(today), "Aujourd'hui");
      expect(relativeDay(today.add(const Duration(days: 1))), 'Demain');
      expect(formatShortDate(DateTime(2026, 11, 8)), '8 nov. 2026');
      expect(formatMoneyShort(1250), '1,250 DT');
    });
  });
}
