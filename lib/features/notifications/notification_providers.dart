// The platform notification service and the one action that (re)builds the
// day's reminder plan. `rescheduleNotifications` is called after onboarding and
// whenever a reminder-relevant setting changes; it is best-effort by design so a
// scheduling failure never blocks the write that triggered it.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:bulwark/core/providers/core_providers.dart';
import 'package:bulwark/features/adoption/domain/notification_planner.dart';
import 'package:bulwark/features/adoption/presentation/providers.dart';
import 'package:bulwark/features/library/data/content_loader.dart';
import 'package:bulwark/features/notifications/notification_service.dart';
import 'package:bulwark/features/notifications/notification_service_factory.dart';

part 'notification_providers.g.dart';

/// The platform notification service — the native Android scheduler on device,
/// a genuine no-op on web. keepAlive: one instance holds the plugin + timezone
/// setup for the app's life. Tests override this with a fake.
@Riverpod(keepAlive: true)
NotificationService notificationService(Ref ref) => createNotificationService();

/// Recompute the day's reminder plan and hand it to the platform scheduler.
///
/// Honors the master Reminders switch: when it's off (or there's no profile
/// yet) we reschedule an empty plan, which cancels everything. Best-effort —
/// any failure (a denied permission, a plugin missing under test) is swallowed
/// so it never surfaces to the user or aborts the caller's save.
Future<void> rescheduleNotifications(WidgetRef ref) =>
    rescheduleNotificationsFrom(ref.read);

/// [rescheduleNotifications] for callers that hold a provider `Ref` (or any
/// reader) rather than a widget's, such as an app-lived service whose work
/// outlives the widget that started it.
Future<void> rescheduleNotificationsFrom(
    T Function<T>(ProviderListenable<T> provider) read) async {
  try {
    final service = read(notificationServiceProvider);
    final prefs = await read(settingsRepositoryProvider).getUserPrefs();
    final profile = await read(profileProvider.future);
    if (!prefs.remindersEnabled || profile == null) {
      await service.reschedule(const []);
      return;
    }
    final library = await read(contentLibraryProvider.future);
    final active = await read(habitStateRepositoryProvider).activeStates();
    final planned = const NotificationPlanner()
        .plan(profile: profile, active: active, library: library);
    await service.reschedule(planned);
  } catch (_) {
    // Reminders are best-effort; a scheduling failure must not block a save.
  }
}
