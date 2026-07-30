import 'dart:math';

final _random = Random();

/// Identifier for a shared item.
///
/// The microsecond prefix is zero padded so that sorting ids as strings puts
/// items back in the order they were created, whichever device created them.
String newId() {
  final stamp = DateTime.now().microsecondsSinceEpoch.toString().padLeft(16, '0');
  final suffix = _random.nextInt(1 << 20).toRadixString(36).padLeft(4, '0');
  return '$stamp-$suffix';
}

class CheckItem {
  CheckItem(
    this.title, {
    String? id,
    this.done = false,
    this.note = '',
    this.dueAt,
    this.notificationId,
  }) : id = id ?? newId();
  final String id;
  String title;
  bool done;
  String note;
  DateTime? dueAt;
  int? notificationId;
}

class CalendarEvent {
  CalendarEvent(this.title, this.date, {String? id}) : id = id ?? newId();
  final String id;
  String title;
  DateTime date;
}

class Idea {
  Idea(this.title, this.detail, {String? id}) : id = id ?? newId();
  final String id;
  String title;
  String detail;
}

class Expense {
  Expense(this.title, this.amount, this.category, {String? id})
    : id = id ?? newId();
  final String id;
  String title;
  double amount;
  String category;
}

Map<String, dynamic> checkItemToJson(CheckItem item) => {
  'id': item.id,
  'title': item.title,
  'done': item.done,
  'note': item.note,
  'dueAt': item.dueAt?.toIso8601String(),
  'notificationId': item.notificationId,
};

CheckItem checkItemFromJson(Map<String, dynamic> json) => CheckItem(
  json['title'] as String,
  id: json['id'] as String?,
  done: json['done'] as bool? ?? false,
  note: json['note'] as String? ?? '',
  dueAt: json['dueAt'] == null ? null : DateTime.parse(json['dueAt'] as String),
  notificationId: json['notificationId'] as int?,
);

Map<String, dynamic> eventToJson(CalendarEvent event) => {
  'id': event.id,
  'title': event.title,
  'date': event.date.toIso8601String(),
};

CalendarEvent eventFromJson(Map<String, dynamic> json) => CalendarEvent(
  json['title'] as String,
  DateTime.parse(json['date'] as String),
  id: json['id'] as String?,
);

Map<String, dynamic> ideaToJson(Idea idea) => {
  'id': idea.id,
  'title': idea.title,
  'detail': idea.detail,
};

Idea ideaFromJson(Map<String, dynamic> json) => Idea(
  json['title'] as String,
  json['detail'] as String,
  id: json['id'] as String?,
);

Map<String, dynamic> expenseToJson(Expense expense) => {
  'id': expense.id,
  'title': expense.title,
  'amount': expense.amount,
  'category': expense.category,
};

Expense expenseFromJson(Map<String, dynamic> json) => Expense(
  json['title'] as String,
  (json['amount'] as num).toDouble(),
  json['category'] as String,
  id: json['id'] as String?,
);
