import 'package:app_aila/features/auth/screens/welcome_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('welcome screen renders its AILA wordmark', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 940));

    await tester.pumpWidget(
      const MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: WelcomeScreen(),
        ),
      ),
    );

    expect(find.byType(WelcomeScreen), findsOneWidget);
    expect(find.text('AILA'), findsOneWidget);

    addTearDown(() => tester.binding.setSurfaceSize(null));
  });
}
