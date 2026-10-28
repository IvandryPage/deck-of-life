import 'package:flutter_test/flutter_test.dart';

import 'package:deck_of_life/app/app.dart';

void main() {
  testWidgets('startup errors are shown to the user', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const StartupErrorApp(message: 'Database unavailable'),
    );

    expect(find.text('Aplikasi tidak bisa dimulai'), findsOneWidget);
    expect(find.text('Database unavailable'), findsOneWidget);
  });
}
