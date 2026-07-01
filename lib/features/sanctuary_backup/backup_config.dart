import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sanctuary_backup_ui/sanctuary_backup_ui.dart';

import '../settings/presentation/settings_actions.dart';

/// Bulwark's [SanctuaryBackupConfig] — app identity, AEAD context, and the
/// destructive-restore consequence copy for the encrypted-backup wiring
/// (SANCTUARY-BRIEF §4.W2). Pulled out of `main.dart` into its own file so
/// the restore-consequence copy is unit-testable directly: it must list
/// everything a restore actually wipes (`AppDatabase.eraseUserData`'s five
/// tables, including the onboarding profile — day-map, goal, pace, evidence
/// threshold, new-parent mode — which is easy to omit from the sentence
/// while still wiping it).
const bulwarkBackupConfig = SanctuaryBackupConfig(
  appId: 'bulwark',
  aadContext: 'bulwark-backup/v1',
  appDisplayName: 'Bulwark',
  restoreReplaceConsequence:
      'Restoring will delete your onboarding profile (day-map, goal, pace, '
      'and reminder settings), every habit, check-in, weekly pulse, and '
      'shopping/purchase state on this device, then replace them with the '
      'contents of the backup file.',
  onAfterRestore: _afterRestore,
);

// Fire-and-forget: the UI doesn't block on invalidation/reminder replanning
// finishing (mirrors Lullaby's onAfterRestore pattern of wrapping the async
// tail in unawaited()). afterBackupRestore itself returns a Future so it
// stays directly awaitable in tests.
void _afterRestore(Ref ref) => unawaited(afterBackupRestore(ref));
