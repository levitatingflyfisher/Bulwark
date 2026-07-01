import 'package:bulwark/features/adoption/domain/notification_planner.dart';

/// The platform-agnostic contract for local reminders. The native (Android)
/// implementation lives in `notification_service_io.dart`; the web build gets a
/// genuine no-op (`notification_service_web.dart`); the right one is chosen by
/// the conditional import in `notification_service_factory.dart`.
///
/// This file deliberately carries *no* import of `flutter_local_notifications`
/// so a test that only exercises the web no-op (or any code that only needs the
/// interface) never transitively drags the plugin in.
abstract interface class NotificationService {
  /// Idempotent one-time setup: timezone database + the Android channel.
  Future<void> init();

  /// Ask the OS for notification permission (Android 13+). Call this only at
  /// opt-in moments — never inside [reschedule], which runs on every settings
  /// change and would re-prompt. Returns whether permission is granted.
  Future<bool> requestPermission();

  /// Cancel everything currently scheduled, then schedule each of
  /// [notifications] as a daily reminder at its `minutesSinceMidnight`. Passing
  /// an empty list is the honest way to cancel all reminders.
  Future<void> reschedule(List<PlannedNotification> notifications);

  /// Cancel every scheduled reminder.
  Future<void> cancelAll();
}
