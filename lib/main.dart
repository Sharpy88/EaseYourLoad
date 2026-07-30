import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'household_sync.dart';
import 'models.dart';
import 'share_page.dart';
import 'shared_data.dart';

final notifications = NotificationService();
final householdSync = HouseholdSync();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await notifications.initialize();
  unawaited(householdSync.initialize());
  runApp(const MentalLoadApp());
}

class MentalLoadApp extends StatelessWidget {
  const MentalLoadApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Ease Your Mind',
    theme: ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xfff4efe9),
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xff3c4f3f),
        primary: const Color(0xff3c4f3f),
        secondary: const Color(0xffb2865b),
        surface: const Color(0xfffcfbf8),
        onSurface: const Color(0xff232724),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xfff4efe9),
        elevation: 0,
        foregroundColor: Color(0xff2f322c),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        color: const Color(0xfffcfbf8),
        shadowColor: const Color(0x14000000),
      ),
      textTheme: ThemeData.light().textTheme.copyWith(
        headlineMedium: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 28,
          letterSpacing: -0.5,
          color: Color(0xff232724),
        ),
        titleLarge: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 20,
          letterSpacing: -0.4,
          color: Color(0xff232724),
        ),
        bodyMedium: const TextStyle(
          fontSize: 14,
          color: Color(0xff5f655f),
          height: 1.45,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: const Color(0xfff4efe9),
        elevation: 0,
        indicatorColor: const Color(0xff3c4f3f).withValues(alpha: 0.14),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          return const TextStyle(fontWeight: FontWeight.w600);
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? const Color(0xff3c4f3f) : const Color(0xff6c706b),
          );
        }),
      ),
    ),
    home: const HomeShell(),
  );
}

class NotificationPreferences {
  NotificationPreferences();

  bool enabled = false;
  bool dailyCheckIn = true;
  bool householdReminders = true;
  bool calendarReminders = true;
  bool shoppingReminders = true;
  int householdReminderCount = 1;
  int calendarReminderCount = 1;
  int shoppingReminderCount = 1;
  List<TimeOfDay> householdReminderTimes = [const TimeOfDay(hour: 9, minute: 0)];
  List<TimeOfDay> calendarReminderTimes = [const TimeOfDay(hour: 9, minute: 0)];
  List<TimeOfDay> shoppingReminderTimes = [const TimeOfDay(hour: 18, minute: 0)];
  TimeOfDay checkInTime = const TimeOfDay(hour: 19, minute: 0);

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'dailyCheckIn': dailyCheckIn,
    'householdReminders': householdReminders,
    'calendarReminders': calendarReminders,
    'shoppingReminders': shoppingReminders,
    'householdReminderCount': householdReminderCount,
    'calendarReminderCount': calendarReminderCount,
    'shoppingReminderCount': shoppingReminderCount,
    'householdReminderTimes': householdReminderTimes
        .map((time) => '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}')
        .toList(),
    'calendarReminderTimes': calendarReminderTimes
        .map((time) => '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}')
        .toList(),
    'shoppingReminderTimes': shoppingReminderTimes
        .map((time) => '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}')
        .toList(),
    'hour': checkInTime.hour,
    'minute': checkInTime.minute,
  };

  factory NotificationPreferences.fromJson(Map<String, dynamic> json) {
    final prefs = NotificationPreferences();
    prefs.enabled = json['enabled'] as bool? ?? false;
    prefs.dailyCheckIn = json['dailyCheckIn'] as bool? ?? true;
    prefs.householdReminders = json['householdReminders'] as bool? ?? true;
    prefs.calendarReminders = json['calendarReminders'] as bool? ?? true;
    prefs.shoppingReminders = json['shoppingReminders'] as bool? ?? true;
    prefs.householdReminderCount = json['householdReminderCount'] as int? ?? 1;
    prefs.calendarReminderCount = json['calendarReminderCount'] as int? ?? 1;
    prefs.shoppingReminderCount = json['shoppingReminderCount'] as int? ?? 1;
    prefs.householdReminderTimes = _timesFromJson(json['householdReminderTimes']);
    prefs.calendarReminderTimes = _timesFromJson(json['calendarReminderTimes']);
    prefs.shoppingReminderTimes = _timesFromJson(json['shoppingReminderTimes']);
    prefs.checkInTime = TimeOfDay(
      hour: json['hour'] as int? ?? 19,
      minute: json['minute'] as int? ?? 0,
    );
    return prefs;
  }

  static List<TimeOfDay> _timesFromJson(dynamic value) {
    if (value is! List) return [const TimeOfDay(hour: 9, minute: 0)];
    return value.map((entry) {
      if (entry is String) {
        final parts = entry.split(':');
        if (parts.length == 2) {
          return TimeOfDay(
            hour: int.parse(parts[0]),
            minute: int.parse(parts[1]),
          );
        }
      }
      return const TimeOfDay(hour: 9, minute: 0);
    }).toList();
  }
}

class AppStorage {
  static const _key = 'ease_your_load_data_v1';

  Future<Map<String, dynamic>?> load() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_key);
    if (raw == null) return null;
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  Future<void> save({
    required SharedData data,
    required NotificationPreferences notifications,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _key,
      jsonEncode({...data.toJson(), 'notifications': notifications.toJson()}),
    );
  }
}

