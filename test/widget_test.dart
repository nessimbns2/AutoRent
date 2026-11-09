import 'package:flutter_test/flutter_test.dart';
import 'package:autorent/app/app.dart';

void main() {
  testWidgets('AutoRentApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const AutoRentApp());
    expect(find.byType(AutoRentApp), findsOneWidget);
    // Advance past SplashScreen timer
    await tester.pump(const Duration(milliseconds: 1500));
  });
}
