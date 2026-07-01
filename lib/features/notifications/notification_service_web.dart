import 'package:bulwark/features/adoption/domain/notification_planner.dart';
import 'package:bulwark/features/notifications/notification_service.dart';

/// Web build: a genuine no-op. Scheduling a background notification from a PWA
/// isn't wired up (and would throw), so every method returns an empty Future
/// without touching any plugin. In-app cues carry reminders on the web; nothing
/// leaves the device either way.
class WebNotificationService implements NotificationService {
  const WebNotificationService();

  @override
  Future<void> init() async {}

  @override
  Future<bool> requestPermission() async => false;

  @override
  Future<void> reschedule(List<PlannedNotification> notifications) async {}

  @override
  Future<void> cancelAll() async {}
}

NotificationService createNotificationService() => const WebNotificationService();
