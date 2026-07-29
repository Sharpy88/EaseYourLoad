// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mental_load_app/main.dart';

void main() {
  testWidgets('shows the dashboard', (WidgetTester tester) async {
    await tester.pumpWidget(const MentalLoadApp());

    expect(find.byType(DashboardPage), findsOneWidget);
  });

  testWidgets('tapping budget from the dashboard triggers the budget action', (
    WidgetTester tester,
  ) async {
    var budgetTapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DashboardPage(
            events: const [],
            shopping: const [],
            chores: const [],
            expenses: const [],
            budget: 0,
            onTab: (_) {},
            onBudgetTap: () => budgetTapped = true,
          ),
        ),
      ),
    );

    final dashboard = tester.widget<DashboardPage>(find.byType(DashboardPage));
    dashboard.onBudgetTap();
    await tester.pump();

    expect(budgetTapped, isTrue);
  });

  testWidgets('tapping the daily check-in tile does not crash', (
    WidgetTester tester,
  ) async {
    final preferences = NotificationPreferences()
      ..enabled = true
      ..dailyCheckIn = true;

    await tester.pumpWidget(
      MaterialApp(
        home: NotificationSettingsPage(
          preferences: preferences,
          onChanged: () {},
        ),
      ),
    );

    expect(find.byType(ListTile), findsWidgets);
    await tester.tap(find.byType(ListTile).last);
    await tester.pump();

    expect(find.byType(NotificationSettingsPage), findsOneWidget);
  });

  test('notification preferences round-trip reminder schedules', () {
    final preferences = NotificationPreferences()
      ..enabled = true
      ..householdReminders = true
      ..shoppingReminders = true
      ..householdReminderCount = 2
      ..householdReminderTimes = [
        const TimeOfDay(hour: 7, minute: 30),
        const TimeOfDay(hour: 20, minute: 0),
      ]
      ..shoppingReminderCount = 1
      ..shoppingReminderTimes = [const TimeOfDay(hour: 18, minute: 45)];

    final restored = NotificationPreferences.fromJson(preferences.toJson());

    expect(restored.householdReminderCount, 2);
    expect(restored.householdReminderTimes.length, 2);
    expect(restored.householdReminderTimes.first.hour, 7);
    expect(restored.shoppingReminderTimes.first.hour, 18);
  });
}