class NotificationService {
  static const _dailyCheckInId = 7001;
  static const _householdReminderBaseId = 8001;
  static const _calendarReminderBaseId = 8101;
  static const _shoppingReminderBaseId = 8201;
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

Future<void> initialize() async {
  if (!Platform.isAndroid && !Platform.isIOS) return;
  tz.initializeTimeZones();
  final zone = await FlutterTimezone.getLocalTimezone();
  tz.setLocalLocation(tz.getLocation(zone.identifier));
  const settings = InitializationSettings(
    android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    iOS: DarwinInitializationSettings(
      requestAlertPermission: false, // we'll ask explicitly via requestPermission()
      requestBadgePermission: false,
      requestSoundPermission: false,
    ),
  );
  await _plugin.initialize(settings: settings);
  _ready = true;
}

Future<bool> requestPermission() async {
  if (!_ready) return false;
  if (Platform.isIOS) {
    return await _plugin
            .resolvePlatformSpecificImplementation
              IOSFlutterLocalNotificationsPlugin
            >()
            ?.requestPermissions(alert: true, badge: true, sound: true) ??
        false;
  }
  return await _plugin
          .resolvePlatformSpecificImplementation
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission() ??
      false;
}

  Future<void> showTest() async {
    if (!_ready) return;
    await _plugin.show(
      id: 7000,
      title: 'Ease Your Mind',
      body: 'Your reminders are ready to help.',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'home_reminders',
          'Home reminders',
          channelDescription: 'Reminders for household tasks and plans',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  }

  Future<void> syncPreferences(NotificationPreferences preferences) async {
    if (!_ready) return;
    if (!preferences.enabled) {
      await cancelDailyCheckIn();
      await cancelCategoryReminders(_householdReminderBaseId);
      await cancelCategoryReminders(_calendarReminderBaseId);
      await cancelCategoryReminders(_shoppingReminderBaseId);
      return;
    }
    if (preferences.dailyCheckIn) {
      await scheduleDailyCheckIn(preferences.checkInTime);
    } else {
      await cancelDailyCheckIn();
    }
    if (preferences.householdReminders) {
      await scheduleCategoryReminders(
        baseId: _householdReminderBaseId,
        count: preferences.householdReminderCount,
        times: preferences.householdReminderTimes,
        title: 'Household reminder',
        body: 'A gentle nudge for your household plans.',
      );
    } else {
      await cancelCategoryReminders(_householdReminderBaseId);
    }
    if (preferences.calendarReminders) {
      await scheduleCategoryReminders(
        baseId: _calendarReminderBaseId,
        count: preferences.calendarReminderCount,
        times: preferences.calendarReminderTimes,
        title: 'Calendar reminder',
        body: 'Time to review your calendar plans.',
      );
    } else {
      await cancelCategoryReminders(_calendarReminderBaseId);
    }
    if (preferences.shoppingReminders) {
      await scheduleCategoryReminders(
        baseId: _shoppingReminderBaseId,
        count: preferences.shoppingReminderCount,
        times: preferences.shoppingReminderTimes,
        title: 'Shopping reminder',
        body: 'Time for a quick check of your shopping list.',
      );
    } else {
      await cancelCategoryReminders(_shoppingReminderBaseId);
    }
  }

  Future<void> scheduleDailyCheckIn(TimeOfDay time) async {
    if (!_ready) return;
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    await _plugin.zonedSchedule(
      id: _dailyCheckInId,
      title: 'Ease Your Mind',
      body: 'Take a moment to check today’s household tasks.',
      scheduledDate: scheduled,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'home_reminders',
          'Home reminders',
          channelDescription: 'Reminders for household tasks and plans',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> cancelDailyCheckIn() => _plugin.cancel(id: _dailyCheckInId);

  Future<void> scheduleCategoryReminders({
    required int baseId,
    required int count,
    required List<TimeOfDay> times,
    required String title,
    required String body,
  }) async {
    if (!_ready) return;
    await cancelCategoryReminders(baseId);
    final limit = count.clamp(0, times.length);
    for (var index = 0; index < limit; index++) {
      final time = times[index];
      final now = tz.TZDateTime.now(tz.local);
      var scheduled = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        time.hour,
        time.minute,
      );
      if (!scheduled.isAfter(now)) {
        scheduled = scheduled.add(const Duration(days: 1));
      }
      await _plugin.zonedSchedule(
        id: baseId + index,
        title: 'Ease Your Mind',
        body: body,
        scheduledDate: scheduled,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'home_reminders',
            'Home reminders',
            channelDescription: 'Reminders for household tasks and plans',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    }
  }

  Future<void> cancelCategoryReminders(int baseId) async {
    for (var index = 0; index < 4; index++) {
      await _plugin.cancel(id: baseId + index);
    }
  }

  Future<void> scheduleTaskReminder(CheckItem task) async {
    if (!_ready || task.dueAt == null || task.notificationId == null) return;
    final reminderTime = task.dueAt!.subtract(const Duration(minutes: 30));
    if (!reminderTime.isAfter(DateTime.now())) return;
    await _plugin.zonedSchedule(
      id: task.notificationId!,
      title: 'Household task due soon',
      body: '${task.title} is due in 30 minutes.',
      scheduledDate: tz.TZDateTime.from(reminderTime, tz.local),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'home_reminders',
          'Home reminders',
          channelDescription: 'Reminders for household tasks and plans',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  Future<void> cancelTaskReminder(CheckItem task) async {
    if (_ready && task.notificationId != null) {
      await _plugin.cancel(id: task.notificationId!);
    }
  }
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;
  final _storage = AppStorage();
  final shopping = <CheckItem>[
    CheckItem('Milk'),
    CheckItem('Fruit for lunches'),
    CheckItem('Dishwasher tablets'),
  ];
  final chores = <CheckItem>[
    CheckItem('Pick up Mia from swimming', note: 'Today, 3:30 PM'),
    CheckItem('Book the dentist', note: 'This week'),
    CheckItem('Take bins out', done: true, note: 'Completed'),
  ];
  final events = <CalendarEvent>[
    CalendarEvent('Mia’s swimming', DateTime.now()),
    CalendarEvent('Date night', DateTime.now().add(const Duration(days: 3))),
  ];
  final gifts = <Idea>[Idea('Sam', 'Cookbook — birthday in August')];
  final dates = <Idea>[
    Idea('Dinner at Little Red', 'Try the new seasonal menu'),
  ];
  final expenses = <Expense>[
    Expense('Groceries', 142.50, 'Food'),
    Expense('Electricity', 98.00, 'Bills'),
  ];
  double budget = 500.00;
  final notificationPreferences = NotificationPreferences();

  @override
  void initState() {
    super.initState();
    householdSync.onRemoteData = _applyRemote;
    householdSync.addListener(_onSyncChanged);
    unawaited(_load());
  }

  @override
  void dispose() {
    householdSync.onRemoteData = null;
    householdSync.removeListener(_onSyncChanged);
    super.dispose();
  }

  void _onSyncChanged() {
    if (mounted) setState(() {});
  }

  SharedData _sharedData() => SharedData(
    shopping: shopping,
    chores: chores,
    events: events,
    gifts: gifts,
    dates: dates,
    expenses: expenses,
    budget: budget,
  );

  /// Replaces local content with what another household member shared.
  void _applyRemote(SharedData data) {
    if (!mounted) return;
    setState(() => _replaceAll(data));
    unawaited(_save());
    for (final task in chores.where((item) => !item.done && item.dueAt != null)) {
      unawaited(notifications.scheduleTaskReminder(task));
    }
  }

  void _replaceAll(SharedData data) {
    shopping
      ..clear()
      ..addAll(data.shopping);
    chores
      ..clear()
      ..addAll(data.chores);
    events
      ..clear()
      ..addAll(data.events);
    gifts
      ..clear()
      ..addAll(data.gifts);
    dates
      ..clear()
      ..addAll(data.dates);
    expenses
      ..clear()
      ..addAll(data.expenses);
    budget = data.budget;
  }

  Future<void> _load() async {
    final saved = await _storage.load();
    if (saved == null || !mounted) return;
    final settings = saved['notifications'] as Map<String, dynamic>?;
    setState(() {
      _replaceAll(SharedData.fromJson(saved, fallbackBudget: budget));
      if (settings != null) {
        notificationPreferences
          ..enabled = settings['enabled'] as bool? ?? false
          ..dailyCheckIn = settings['dailyCheckIn'] as bool? ?? true
          ..householdReminders = settings['householdReminders'] as bool? ?? true
          ..calendarReminders = settings['calendarReminders'] as bool? ?? true
          ..shoppingReminders = settings['shoppingReminders'] as bool? ?? true
          ..householdReminderCount =
              settings['householdReminderCount'] as int? ?? 1
          ..calendarReminderCount = settings['calendarReminderCount'] as int? ?? 1
          ..shoppingReminderCount = settings['shoppingReminderCount'] as int? ?? 1
          ..householdReminderTimes = NotificationPreferences._timesFromJson(
            settings['householdReminderTimes'],
          )
          ..calendarReminderTimes = NotificationPreferences._timesFromJson(
            settings['calendarReminderTimes'],
          )
          ..shoppingReminderTimes = NotificationPreferences._timesFromJson(
            settings['shoppingReminderTimes'],
          )
          ..checkInTime = TimeOfDay(
            hour: settings['hour'] as int? ?? 19,
            minute: settings['minute'] as int? ?? 0,
          );
      }
      unawaited(notifications.syncPreferences(notificationPreferences));
    });
  }

  Future<void> _save() => _storage.save(
    data: _sharedData(),
    notifications: notificationPreferences,
  );

  void _refresh() {
    setState(() {});
    unawaited(_save());
    householdSync.push(_sharedData());
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      DashboardPage(
        events: events,
        shopping: shopping,
        chores: chores,
        expenses: expenses,
        budget: budget,
        onTab: (i) => setState(() => _tab = i),
        onBudgetTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => BudgetPage(
              expenses: expenses,
              budget: budget,
              onChanged: _refresh,
              onBudget: (value) {
                budget = value;
                _refresh();
              },
            ),
          ),
        ),
      ),
      CalendarPage(events: events, onChanged: _refresh),
      ChecklistPage(
        title: 'Shopping',
        emptyText: 'Your shopping list is clear.',
        items: shopping,
        addLabel: 'Add item',
        onChanged: _refresh,
      ),
      ChecklistPage(
        title: 'Household',
        emptyText: 'No chores planned yet.',
        items: chores,
        addLabel: 'Add chore',
        isHousehold: true,
        notificationPreferences: notificationPreferences,
        onChanged: _refresh,
      ),
      MorePage(
        gifts: gifts,
        dates: dates,
        expenses: expenses,
        budget: budget,
        notificationPreferences: notificationPreferences,
        onChanged: _refresh,
        onBudget: (value) {
          budget = value;
          _refresh();
        },
        currentData: _sharedData,
      ),
    ];
    return Scaffold(
      body: SafeArea(child: pages[_tab]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (index) => setState(() => _tab = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.grid_view_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            label: 'Calendar',
          ),
          NavigationDestination(
            icon: Icon(Icons.shopping_basket_outlined),
            label: 'Shopping',
          ),
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            label: 'Household',
          ),
          NavigationDestination(
            icon: Icon(Icons.more_horiz_rounded),
            label: 'More',
          ),
        ],
      ),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class DashboardPage extends StatelessWidget {
  const DashboardPage({
    super.key,
    required this.events,
    required this.shopping,
    required this.chores,
    required this.expenses,
    required this.budget,
    required this.onTab,
    required this.onBudgetTap,
  });
  final List<CalendarEvent> events;
  final List<CheckItem> shopping, chores;
  final List<Expense> expenses;
  final double budget;
  final ValueChanged<int> onTab;
  final VoidCallback onBudgetTap;

  @override
  Widget build(BuildContext context) {
    final openChores = chores.where((item) => !item.done).length;
    final openShopping = shopping.where((item) => !item.done).length;
    final spent = expenses.fold(0.0, (total, item) => total + item.amount);
    final next = [...events]..sort((a, b) => a.date.compareTo(b.date));
    final nextPlans = next
        .take(3)
        .map(
          (event) => _InfoTile(
            title: event.title,
            subtitle: prettyDate(event.date),
            icon: Icons.calendar_today_outlined,
          ),
        )
        .toList();
    final unfinishedHouseholdTasks = chores
        .where((item) => !item.done)
        .toList();
    final urgentTasks = unfinishedHouseholdTasks
        .where(
          (item) => item.dueAt != null && item.dueAt!.isBefore(DateTime.now()),
        )
        .toList();
    final CheckItem? nextHouseholdTask = unfinishedHouseholdTasks.isEmpty
        ? null
        : unfinishedHouseholdTasks.first;
    final choresSummary = openChores == 1
        ? '1 household task still open'
        : '$openChores household tasks still open';
    final shoppingSummary = openShopping == 1
        ? '1 item is on the shopping list'
        : '$openShopping items are on the shopping list';
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
          decoration: BoxDecoration(
            color: const Color(0xfff8f3eb),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: const Color(0x143c4f3f)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 15,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                formatDateHeading(DateTime.now()),
                style: const TextStyle(
                  color: Color(0xff3c4f3f),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                timeGreeting(),
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 28,
                  letterSpacing: -0.6,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'A calm, clear view of what matters most today.',
                style: TextStyle(color: Color(0xff69736c), fontSize: 13),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        if (urgentTasks.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xffffe4e1),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xffd94d42)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Color(0xffb3261e)),
                    SizedBox(width: 8),
                    Text(
                      'Urgent',
                      style: TextStyle(
                        color: Color(0xffb3261e),
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                ...urgentTasks
                    .take(3)
                    .map(
                      (task) => Text(
                        '${task.title} — overdue ${overdueLabel(task.dueAt!)}',
                        style: const TextStyle(color: Color(0xff7d211c)),
                      ),
                    ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xff3c4f3f), Color(0xff536b5b)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [
              BoxShadow(
                color: Color(0x22000000),
                blurRadius: 18,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                choresSummary,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 12),
              if (nextHouseholdTask != null)
                Text(
                  'Next household task: ${nextHouseholdTask.title}',
                  style: const TextStyle(color: Color(0xffdce8dc)),
                ),
              if (nextHouseholdTask == null)
                const Text(
                  'Your household tasks are all caught up.',
                  style: TextStyle(color: Color(0xffdce8dc)),
                ),
              const SizedBox(height: 4),
              Text(
                shoppingSummary,
                style: const TextStyle(color: Color(0xffdce8dc)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const _SectionTitle('At a glance'),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 2,
          childAspectRatio: 0.95,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 6,
          crossAxisSpacing: 6,
          children: [
            _ActionCard(
              icon: Icons.shopping_basket_outlined,
              title: 'Shopping',
              detail: '$openShopping to buy',
              tint: const Color(0xffffead6),
              onTap: () => onTab(2),
            ),
            _ActionCard(
              icon: Icons.cleaning_services_outlined,
              title: 'Household',
              detail: '$openChores to do',
              tint: const Color(0xffdbe9dc),
              onTap: () => onTab(3),
            ),
            _ActionCard(
              icon: Icons.calendar_month_outlined,
              title: 'Calendar',
              detail: '${events.length} plans saved',
              tint: const Color(0xffeee0ed),
              onTap: () => onTab(1),
            ),
            _ActionCard(
              icon: Icons.account_balance_wallet_outlined,
              title: 'Budget',
              detail:
                  '\$${spent.toStringAsFixed(0)} / \$${budget.toStringAsFixed(0)}',
              tint: const Color(0xffdce8f4),
              onTap: onBudgetTap,
            ),
          ],
        ),
        const SizedBox(height: 25),
        const _SectionTitle('Next plans'),
        const SizedBox(height: 8),
        if (next.isEmpty)
          const _EmptyCard(message: 'Add an event to see it here.'),
        if (next.isNotEmpty) ...nextPlans,
      ],
    );
  }
}

class CalendarPage extends StatelessWidget {
  const CalendarPage({
    super.key,
    required this.events,
    required this.onChanged,
  });
  final List<CalendarEvent> events;
  final VoidCallback onChanged;
  @override
  Widget build(BuildContext context) {
    final ordered = [...events]..sort((a, b) => a.date.compareTo(b.date));
    return Scaffold(
      appBar: AppBar(title: const Text('Calendar')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => addEvent(context, events, onChanged),
        icon: const Icon(Icons.add),
        label: const Text('Add event'),
      ),
      body: ordered.isEmpty
          ? const _EmptyCard(message: 'No plans yet. Add the first one.')
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: ordered.length,
              itemBuilder: (context, index) {
                final event = ordered[index];
                return Dismissible(
                  key: ObjectKey(event),
                  direction: DismissDirection.endToStart,
                  onDismissed: (_) {
                    events.remove(event);
                    onChanged();
                  },
                  background: const _DeleteBackground(),
                  child: _InfoTile(
                    title: event.title,
                    subtitle: prettyDate(event.date),
                    icon: Icons.calendar_month_outlined,
                  ),
                );
              },
            ),
    );
  }
}

class ChecklistPage extends StatelessWidget {
  const ChecklistPage({
    super.key,
    required this.title,
    required this.emptyText,
    required this.items,
    required this.addLabel,
    this.isHousehold = false,
    this.notificationPreferences,
    required this.onChanged,
  });
  final String title, emptyText, addLabel;
  final List<CheckItem> items;
  final bool isHousehold;
  final NotificationPreferences? notificationPreferences;
  final VoidCallback onChanged;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title)),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: () => isHousehold
          ? addHouseholdTask(context, items, onChanged, notificationPreferences)
          : addCheckItem(context, items, onChanged, label: addLabel),
      icon: const Icon(Icons.add),
      label: Text(addLabel),
    ),
    body: items.isEmpty
        ? _EmptyCard(message: emptyText)
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              final overdue = isOverdue(item);
              final subtitle = isHousehold && item.dueAt != null
                  ? 'Due ${prettyDateTime(item.dueAt!)}${overdue ? ' — OVERDUE' : ''}'
                  : item.note;
              return Dismissible(
                key: ObjectKey(item),
                direction: DismissDirection.endToStart,
                onDismissed: (_) {
                  notifications.cancelTaskReminder(item);
                  items.remove(item);
                  onChanged();
                },
                background: const _DeleteBackground(),
                child: Card(
                  child: CheckboxListTile(
                    value: item.done,
                    onChanged: (value) {
                      item.done = value ?? false;
                      if (item.done) notifications.cancelTaskReminder(item);
                      onChanged();
                    },
                    title: Text(
                      item.title,
                      style: TextStyle(
                        color: overdue ? const Color(0xffb3261e) : null,
                        fontWeight: overdue ? FontWeight.w700 : null,
                        decoration: item.done
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                    subtitle: subtitle.isEmpty
                        ? null
                        : Text(
                            subtitle,
                            style: TextStyle(
                              color: overdue ? const Color(0xffb3261e) : null,
                            ),
                          ),
                  ),
                ),
              );
            },
          ),
  );
}

