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

  test('collections are keyed by item id so writes address single items', () {
    final milk = CheckItem('Milk');
    final json = SharedData(
      shopping: [milk],
      chores: const [],
      events: const [],
      gifts: const [],
      dates: const [],
      expenses: const [],
      budget: 500,
    ).toJson();

    expect(json['shopping'], isA<Map<String, dynamic>>());
    expect((json['shopping'] as Map).keys.single, milk.id);
  });

  test('items keep their id and creation order across a round-trip', () {
    final first = CheckItem('Bread');
    final second = CheckItem('Jam');
    final data = SharedData(
      shopping: [first, second],
      chores: const [],
      events: const [],
      gifts: const [],
      dates: const [],
      expenses: const [],
      budget: 500,
    );

    // Keys arrive from Firestore in arbitrary order; ids restore the order.
    final shuffled = {
      for (final key in (data.toJson()['shopping'] as Map).keys.toList().reversed)
        key: (data.toJson()['shopping'] as Map)[key],
    };
    final restored = SharedData.fromJson({...data.toJson(), 'shopping': shuffled});

    expect(restored.shopping.map((item) => item.id), [first.id, second.id]);
    expect(restored.shopping.map((item) => item.title), ['Bread', 'Jam']);
  });

  test('lists written by older builds still load', () {
    final restored = SharedData.fromJson({
      'shopping': [
        {'title': 'Milk', 'done': true, 'note': '', 'dueAt': null},
      ],
      'budget': 300,
    });

    expect(restored.shopping.single.title, 'Milk');
    expect(restored.shopping.single.done, isTrue);
    expect(restored.shopping.single.id, isNotEmpty);
    expect(restored.budget, 300);
  });
}
