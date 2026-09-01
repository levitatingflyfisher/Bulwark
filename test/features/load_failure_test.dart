import 'package:bulwark/core/providers/core_providers.dart';
import 'package:bulwark/features/adoption/presentation/providers.dart';
import 'package:bulwark/features/adoption/presentation/queue_screen.dart';
import 'package:bulwark/features/checkin/presentation/checkin_screen.dart';
import 'package:bulwark/features/home/presentation/home_screen.dart';
import 'package:bulwark/features/library/data/content_loader.dart';
import 'package:bulwark/features/library/domain/content_library.dart';
import 'package:bulwark/features/library/presentation/intervention_detail_screen.dart';
import 'package:bulwark/features/library/presentation/library_screen.dart';
import 'package:bulwark/features/onboarding/presentation/onboarding_screen.dart';
import 'package:bulwark/features/settings/domain/user_prefs.dart';
import 'package:bulwark/features/settings/presentation/settings_screen.dart';
import 'package:bulwark/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openhearth_design/openhearth_design.dart';

/// A load failure shows the fleet's one failure state (a plain sentence and
/// Try again), never the exception's own text (C10; the audit found
/// "Something went wrong.\n$error" on six screens).
const _secret = 'SqliteException(5): database is locked';

Never _boom() => throw StateError(_secret);

void main() {
  final overrides = <Override>[
    userPrefsProvider.overrideWith((ref) => Stream.value(const UserPrefs())),
    activeHabitsProvider.overrideWith((ref) async => _boom()),
    queuedHabitsProvider.overrideWith((ref) async => _boom()),
    profileProvider.overrideWith((ref) async => _boom()),
    contentLibraryProvider.overrideWith(
        (ref) => Future<ContentLibrary>.error(StateError(_secret))),
    habitStatesByIdProvider.overrideWith((ref) async => const {}),
    graduationEligibleProvider.overrideWith((ref) async => const []),
    todaysCheckinsProvider.overrideWith((ref) async => const []),
    pulseDueProvider.overrideWith((ref) async => const []),
    allCheckinsProvider.overrideWith((ref) async => const []),
    weakTriggerIdsProvider.overrideWith((ref) async => const {}),
    pausedHabitsProvider.overrideWith((ref) async => const []),
  ];

  final screens = <String, Widget>{
    'Home': const HomeScreen(),
    'Queue': const QueueScreen(),
    'Check-in': const CheckinScreen(),
    'Library': const LibraryScreen(),
    'Detail': const InterventionDetailScreen(id: 'x'),
    'Settings': const SettingsScreen(),
    'Onboarding': const OnboardingScreen(),
  };

  for (final s in screens.entries) {
    testWidgets('${s.key}: a load failure is a friendly state with Try again',
        (tester) async {
      await tester.pumpWidget(ProviderScope(
        overrides: overrides,
        child: MaterialApp(theme: AppTheme.light, home: s.value),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(OhErrorState), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
      expect(find.textContaining('database is locked'), findsNothing);
      expect(find.textContaining('StateError'), findsNothing);
    });
  }
}