class MorePage extends StatelessWidget {
  const MorePage({
    super.key,
    required this.gifts,
    required this.dates,
    required this.expenses,
    required this.budget,
    required this.notificationPreferences,
    required this.onChanged,
    required this.onBudget,
    required this.currentData,
  });
  final List<Idea> gifts, dates;
  final List<Expense> expenses;
  final double budget;
  final NotificationPreferences notificationPreferences;
  final VoidCallback onChanged;
  final ValueChanged<double> onBudget;
  final SharedData Function() currentData;
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      Text(
        'More',
        style: Theme.of(
          context,
        ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 16),
      _MoreCard(
        icon: Icons.card_giftcard_outlined,
        title: 'Gift ideas',
        subtitle: '${gifts.length} ideas saved',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => IdeaPage(
              title: 'Gift ideas',
              items: gifts,
              prompt: 'Add gift idea',
              onChanged: onChanged,
            ),
          ),
        ),
      ),
      _MoreCard(
        icon: Icons.favorite_border,
        title: 'Date night plans',
        subtitle: '${dates.length} ideas saved',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => IdeaPage(
              title: 'Date night plans',
              items: dates,
              prompt: 'Add date plan',
              onChanged: onChanged,
            ),
          ),
        ),
      ),
      _MoreCard(
        icon: Icons.account_balance_wallet_outlined,
        title: 'Budget tracking',
        subtitle: 'Set a monthly limit and add spending',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => BudgetPage(
              expenses: expenses,
              budget: budget,
              onChanged: onChanged,
              onBudget: onBudget,
            ),
          ),
        ),
      ),
      _MoreCard(
        icon: Icons.notifications_none_rounded,
        title: 'Notifications',
        subtitle: notificationPreferences.enabled
            ? 'Reminders are on'
            : 'Reminders are off',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => NotificationSettingsPage(
              preferences: notificationPreferences,
              onChanged: onChanged,
            ),
          ),
        ),
      ),
      _MoreCard(
        icon: Icons.people_outline,
        title: 'Share with someone',
        subtitle: householdSync.isSharing
            ? 'Sharing live with code ${householdSync.inviteCode}'
            : 'Invite a partner to see the same lists',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                SharePage(sync: householdSync, currentData: currentData),
          ),
        ),
      ),
    ],
  );
}

