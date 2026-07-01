import 'package:bulwark/features/adoption/domain/notification_planner.dart';
import 'package:bulwark/features/notifications/notification_service_web.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // The web build must be a genuine no-op: every method returns without
  // throwing and without touching any plugin (scheduling on web would throw).
  const service = WebNotificationService();

  test('init returns cleanly', () async {
    await expectLater(service.init(), completes);
  });

  test('requestPermission returns false without prompting', () async {
    expect(await service.requestPermission(), isFalse);
  });

  test('reschedule of a real plan returns without throwing', () async {
    const plan = [
      PlannedNotification(
        minutesSinceMidnight: 8 * 60,
        title: 'Morning habits',
        body: 'sunlight',
        id: 'batch-morning',
      ),
    ];
    await expectLater(service.reschedule(plan), completes);
  });

  test('cancelAll returns cleanly', () async {
    await expectLater(service.cancelAll(), completes);
  });
}
