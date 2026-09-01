import 'package:bulwark/features/about/presentation/about_screen.dart';
import 'package:bulwark/features/adoption/data/profile_repository.dart';
import 'package:bulwark/features/adoption/domain/enums.dart';
import 'package:bulwark/features/adoption/domain/profile.dart';
import 'package:bulwark/features/adoption/presentation/progress_screen.dart';
import 'package:bulwark/features/adoption/presentation/queue_screen.dart';
import 'package:bulwark/features/adoption/presentation/shopping_screen.dart';
import 'package:bulwark/features/checkin/presentation/checkin_screen.dart';
import 'package:bulwark/features/home/presentation/home_screen.dart';
import 'package:bulwark/features/library/presentation/intervention_detail_screen.dart';
import 'package:bulwark/features/library/presentation/library_screen.dart';
import 'package:bulwark/features/onboarding/presentation/onboarding_screen.dart';
import 'package:bulwark/features/settings/presentation/settings_screen.dart';
import 'package:bulwark/shared/theme/app_theme.dart';
import 'package:bulwark/shared/widgets/theme_toggle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openhearth_design/openhearth_design.dart';

import '../support/adoption_harness.dart';

/// On a tablet or in the browser each screen keeps a phone-width column
/// instead of stretching its 360 layout across 1024 px (audit about-face-10,
/// design-for-hackers-05), and every top-level screen carries the theme
/// control in its app bar, so light/dark/follow-phone is at most two taps
/// away (fleet ruling).
void main() {
  const topLevel = <String, Widget>{
    'Home': HomeScreen(),
    'Library': LibraryScreen(),
    'Queue': QueueScreen(),
    'Shopping': ShoppingScreen(),
    'Progress': ProgressScreen(),
    'Settings': SettingsScreen(),
  };
  const others = <String, Widget>{
    'Check-in': CheckinScreen(),
    'Detail': InterventionDetailScreen(id: 'sleep-window'),
    'About': AboutScreen(),
    'Onboarding': OnboardingScreen(),
  };

  for (final s in {...topLevel, ...others}.entries) {
    testWidgets('${s.key}: content is capped at 640 dp on a 1024 dp window',
        (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(1024, 768);
      addTearDown(tester.view.reset);
      final db = memoryDatabase();
      await tester.runAsync(() => ProfileRepository(db).save(const Profile(
            wakeMinutes: 7 * 60,
            bedMinutes: 22 * 60,
            goal: Goal.general,
            pace: Pace.moderate,
            onboarded: true,
          )));

      await tester.pumpWidget(ProviderScope(
        overrides: [...adoptionOverrides(db: db), ...backupOverrides()],
        child: MaterialApp(theme: AppTheme.light, home: s.value),
      ));
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 200)));
      await tester.pumpAndSettle();

      expect(find.byType(OhPage), findsOneWidget);
      final body = tester.getRect(find.byType(OhPage));
      final content = find.descendant(
          of: find.byType(OhPage), matching: find.byType(ConstrainedBox));
      final widest = content.evaluate().map((e) {
        final box = e.renderObject! as RenderBox;
        return box.size.width;
      }).reduce((a, b) => a > b ? a : b);
      expect(widest, lessThanOrEqualTo(640), reason: '${body.width} window');

      if (topLevel.containsKey(s.key)) {
        expect(
            find.descendant(
                of: find.byType(AppBar), matching: find.byType(ThemeToggle)),
            findsOneWidget);
      }

      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(db.close);
    });
  }
}