class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({
    super.key,
    required this.preferences,
    required this.onChanged,
  });
  final NotificationPreferences preferences;
  final VoidCallback onChanged;
  @override
  State<NotificationSettingsPage> createState() =>
      _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> {
  bool get isAndroid => Platform.isAndroid || Platform.isIOS;

  Widget _buildReminderScheduleEditor({
    required String title,
    required String subtitle,
    required bool enabled,
    required int count,
    required List<TimeOfDay> times,
    required ValueChanged<int> onCountChanged,
    required ValueChanged<List<TimeOfDay>> onTimesChanged,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(title),
                    subtitle: Text(subtitle),
                  ),
                ),
                Switch(
                  value: enabled,
                  onChanged: widget.preferences.enabled
                      ? (value) {
                          setState(() {
                            if (title == 'Household reminders') {
                              widget.preferences.householdReminders = value;
                            } else if (title == 'Calendar reminders') {
                              widget.preferences.calendarReminders = value;
                            } else {
                              widget.preferences.shoppingReminders = value;
                            }
                          });
                          widget.onChanged();
                        }
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Text('Times per day:'),
                const SizedBox(width: 8),
                DropdownButton<int>(
                  value: count,
                  items: List.generate(4, (index) => index + 1)
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text('$value'),
                        ),
                      )
                      .toList(),
                  onChanged: widget.preferences.enabled
                      ? (value) {
                          if (value != null) {
                            onCountChanged(value);
                            setState(() {});
                          }
                        }
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...List.generate(count, (index) {
              final time = times[index % times.length];
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text('Time ${index + 1}'),
                    ),
                    TextButton(
                      onPressed: widget.preferences.enabled
                          ? () async {
                              final picked = await showTimePicker(
                                context: context,
                                initialTime: time,
                              );
                              if (picked != null) {
                                final updatedTimes = [...times];
                                updatedTimes[index] = picked;
                                onTimesChanged(updatedTimes);
                                setState(() {});
                              }
                            }
                          : null,
                      child: Text(time.format(context)),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Future<void> _setEnabled(bool enabled) async {
    if (enabled && isAndroid) {
      final granted = await notifications.requestPermission();
      if (!granted && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please allow notifications in Android settings.'),
          ),
        );
        return;
      }
    }
    setState(() => widget.preferences.enabled = enabled);
    widget.onChanged();
    await _syncNotifications();
  }

  Future<void> _syncNotifications() async {
    if (!isAndroid) return;
    await notifications.syncPreferences(widget.preferences);
  }

  Future<void> _syncDailyCheckIn() async {
    if (!isAndroid) return;
    if (widget.preferences.dailyCheckIn) {
      await notifications.scheduleDailyCheckIn(widget.preferences.checkInTime);
    } else {
      await notifications.cancelDailyCheckIn();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Notifications')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Choose the reminders that genuinely make home life easier.',
        ),
        if (!isAndroid)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Text(
              'Scheduled reminders are enabled when you run the Android app. Windows is useful for testing the app interface.',
              style: TextStyle(color: Color(0xff69736c)),
            ),
          ),
        const SizedBox(height: 12),
        Card(
          child: SwitchListTile(
            title: const Text('Notifications'),
            subtitle: const Text('Allow reminders from Ease Your Mind'),
            value: widget.preferences.enabled,
            onChanged: _setEnabled,
          ),
        ),
        const SizedBox(height: 16),
        const _SectionTitle('Reminder types'),
        Card(
          child: Column(
            children: [
              SwitchListTile(
                title: const Text('Daily home check-in'),
                subtitle: Text(
                  'A gentle daily prompt at ${widget.preferences.checkInTime.format(context)}',
                ),
                value: widget.preferences.dailyCheckIn,
                onChanged: widget.preferences.enabled
                    ? (value) async {
                        setState(() => widget.preferences.dailyCheckIn = value);
                        widget.onChanged();
                        await _syncNotifications();
                      }
                    : null,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _buildReminderScheduleEditor(
          title: 'Household reminders',
          subtitle: 'Choose how often household reminders should land each day',
          enabled: widget.preferences.householdReminders,
          count: widget.preferences.householdReminderCount,
          times: widget.preferences.householdReminderTimes,
          onCountChanged: (value) async {
            widget.preferences.householdReminderCount = value;
            if (widget.preferences.householdReminderTimes.length < value) {
              final extra = List<TimeOfDay>.generate(
                value - widget.preferences.householdReminderTimes.length,
                (index) => const TimeOfDay(hour: 9, minute: 0),
              );
              widget.preferences.householdReminderTimes = [
                ...widget.preferences.householdReminderTimes,
                ...extra,
              ];
            } else if (widget.preferences.householdReminderTimes.length > value) {
              widget.preferences.householdReminderTimes = widget
                  .preferences
                  .householdReminderTimes
                  .sublist(0, value);
            }
            widget.onChanged();
            await _syncNotifications();
          },
          onTimesChanged: (value) async {
            widget.preferences.householdReminderTimes = value;
            widget.onChanged();
            await _syncNotifications();
          },
        ),
        const SizedBox(height: 12),
        _buildReminderScheduleEditor(
          title: 'Calendar reminders',
          subtitle: 'Choose how often calendar reminders should land each day',
          enabled: widget.preferences.calendarReminders,
          count: widget.preferences.calendarReminderCount,
          times: widget.preferences.calendarReminderTimes,
          onCountChanged: (value) async {
            widget.preferences.calendarReminderCount = value;
            if (widget.preferences.calendarReminderTimes.length < value) {
              final extra = List<TimeOfDay>.generate(
                value - widget.preferences.calendarReminderTimes.length,
                (index) => const TimeOfDay(hour: 9, minute: 0),
              );
              widget.preferences.calendarReminderTimes = [
                ...widget.preferences.calendarReminderTimes,
                ...extra,
              ];
            } else if (widget.preferences.calendarReminderTimes.length > value) {
              widget.preferences.calendarReminderTimes = widget
                  .preferences
                  .calendarReminderTimes
                  .sublist(0, value);
            }
            widget.onChanged();
            await _syncNotifications();
          },
          onTimesChanged: (value) async {
            widget.preferences.calendarReminderTimes = value;
            widget.onChanged();
            await _syncNotifications();
          },
        ),
        const SizedBox(height: 12),
        _buildReminderScheduleEditor(
          title: 'Shopping reminders',
          subtitle: 'Choose how often shopping reminders should land each day',
          enabled: widget.preferences.shoppingReminders,
          count: widget.preferences.shoppingReminderCount,
          times: widget.preferences.shoppingReminderTimes,
          onCountChanged: (value) async {
            widget.preferences.shoppingReminderCount = value;
            if (widget.preferences.shoppingReminderTimes.length < value) {
              final extra = List<TimeOfDay>.generate(
                value - widget.preferences.shoppingReminderTimes.length,
                (index) => const TimeOfDay(hour: 18, minute: 0),
              );
              widget.preferences.shoppingReminderTimes = [
                ...widget.preferences.shoppingReminderTimes,
                ...extra,
              ];
            } else if (widget.preferences.shoppingReminderTimes.length > value) {
              widget.preferences.shoppingReminderTimes = widget
                  .preferences
                  .shoppingReminderTimes
                  .sublist(0, value);
            }
            widget.onChanged();
            await _syncNotifications();
          },
          onTimesChanged: (value) async {
            widget.preferences.shoppingReminderTimes = value;
            widget.onChanged();
            await _syncNotifications();
          },
        ),
        ListTile(
          enabled:
              widget.preferences.enabled && widget.preferences.dailyCheckIn,
          leading: const Icon(Icons.schedule_outlined),
          title: const Text('Daily check-in time'),
          subtitle: Text(widget.preferences.checkInTime.format(context)),
          trailing: const Icon(Icons.chevron_right),
          onTap: () async {
            final time = await showTimePicker(
              context: context,
              initialTime: widget.preferences.checkInTime,
            );
            if (time != null) {
              setState(() => widget.preferences.checkInTime = time);
              widget.onChanged();
              await _syncDailyCheckIn();
            }
          },
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: widget.preferences.enabled && isAndroid
              ? () => notifications.showTest()
              : null,
          icon: const Icon(Icons.notifications_active_outlined),
          label: const Text('Send a test notification'),
        ),
      ],
    ),
  );
}

class IdeaPage extends StatelessWidget {
  const IdeaPage({
    super.key,
    required this.title,
    required this.items,
    required this.prompt,
    required this.onChanged,
  });
  final String title, prompt;
  final List<Idea> items;
  final VoidCallback onChanged;
  @override
  Widget build(BuildContext context) => StatefulBuilder(
    builder: (context, setLocalState) => Scaffold(
      appBar: AppBar(title: Text(title)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await addIdea(context, items, onChanged, prompt);
          setLocalState(() {});
        },
        icon: const Icon(Icons.add),
        label: Text(prompt),
      ),
      body: items.isEmpty
          ? const _EmptyCard(message: 'Nothing saved yet.')
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final idea = items[index];
                return Dismissible(
                  key: ObjectKey(idea),
                  direction: DismissDirection.endToStart,
                  onDismissed: (_) {
                    items.remove(idea);
                    onChanged();
                    setLocalState(() {});
                  },
                  background: const _DeleteBackground(),
                  child: _InfoTile(
                    title: idea.title,
                    subtitle: idea.detail,
                    icon: Icons.lightbulb_outline,
                  ),
                );
              },
            ),
    ),
  );
}

