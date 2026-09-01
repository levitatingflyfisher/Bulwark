// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sanctuary_auth_core/sanctuary_auth_core.dart' as sanctuary;
import 'package:sanctuary_backup_ui/sanctuary_backup_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bulwark/core/providers/core_providers.dart';
import 'package:bulwark/core/router/app_router.dart';
import 'package:bulwark/features/sanctuary_backup/backup_config.dart';
import 'package:bulwark/features/sanctuary_backup/data/backup_serializer.dart';
import 'package:bulwark/shared/theme/app_theme.dart';
import 'package:bulwark/shared/widgets/undo_host.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        // Encrypted-backup wiring (sanctuary_backup_ui). Bulwark is a new app
        // (not a legacy Lullaby-style carry-over), so — unlike Lullaby — it
        // sets an explicit appDomain: this app's key material is isolated
        // from any other OpenHearth app sharing the same household seed
        // phrase (SANCTUARY-BRIEF §2.1). Aliased `as sanctuary` so its
        // AuthState/AuthTier can never collide with Bulwark's own unrelated
        // core/auth/auth_state.dart stub types of the same name.
        sanctuary.sanctuaryAppDomainProvider.overrideWithValue('bulwark'),
        sanctuaryBackupConfigProvider.overrideWithValue(bulwarkBackupConfig),
        // On web every fleet PWA shares one origin's localStorage; this gives
        // Bulwark's recovery words their own names (native is unchanged).
        appScopedKeyStoreOverride(),
        backupSerializerProvider.overrideWith(
          (ref) => BulwarkBackupSerializer(ref.watch(appDatabaseProvider)),
        ),
      ],
      child: const BulwarkApp(),
    ),
  );
}

class BulwarkApp extends ConsumerStatefulWidget {
  const BulwarkApp({super.key});

  @override
  ConsumerState<BulwarkApp> createState() => _BulwarkAppState();
}

class _BulwarkAppState extends ConsumerState<BulwarkApp> {
  @override
  void initState() {
    super.initState();
    // Silent freshness snapshot (BACKUP_RETENTION_SPEC §3): if the newest
    // vault snapshot is >7 days old and a backup key exists, take one.
    // Post-frame + fire-and-forget — never blocks boot, never surfaces
    // errors (the Sundial/Lullaby startup pattern).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(backupControllerProvider.notifier).runStartupMaintenance();
    });
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp.router(
      title: 'Bulwark',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      routerConfig: router,
      // Each screen caps its own content width (OhPage), so the app bars
      // still span the window while the column stays readable. The Undo bar
      // for lifecycle changes lives under every screen.
      builder: (context, child) =>
          UndoHost(child: child ?? const SizedBox.shrink()),
    );
  }
}
