import 'package:bulwark/features/adoption/domain/notification_planner.dart';
import 'package:bulwark/features/notifications/notification_service.dart';

/// Records what the app asked the platform to do, so tests can assert on the
/// planner→scheduler wiring without touching a real notification channel.
class FakeNotificationService implements NotificationService {
  int initCount = 0;
  int permissionCount = 0;
  int cancelAllCount = 0;

  /// One entry per `reschedule` call; each is the plan handed to the platform.
  final List<List<PlannedNotification>> rescheduleCalls = [];

  /// The most recent plan, or null if reschedule was never called.
  List<PlannedNotification>? get lastPlan =>
      rescheduleCalls.isEmpty ? null : rescheduleCalls.last;

  @override
  Future<void> init() async => initCount++;

  @override
  Future<bool> requestPermission() async {
    permissionCount++;
    return true;
  }

  @override
  Future<void> reschedule(List<PlannedNotification> notifications) async {
    rescheduleCalls.add(List.of(notifications));
  }

  @override
  Future<void> cancelAll() async => cancelAllCount++;
}
