import 'package:flutter_test/flutter_test.dart';
import 'package:mental_load_app/models.dart';
import 'package:mental_load_app/shared_data.dart';

void main() {
  test('shared data round-trips through the payload sent to Firestore', () {
    final data = SharedData(
      shopping: [CheckItem('Milk')],
      chores: [
        CheckItem(
          'Take bins out',
          done: true,
          note: 'Kerb by 7am',
          dueAt: DateTime(2026, 8, 1, 7),
          notificationId: 42,
        ),
      ],
      events: [CalendarEvent('Swimming', DateTime(2026, 8, 3))],
      gifts: [Idea('Sam', 'Cookbook')],
      dates: [Idea('Little Red', 'Seasonal menu')],
      expenses: [Expense('Groceries', 142.5, 'Food')],
      budget: 620,
    );

    final restored = SharedData.fromJson(data.toJson());

    expect(restored.shopping.single.title, 'Milk');
    expect(restored.chores.single.done, isTrue);
    expect(restored.chores.single.dueAt, DateTime(2026, 8, 1, 7));
    expect(restored.chores.single.notificationId, 42);
    expect(restored.events.single.date, DateTime(2026, 8, 3));
    expect(restored.gifts.single.detail, 'Cookbook');
    expect(restored.dates.single.title, 'Little Red');
    expect(restored.expenses.single.amount, 142.5);
    expect(restored.budget, 620);
  });

  test('missing sections fall back to empty lists and the given budget', () {
    final restored = SharedData.fromJson(const {}, fallbackBudget: 500);

    expect(restored.shopping, isEmpty);
    expect(restored.expenses, isEmpty);
    expect(restored.budget, 500);
  });
}
