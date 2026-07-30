import 'models.dart';

/// The household content that is shared between invited users.
///
/// Notification preferences are deliberately excluded: reminders stay local to
/// each device.
class SharedData {
  SharedData({
    required this.shopping,
    required this.chores,
    required this.events,
    required this.gifts,
    required this.dates,
    required this.expenses,
    required this.budget,
  });

  final List<CheckItem> shopping;
  final List<CheckItem> chores;
  final List<CalendarEvent> events;
  final List<Idea> gifts;
  final List<Idea> dates;
  final List<Expense> expenses;
  final double budget;

  Map<String, dynamic> toJson() => {
    'shopping': shopping.map(checkItemToJson).toList(),
    'chores': chores.map(checkItemToJson).toList(),
    'events': events.map(eventToJson).toList(),
    'gifts': gifts.map(ideaToJson).toList(),
    'dates': dates.map(ideaToJson).toList(),
    'expenses': expenses.map(expenseToJson).toList(),
    'budget': budget,
  };

  static SharedData fromJson(Map<String, dynamic> json, {double fallbackBudget = 500}) =>
      SharedData(
        shopping: _list(json['shopping'], checkItemFromJson),
        chores: _list(json['chores'], checkItemFromJson),
        events: _list(json['events'], eventFromJson),
        gifts: _list(json['gifts'], ideaFromJson),
        dates: _list(json['dates'], ideaFromJson),
        expenses: _list(json['expenses'], expenseFromJson),
        budget: (json['budget'] as num?)?.toDouble() ?? fallbackBudget,
      );

  static List<T> _list<T>(
    dynamic value,
    T Function(Map<String, dynamic>) parse,
  ) {
    if (value is! List) return <T>[];
    return value
        .whereType<Map>()
        .map((entry) => parse(Map<String, dynamic>.from(entry)))
        .toList();
  }
}