class BudgetPage extends StatelessWidget {
  const BudgetPage({
    super.key,
    required this.expenses,
    required this.budget,
    required this.onChanged,
    required this.onBudget,
  });
  final List<Expense> expenses;
  final double budget;
  final VoidCallback onChanged;
  final ValueChanged<double> onBudget;
  @override
  Widget build(BuildContext context) {
    var localBudget = budget;
    return StatefulBuilder(
      builder: (context, setLocalState) {
        final spent = expenses.fold(0.0, (total, item) => total + item.amount);
        final progress = localBudget == 0
            ? 0.0
            : (spent / localBudget).clamp(0.0, 1.0).toDouble();
        return Scaffold(
          appBar: AppBar(title: const Text('Budget tracking')),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () async {
              await addExpense(context, expenses, onChanged);
              setLocalState(() {});
            },
            icon: const Icon(Icons.add),
            label: const Text('Add expense'),
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xffdce8f4),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '\$${spent.toStringAsFixed(2)} spent',
                      style: const TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'of \$${localBudget.toStringAsFixed(2)} monthly budget',
                    ),
                    const SizedBox(height: 14),
                    LinearProgressIndicator(value: progress),
                    const SizedBox(height: 10),
                    Text(
                      '\$${(localBudget - spent).toStringAsFixed(2)} remaining',
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: () async {
                  await editBudget(context, localBudget, (value) {
                    localBudget = value;
                    onBudget(value);
                  });
                  setLocalState(() {});
                },
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Change monthly budget'),
              ),
              const _SectionTitle('Spending'),
              const SizedBox(height: 8),
              ...expenses.map(
                (expense) => Dismissible(
                  key: ObjectKey(expense),
                  direction: DismissDirection.endToStart,
                  onDismissed: (_) {
                    expenses.remove(expense);
                    onChanged();
                    setLocalState(() {});
                  },
                  background: const _DeleteBackground(),
                  child: _InfoTile(
                    title: expense.title,
                    subtitle: expense.category,
                    icon: Icons.receipt_long_outlined,
                    trailing: '\$${expense.amount.toStringAsFixed(2)}',
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);
  final String title;
  @override
  Widget build(BuildContext context) => Text(
    title,
    style: Theme.of(
      context,
    ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
  );
}

// ignore: unused_element
class _MetricPill extends StatelessWidget {
  const _MetricPill({
    required this.label,
    required this.value,
    required this.tint,
  });
  final String label;
  final String value;
  final Color tint;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: tint,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Color(0xff69736c)),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.detail,
    required this.tint,
    required this.onTap,
  });
  final IconData icon;
  final String title, detail;
  final Color tint;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(18),
    child: Ink(
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x143c4f3f)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0f000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: const Color(0xfff8f3eb),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 16, color: const Color(0xff3c4f3f)),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  detail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 8, color: Color(0xff59645c)),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.trailing,
  });
  final String title, subtitle;
  final IconData icon;
  final String? trailing;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    child: Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        leading: CircleAvatar(
          radius: 22,
          backgroundColor: const Color(0xffefe7dc),
          child: Icon(icon, color: const Color(0xff3c4f3f)),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        trailing: trailing == null
            ? null
            : Text(
                trailing!,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
      ),
    ),
  );
}

