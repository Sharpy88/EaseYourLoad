import 'models.dart';

/// The household content that is shared between invited users.
///
/// Notification preferences are deliberately excluded: reminders stay local to
/// each device.
///
/// Every collection is serialized as a map keyed by item id rather than a list,
/// so two people editing at the same time touch different keys and neither
/// edit is lost. Ids sort chronologically, which is what restores list order.
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

  /// Names of the item collections inside the shared payload, in the order the
  /// app presents them.
  static const collections = [
    'shopping',
    'chores',
    'events',
    'gifts',
    'dates',
    'expenses',
  ];

  static const budgetField = 'budget';

  final List<CheckItem> shopping;
  final List<CheckItem> chores;
  final List<CalendarEvent> events;
  final List<Idea> gifts;
  final List<Idea> dates;
  final List<Expense> expenses;
  final double budget;

  Map<String, dynamic> toJson() => {
    'shopping': _keyed(shopping, (item) => item.id, checkItemToJson),
    'chores': _keyed(chores, (item) => item.id, checkItemToJson),
    'events': _keyed(events, (item) => item.id, eventToJson),
    'gifts': _keyed(gifts, (item) => item.id, ideaToJson),
    'dates': _keyed(dates, (item) => item.id, ideaToJson),
    'expenses': _keyed(expenses, (item) => item.id, expenseToJson),
    budgetField: budget,
  };

  static SharedData fromJson(
    Map<String, dynamic> json, {
    double fallbackBudget = 500,
  }) => SharedData(
    shopping: _items(json['shopping'], checkItemFromJson),
    chores: _items(json['chores'], checkItemFromJson),
    events: _items(json['events'], eventFromJson),
    gifts: _items(json['gifts'], ideaFromJson),
    dates: _items(json['dates'], ideaFromJson),
    expenses: _items(json['expenses'], expenseFromJson),
    budget: (json[budgetField] as num?)?.toDouble() ?? fallbackBudget,
  );

  static Map<String, dynamic> _keyed<T>(
    List<T> items,
    String Function(T) id,
    Map<String, dynamic> Function(T) encode,
  ) => {for (final item in items) id(item): encode(item)};

  /// Reads one collection, accepting both the keyed map written by this version
  /// and the plain list written by older builds and older device caches.
  static List<T> _items<T>(
    dynamic value,
    T Function(Map<String, dynamic>) parse,
  ) {
    if (value is Map) {
      final keys = value.keys.whereType<String>().toList()..sort();
      return [
        for (final key in keys)
          if (value[key] is Map)
            parse({
              'id': key,
              ...Map<String, dynamic>.from(value[key] as Map),
            }),
      ];
    }
    if (value is List) {
      return value
          .whereType<Map>()
          .map((entry) => parse(Map<String, dynamic>.from(entry)))
          .toList();
    }
    return <T>[];
  }
}
