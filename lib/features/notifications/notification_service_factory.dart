import 'package:bulwark/features/notifications/notification_service.dart';

// Platform selection: the web no-op by default, the native Android impl when
// dart:io exists. Kept out of `notification_service.dart` so the interface (and
// the web no-op) stay free of the flutter_local_notifications import.
import 'notification_service_web.dart'
    if (dart.library.io) 'notification_service_io.dart' as platform;

NotificationService createNotificationService() =>
    platform.createNotificationService();