class _MoreCard extends StatelessWidget {
  const _MoreCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String title, subtitle;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    child: Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
        leading: CircleAvatar(
          radius: 22,
          backgroundColor: const Color(0xffefe7dc),
          child: Icon(icon, color: const Color(0xff3c4f3f)),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
      ),
    ),
  );
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(20),
    child: Center(
      child: Text(message, style: const TextStyle(color: Color(0xff69736c))),
    ),
  );
}

class _DeleteBackground extends StatelessWidget {
  const _DeleteBackground();
  @override
  Widget build(BuildContext context) => Container(
    alignment: Alignment.centerRight,
    padding: const EdgeInsets.only(right: 22),
    margin: const EdgeInsets.only(bottom: 4),
    decoration: BoxDecoration(
      color: Colors.red.shade300,
      borderRadius: BorderRadius.circular(12),
    ),
    child: const Icon(Icons.delete_outline, color: Colors.white),
  );
}

String prettyDate(DateTime date) {
  const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  return '${names[date.weekday - 1]}, ${date.day}/${date.month}/${date.year}';
}

String formatDateHeading(DateTime date) {
  const weekdays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  final daySuffix = date.day == 1 || date.day == 21 || date.day == 31
      ? 'st'
      : date.day == 2 || date.day == 22
      ? 'nd'
      : date.day == 3 || date.day == 23
      ? 'rd'
      : 'th';
  return '${weekdays[date.weekday - 1]} ${date.day}$daySuffix ${months[date.month - 1]} ${date.year}';
}

