// lib/core/router/app_router.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:bulwark/features/about/presentation/about_screen.dart';
import 'package:bulwark/features/adoption/presentation/progress_screen.dart';
import 'package:bulwark/features/adoption/presentation/providers.dart';
import 'package:bulwark/features/adoption/presentation/queue_screen.dart';
import 'package:bulwark/features/adoption/presentation/shopping_screen.dart';
import 'package:bulwark/features/checkin/presentation/checkin_screen.dart';
import 'package:bulwark/features/home/presentation/home_screen.dart';
import 'package:bulwark/features/library/presentation/intervention_detail_screen.dart';
import 'package:bulwark/features/library/presentation/library_screen.dart';
import 'package:bulwark/features/onboarding/presentation/onboarding_screen.dart';
import 'package:bulwark/features/settings/presentation/settings_screen.dart';

part 'app_router.g.dart';

CustomTransitionPage<T> _fade<T>({required LocalKey key, required Widget child}) =>
    CustomTransitionPage<T>(
      key: key,
      child: child,
      transitionDuration: const Duration(milliseconds: 350),
      transitionsBuilder: (_, a, __, c) =>
          FadeTransition(opacity: CurvedAnimation(parent: a, curve: Curves.easeOut), child: c),
    );

/// Route table for the core loop. The redirect gates the whole app on
/// onboarding: with no onboarded [Profile] every route funnels to
/// `/onboarding`, and once onboarded that screen bounces to Home. The router is
/// rebuilt-free (kept alive) and re-runs its redirect whenever the profile
/// changes, via a [ValueNotifier] driven off [profileProvider].
@Riverpod(keepAlive: true)
GoRouter appRouter(Ref ref) {
  final refresh = ValueNotifier<int>(0);
  ref.onDispose(refresh.dispose);
  ref.listen(profileProvider, (_, __) => refresh.value++);

  final router = GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) {
      final async = ref.read(profileProvider);
      // Hold still until the profile has resolved — don't flash onboarding at
      // a returning, already-onboarded user while the row loads.
      if (!async.hasValue) return null;
      final onboarded = async.value?.onboarded ?? false;
      final atOnboarding = state.matchedLocation == '/onboarding';
      if (!onboarded && !atOnboarding) return '/onboarding';
      if (onboarded && atOnboarding) return '/';
      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        pageBuilder: (c, s) => _fade(key: s.pageKey, child: const HomeScreen()),
      ),
      GoRoute(
        path: '/onboarding',
        pageBuilder: (c, s) =>
            _fade(key: s.pageKey, child: const OnboardingScreen()),
      ),
      GoRoute(
        path: '/checkin',
        pageBuilder: (c, s) =>
            _fade(key: s.pageKey, child: const CheckinScreen()),
      ),
      GoRoute(
        path: '/library',
        pageBuilder: (c, s) =>
            _fade(key: s.pageKey, child: const LibraryScreen()),
      ),
      GoRoute(
        path: '/intervention/:id',
        pageBuilder: (c, s) => _fade(
          key: s.pageKey,
          child: InterventionDetailScreen(id: s.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: '/queue',
        pageBuilder: (c, s) =>
            _fade(key: s.pageKey, child: const QueueScreen()),
      ),
      GoRoute(
        path: '/shopping',
        pageBuilder: (c, s) =>
            _fade(key: s.pageKey, child: const ShoppingScreen()),
      ),
      GoRoute(
        path: '/progress',
        pageBuilder: (c, s) =>
            _fade(key: s.pageKey, child: const ProgressScreen()),
      ),
      GoRoute(
        path: '/settings',
        pageBuilder: (c, s) =>
            _fade(key: s.pageKey, child: const SettingsScreen()),
      ),
      GoRoute(
        path: '/about',
        pageBuilder: (c, s) =>
            _fade(key: s.pageKey, child: const AboutScreen()),
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
}
