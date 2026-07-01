import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'package:bulwark/features/adoption/domain/notification_planner.dart';
import 'package:bulwark/features/notifications/notification_service.dart';

/// Android: schedules the planner's reminders as repeating daily local
/// notifications via flutter_local_notifications.
///
/// Scheduling uses [AndroidScheduleMode.inexactAllowWhileIdle] deliberately — we
/// do NOT request SCHEDULE_EXACT_ALARM, keeping the permission footprint as
/// small as the no-INTERNET ethos. A habit nudge landing a few minutes late is
/// fine; a wall of exact-alarm permissions is not.
class AndroidNotificationService implements NotificationService {
  AndroidNotificationService(this._plugin);

  final FlutterLocalNotificationsPlugin _plugin;
  bool _ready = false;

  static const _channelId = 'bulwark_reminders';
  static const _channelName = 'Reminders';
  static const _channelDescription =
      'Gentle daily nudges for your habits and check-in.';

  static const NotificationDetails _details = NotificationDetails(
    android: AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    ),
  );

  @override
  Future<void> init() async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    tz.setLocalLocation(_resolveLocalLocation());

    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await _plugin.initialize(settings: settings);

    await _android?.createNotificationChannel(const AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDescription,
      importance: Importance.defaultImportance,
    ));
    _ready = true;
  }

  @override
  Future<bool> requestPermission() async {
    await init();
    return await _android?.requestNotificationsPermission() ?? false;
  }

  @override
  Future<void> reschedule(List<PlannedNotification> notifications) async {
    await init();
    await _plugin.cancelAll();
    // Index-based ids are collision-free because we cancelAll first, and the
    // plan is never longer than NotificationPlanner.maxPerDay.
    for (final (i, n) in notifications.indexed) {
      await _plugin.zonedSchedule(
        id: i,
        scheduledDate: _nextInstanceOfMinute(n.minutesSinceMidnight),
        notificationDetails: _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        title: n.title,
        body: n.body,
        matchDateTimeComponents: DateTimeComponents.time, // repeat daily
      );
    }
  }

  @override
  Future<void> cancelAll() async {
    await init();
    await _plugin.cancelAll();
  }

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  /// The next wall-clock occurrence of [minutesSinceMidnight] in the local zone —
  /// today if it's still ahead, tomorrow otherwise.
  tz.TZDateTime _nextInstanceOfMinute(int minutesSinceMidnight) {
    final now = tz.TZDateTime.now(tz.local);
    var when = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      minutesSinceMidnight ~/ 60,
      minutesSinceMidnight % 60,
    );
    if (!when.isAfter(now)) when = when.add(const Duration(days: 1));
    return when;
  }

  /// Resolve the device's local zone by matching the current UTC offset. This
  /// avoids a flutter_timezone dependency; it is DST-imperfect (it can pick a
  /// same-offset sibling zone) but correct for a daily wall-clock reminder, and
  /// falls back to UTC if nothing matches.
  tz.Location _resolveLocalLocation() {
    final offset = DateTime.now().timeZoneOffset;
    for (final loc in tz.timeZoneDatabase.locations.values) {
      if (tz.TZDateTime.now(loc).timeZoneOffset == offset) return loc;
    }
    return tz.getLocation('UTC');
  }
}

NotificationService createNotificationService() =>
    AndroidNotificationService(FlutterLocalNotificationsPlugin());