String prettyDateTime(DateTime date) {
  final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
  final minute = date.minute.toString().padLeft(2, '0');
  final period = date.hour < 12 ? 'AM' : 'PM';
  return '${prettyDate(date)} at $hour:$minute $period';
}

bool isOverdue(CheckItem item) =>
    !item.done && item.dueAt != null && item.dueAt!.isBefore(DateTime.now());
String overdueLabel(DateTime dueAt) {
  final elapsed = DateTime.now().difference(dueAt);
  if (elapsed.inDays > 0) return '${elapsed.inDays}d ago';
  if (elapsed.inHours > 0) return '${elapsed.inHours}h ago';
  return '${elapsed.inMinutes.clamp(1, 59)}m ago';
}

String timeGreeting() {
  final hour = DateTime.now().hour;
  if (hour < 12) return 'Good morning';
  if (hour < 18) return 'Good afternoon';
  return 'Good evening';
}

Future<void> addCheckItem(
  BuildContext context,
  List<CheckItem> items,
  VoidCallback refresh, {
  required String label,
}) async {
  final result = await textPrompt(
    context,
    label,
    fields: const ['What needs doing?', 'Optional reminder'],
  );
  if (result != null && result[0].trim().isNotEmpty) {
    items.add(CheckItem(result[0].trim(), note: result[1].trim()));
    refresh();
  }
}

