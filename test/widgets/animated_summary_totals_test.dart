import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movement_quest/models/training_summary.dart';
import 'package:movement_quest/widgets/animated_summary_totals.dart';

void main() {
  TrainingSummary summary(int repetitions) {
    return TrainingSummary(
      generatedAtUtc: DateTime.utc(2026, 10, 25, 12),
      completedSessions: 1,
      unfinishedSessions: 0,
      totalSets: 2,
      totalRepetitions: repetitions,
    );
  }

  Future<void> showTotals(
    WidgetTester tester, {
    required TrainingSummary value,
    bool isSaved = false,
    bool reduceMotion = false,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: reduceMotion),
          child: Scaffold(
            body: AnimatedSummaryTotals(summary: value, isSaved: isSaved),
          ),
        ),
      ),
    );
  }

  testWidgets('The explicit animation finishes with visible totals', (
    tester,
  ) async {
    await showTotals(tester, value: summary(18));

    await tester.pumpAndSettle();

    final fade = tester.widget<FadeTransition>(
      find.descendant(
        of: find.byType(AnimatedSummaryTotals),
        matching: find.byType(FadeTransition),
      ),
    );

    expect(fade.opacity.value, 1);
    expect(find.text('Generated snapshot'), findsOneWidget);
    expect(find.text('Total repetitions: 18'), findsOneWidget);
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('Replacing a snapshot updates its label and totals', (
    tester,
  ) async {
    await showTotals(tester, value: summary(18));
    await tester.pumpAndSettle();

    await showTotals(tester, value: summary(30), isSaved: true);
    await tester.pumpAndSettle();

    expect(find.text('Saved file snapshot'), findsOneWidget);
    expect(find.text('Total repetitions: 30'), findsOneWidget);
    expect(find.text('Total repetitions: 18'), findsNothing);
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('Reduced motion displays totals without the entrance animation', (
    tester,
  ) async {
    await showTotals(tester, value: summary(18), reduceMotion: true);

    final fade = tester.widget<FadeTransition>(
      find.descendant(
        of: find.byType(AnimatedSummaryTotals),
        matching: find.byType(FadeTransition),
      ),
    );

    expect(fade.opacity.value, 1);
    expect(find.text('Total repetitions: 18'), findsOneWidget);
  });

  testWidgets('Removing the widget disposes its active controller', (
    tester,
  ) async {
    await showTotals(tester, value: summary(18));
    await tester.pump(const Duration(milliseconds: 100));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(tester.hasRunningAnimations, isFalse);
  });
}
