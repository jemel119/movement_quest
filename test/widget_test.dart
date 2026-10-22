import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movement_quest/main.dart';

void main() {
  testWidgets('Navigation opens each main section', (tester) async {
    await tester.pumpWidget(const MovementQuestApp());

    expect(find.text('Movement Quest'), findsOneWidget);
    expect(find.text('Your workout plans will appear here.'), findsOneWidget);

    await tester.tap(find.widgetWithText(NavigationDestination, 'History'));
    await tester.pumpAndSettle();

    expect(find.text('Training History'), findsOneWidget);
    expect(
      find.text('Your training history will appear here.'),
      findsOneWidget,
    );

    await tester.tap(find.widgetWithText(NavigationDestination, 'Settings'));
    await tester.pumpAndSettle();

    expect(find.text('Your preferences will appear here.'), findsOneWidget);

    await tester.tap(find.widgetWithText(NavigationDestination, 'Workouts'));
    await tester.pumpAndSettle();

    expect(find.text('Movement Quest'), findsOneWidget);
    expect(find.text('Your workout plans will appear here.'), findsOneWidget);
  });
}