Future<void> addHouseholdTask(
  BuildContext context,
  List<CheckItem> items,
  VoidCallback refresh,
  NotificationPreferences? preferences,
) async {
  final result = await textPrompt(
    context,
    'Add household task',
    fields: const ['What needs doing?', 'Optional note'],
  );
  if (result == null || result.first.trim().isEmpty || !context.mounted) return;
  final date = await showDatePicker(
    context: context,
    initialDate: DateTime.now(),
    firstDate: DateTime.now().subtract(const Duration(days: 1)),
    lastDate: DateTime.now().add(const Duration(days: 3650)),
    helpText: 'When is this due?',
  );
  if (date == null || !context.mounted) return;
  final time = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.now(),
    helpText: 'What time is it due?',
  );
  if (time == null) return;
  final dueAt = DateTime(
    date.year,
    date.month,
    date.day,
    time.hour,
    time.minute,
  );
  final task = CheckItem(
    result.first.trim(),
    note: result[1].trim(),
    dueAt: dueAt,
    notificationId: dueAt.millisecondsSinceEpoch.remainder(2000000000),
  );
  items.add(task);
  refresh();
  if (preferences?.enabled == true && preferences?.householdReminders == true) {
    await notifications.scheduleTaskReminder(task);
  }
}

Future<void> addIdea(
  BuildContext context,
  List<Idea> items,
  VoidCallback refresh,
  String prompt,
) async {
  final result = await textPrompt(
    context,
    prompt,
    fields: const ['Title', 'Notes'],
  );
  if (result != null && result[0].trim().isNotEmpty) {
    items.add(Idea(result[0].trim(), result[1].trim()));
    refresh();
  }
}

Future<void> addEvent(
  BuildContext context,
  List<CalendarEvent> events,
  VoidCallback refresh,
) async {
  final result = await textPrompt(
    context,
    'Add event',
    fields: const ['Event name'],
  );
  if (result == null || result.first.trim().isEmpty || !context.mounted) return;
  final date = await showDatePicker(
    context: context,
    initialDate: DateTime.now(),
    firstDate: DateTime.now().subtract(const Duration(days: 365)),
    lastDate: DateTime.now().add(const Duration(days: 3650)),
  );
  if (date != null) {
    events.add(CalendarEvent(result.first.trim(), date));
    refresh();
  }
}

Future<void> addExpense(
  BuildContext context,
  List<Expense> expenses,
  VoidCallback refresh,
) async {
  final result = await textPrompt(
    context,
    'Add expense',
    fields: const ['What was it?', 'Amount', 'Category'],
  );
  if (result == null || result[0].trim().isEmpty) return;
  final amount = double.tryParse(result[1].replaceAll(r'$', '').trim());
  if (amount == null) return;
  expenses.add(
    Expense(
      result[0].trim(),
      amount,
      result[2].trim().isEmpty ? 'Other' : result[2].trim(),
    ),
  );
  refresh();
}

Future<void> editBudget(
  BuildContext context,
  double budget,
  ValueChanged<double> onBudget,
) async {
  final result = await textPrompt(
    context,
    'Monthly budget',
    fields: ['Budget amount'],
    values: [budget.toStringAsFixed(0)],
  );
  final amount = result == null
      ? null
      : double.tryParse(result.first.replaceAll(r'$', '').trim());
  if (amount != null && amount >= 0) onBudget(amount);
}

Future<List<String>?> textPrompt(
  BuildContext context,
  String title, {
  required List<String> fields,
  List<String>? values,
}) async {
  final controllers = List.generate(
    fields.length,
    (index) => TextEditingController(text: values == null ? '' : values[index]),
  );
  final result = await showDialog<List<String>>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(
            fields.length,
            (index) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: TextField(
                controller: controllers[index],
                keyboardType:
                    fields[index] == 'Amount' ||
                        fields[index] == 'Budget amount'
                    ? const TextInputType.numberWithOptions(decimal: true)
                    : null,
                decoration: InputDecoration(labelText: fields[index]),
              ),
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(
            dialogContext,
            controllers.map((controller) => controller.text).toList(),
          ),
          child: const Text('Save'),
        ),
      ],
    ),
  );
  for (final controller in controllers) {
    controller.dispose();
  }
  return result;
}
