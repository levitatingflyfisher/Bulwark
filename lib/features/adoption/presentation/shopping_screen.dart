import 'package:flutter/material.dart';
import 'package:openhearth_design/openhearth_design.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import 'package:bulwark/features/adoption/domain/shopping_state.dart';
import 'package:bulwark/features/adoption/presentation/providers.dart';
import 'package:bulwark/features/library/domain/enums.dart';
import 'package:bulwark/features/library/domain/intervention.dart';
import 'package:bulwark/features/library/presentation/content_labels.dart';
import 'package:bulwark/shared/theme/app_palette.dart';
import 'package:bulwark/shared/theme/app_spacing.dart';
import 'package:bulwark/shared/widgets/theme_toggle.dart';

/// One shoppable need: the intervention it belongs to and its generic criteria.
class _ShopNeed {
  final String interventionId;
  final Shopping shopping;
  const _ShopNeed(this.interventionId, this.shopping);
}

/// The shopping list, derived from the supplies your active and queued habits
/// need. Grouped buy-once vs restock, then by where you'd get it. A checkbox
/// marks a need acquired — generic criteria only, never a brand or a link.
class ShoppingScreen extends ConsumerStatefulWidget {
  const ShoppingScreen({super.key});

  @override
  ConsumerState<ShoppingScreen> createState() => _ShoppingScreenState();
}

class _ShoppingScreenState extends ConsumerState<ShoppingScreen> {
  Future<void> _setPurchased(String interventionId, bool purchased) async {
    await ref.read(shoppingRepositoryProvider).setPurchased(
          interventionId,
          purchased: purchased,
          purchasedAt: purchased ? DateTime.now() : null,
        );
    ref.invalidate(shoppingStatesProvider);
    await ref.read(shoppingStatesProvider.future);
  }

  @override
  Widget build(BuildContext context) {
    final active = ref.watch(activeHabitsProvider);
    final queued = ref.watch(queuedHabitsProvider);
    final purchased = ref.watch(shoppingStatesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Shopping'),
        actions: const [ThemeToggle()],
      ),
      body: OhPage(
        padding: EdgeInsets.zero,
        child: (active.isLoading || queued.isLoading)
            ? const Center(child: CircularProgressIndicator())
            : _list(
                active.valueOrNull ?? const [],
                queued.valueOrNull ?? const [],
                purchased.valueOrNull ?? const {},
              ),
      ),
    );
  }

  Widget _list(
    List<ActiveHabit> active,
    List<ActiveHabit> queued,
    Map<String, ShoppingState> purchased,
  ) {
    // Dedupe by interventionId (a habit can't be active and queued at once, but
    // guard anyway), keep only those that need buying.
    final seen = <String>{};
    final needs = <_ShopNeed>[];
    for (final h in [...active, ...queued]) {
      if (!seen.add(h.interventionId)) continue;
      final shopping = h.intervention.shopping;
      if (shopping != null) needs.add(_ShopNeed(h.interventionId, shopping));
    }

    if (needs.isEmpty) return const _EmptyShopping();

    final oneTime = needs.where((n) => !n.shopping.recurring).toList();
    final recurring = needs.where((n) => n.shopping.recurring).toList();

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        ..._section('Buy once', oneTime, purchased),
        ..._section('Restock', recurring, purchased),
      ],
    );
  }

  List<Widget> _section(
    String title,
    List<_ShopNeed> needs,
    Map<String, ShoppingState> purchased,
  ) {
    if (needs.isEmpty) return const [];
    final widgets = <Widget>[
      Padding(
        padding:
            const EdgeInsets.only(top: AppSpacing.sm, bottom: AppSpacing.sm),
        child: Text(title, style: Theme.of(context).textTheme.titleMedium),
      ),
    ];
    for (final where in ShopWhere.values) {
      final inWhere = needs.where((n) => n.shopping.where == where).toList();
      if (inWhere.isEmpty) continue;
      widgets.add(Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.xs),
        child: Text(shopWhereLabel(where),
            style: Theme.of(context)
                .textTheme
                .labelMedium
                ?.copyWith(color: BulwarkPalette.of(context).secondaryText)),
      ));
      for (final need in inWhere) {
        widgets.add(_ShopRow(
          need: need,
          purchased: purchased[need.interventionId]?.purchased ?? false,
          onChanged: (v) => _setPurchased(need.interventionId, v),
        ));
      }
    }
    return widgets;
  }
}

class _ShopRow extends StatelessWidget {
  const _ShopRow({
    required this.need,
    required this.purchased,
    required this.onChanged,
  });

  final _ShopNeed need;
  final bool purchased;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final muted = purchased;
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => onChanged(!purchased),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: purchased,
                onChanged: (v) => onChanged(v ?? false),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        need.shopping.item,
                        style: text.titleSmall?.copyWith(
                          color: muted
                              ? BulwarkPalette.of(context).secondaryText
                              : Theme.of(context).colorScheme.onSurface,
                          decoration: muted ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        need.shopping.criteria,
                        style: text.bodySmall?.copyWith(
                            color: BulwarkPalette.of(context).secondaryText),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyShopping extends StatelessWidget {
  const _EmptyShopping();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.shoppingBasket,
                size: 40, color: BulwarkPalette.of(context).secondaryText),
            const SizedBox(height: AppSpacing.md),
            Text('Nothing to buy.',
                style: text.headlineSmall, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Your current habits need no supplies. Anything you add that does '
              'will show up here.',
              style: text.bodyLarge
                  ?.copyWith(color: BulwarkPalette.of(context).secondaryText),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
