import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openhearth_design/openhearth_design.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import 'package:bulwark/features/adoption/presentation/providers.dart';
import 'package:bulwark/features/adoption/presentation/widgets/evidence_tag.dart';
import 'package:bulwark/features/library/data/content_loader.dart';
import 'package:bulwark/features/library/domain/enums.dart';
import 'package:bulwark/features/library/domain/intervention.dart';
import 'package:bulwark/features/library/presentation/content_labels.dart';
import 'package:bulwark/features/library/presentation/library_filter.dart';
import 'package:bulwark/shared/theme/app_palette.dart';
import 'package:bulwark/shared/theme/app_spacing.dart';
import 'package:bulwark/shared/widgets/theme_toggle.dart';

/// The full reference library: every shipped intervention, searchable and
/// filterable. Read-only browsing — activating happens on the Detail screen.
class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  final _searchController = TextEditingController();
  LibraryFilters _filters = const LibraryFilters();
  bool _seededThreshold = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openFacetSheet() async {
    final updated = await showModalBottomSheet<LibraryFilters>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _FacetSheet(initial: _filters),
    );
    if (updated != null) setState(() => _filters = updated);
  }

  @override
  Widget build(BuildContext context) {
    final libraryAsync = ref.watch(contentLibraryProvider);
    // Default the evidence floor to the user's onboarding preference, once.
    final profile = ref.watch(profileProvider).valueOrNull;
    if (!_seededThreshold && profile != null) {
      _seededThreshold = true;
      _filters =
          _filters.copyWith(evidenceThreshold: profile.evidenceThreshold);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Library'),
        actions: [
          // Bar words stop growing at 2x, as ThemeToggle's do.
          MediaQuery.withClampedTextScaling(
            maxScaleFactor: 2.0,
            child: TextButton.icon(
              onPressed: _openFacetSheet,
              style: TextButton.styleFrom(
                foregroundColor: IconTheme.of(context).color,
                iconColor: IconTheme.of(context).color,
                minimumSize: const Size(48, 48),
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              label: const Text('Filters'),
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(LucideIcons.slidersHorizontal),
                  if (_filters.hasFacets)
                    Positioned(
                      right: -2,
                      top: -2,
                      child: CircleAvatar(
                        radius: 4,
                        backgroundColor: BulwarkPalette.of(context).lichen,
                      ),
                    ),
                ],
              ),
            ),
          ),
          const ThemeToggle(),
        ],
      ),
      body: OhPage(
        padding: EdgeInsets.zero,
        child: libraryAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, st) => OhErrorState.fromError(
            e,
            stackTrace: st,
            title: "Couldn’t open the library",
            onRetry: () => ref.invalidate(contentLibraryProvider),
          ),
          data: (library) {
            final results = filterInterventions(library, _filters);
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.md,
                      AppSpacing.md, AppSpacing.md, AppSpacing.sm),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (v) =>
                        setState(() => _filters = _filters.copyWith(query: v)),
                    decoration: InputDecoration(
                      hintText: 'Search habits',
                      isDense: true,
                      prefixIcon: const Icon(LucideIcons.search, size: 18),
                      suffixIcon: _filters.query.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(LucideIcons.x, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                setState(() =>
                                    _filters = _filters.copyWith(query: ''));
                              },
                            ),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                _CategoryStrip(
                  selected: _filters.categories,
                  onToggle: (c) => setState(() {
                    final next = Set<Category>.of(_filters.categories);
                    next.contains(c) ? next.remove(c) : next.add(c);
                    _filters = _filters.copyWith(categories: next);
                  }),
                ),
                Expanded(
                  child: results.isEmpty
                      ? const _NoMatches()
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(AppSpacing.md,
                              AppSpacing.sm, AppSpacing.md, AppSpacing.md),
                          itemCount: results.length,
                          itemBuilder: (_, i) =>
                              _LibraryRow(intervention: results[i]),
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// A horizontally-scrolling row of category filter chips — scrolls rather than
/// overflows on a narrow screen.
class _CategoryStrip extends StatelessWidget {
  const _CategoryStrip({required this.selected, required this.onToggle});

  final Set<Category> selected;
  final void Function(Category) onToggle;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        itemCount: Category.values.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (_, i) {
          final c = Category.values[i];
          return Align(
            alignment: Alignment.center,
            child: FilterChip(
              label: Text(categoryLabel(c)),
              selected: selected.contains(c),
              showCheckmark: false,
              onSelected: (_) => onToggle(c),
            ),
          );
        },
      ),
    );
  }
}

class _LibraryRow extends StatelessWidget {
  const _LibraryRow({required this.intervention});

  final Intervention intervention;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push('/intervention/${intervention.id}'),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(intervention.title,
                  style: text.titleMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: AppSpacing.xs),
              // What the habit IS, so it reads as body text, whole
              // (audit design-for-hackers-07); only the metadata below is
              // secondary.
              Text(
                intervention.action,
                style: text.bodyMedium
                    ?.copyWith(color: Theme.of(context).colorScheme.onSurface),
              ),
              const SizedBox(height: AppSpacing.sm),
              // Wrap keeps the metadata reflowing instead of overflowing at
              // large text scales on a 320dp screen.
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _MetaPill(categoryLabel(intervention.category)),
                  EvidenceTag(intervention.evidence),
                  _MetaPill(costLabel(intervention.cost.tier)),
                  _MetaPill(timeLabel(intervention.timeCostMinutes)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A small, muted metadata pill — no ranking, just a scannable fact.
class _MetaPill extends StatelessWidget {
  const _MetaPill(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
      decoration: BoxDecoration(
        color: BulwarkPalette.of(context).secondaryText.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label,
          style: text.labelSmall
              ?.copyWith(color: Theme.of(context).colorScheme.onSurface)),
    );
  }
}

class _NoMatches extends StatelessWidget {
  const _NoMatches();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Text(
          'Nothing matches those filters yet.\nTry widening them.',
          style: text.bodyLarge
              ?.copyWith(color: BulwarkPalette.of(context).secondaryText),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

// ─── Facet sheet (evidence / cost / time) ───────────────────────────────────

class _FacetSheet extends StatefulWidget {
  const _FacetSheet({required this.initial});
  final LibraryFilters initial;

  @override
  State<_FacetSheet> createState() => _FacetSheetState();
}

class _FacetSheetState extends State<_FacetSheet> {
  late LibraryFilters _draft = widget.initial;

  static const _evidenceOptions = [
    (0, 'Any'),
    (1, 'Mechanistic +'),
    (2, 'Observational +'),
    (3, 'Trials only'),
  ];
  static const _timeOptions = [
    (null, 'Any'),
    // 'Up to' rather than the maths symbol: neither bundled font has
    // U+2264, so it drew as a box. Same meaning, in letters we ship.
    (5, 'Up to 5 min'),
    (10, 'Up to 10 min'),
    (20, 'Up to 20 min'),
  ];

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Filters', style: text.titleLarge),
            const SizedBox(height: AppSpacing.md),
            Text('Minimum evidence', style: text.titleSmall),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final (value, label) in _evidenceOptions)
                  ChoiceChip(
                    label: Text(label),
                    selected: _draft.evidenceThreshold == value,
                    onSelected: (_) => setState(() =>
                        _draft = _draft.copyWith(evidenceThreshold: value)),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text('Cost', style: text.titleSmall),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final tier in CostTier.values)
                  FilterChip(
                    label: Text(costLabel(tier)),
                    selected: _draft.costTiers.contains(tier),
                    showCheckmark: false,
                    onSelected: (_) => setState(() {
                      final next = Set<CostTier>.of(_draft.costTiers);
                      next.contains(tier) ? next.remove(tier) : next.add(tier);
                      _draft = _draft.copyWith(costTiers: next);
                    }),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text('Daily time', style: text.titleSmall),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final (value, label) in _timeOptions)
                  ChoiceChip(
                    label: Text(label),
                    selected: _draft.maxMinutes == value,
                    onSelected: (_) => setState(
                        () => _draft = _draft.copyWith(maxMinutes: value)),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            // Wrap (not a Row with a Spacer): at 320 dp × large text the two
            // buttons overflowed the row; here they drop to their own lines
            // instead.
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                TextButton(
                  onPressed: () => setState(() => _draft = LibraryFilters(
                        query: _draft.query,
                      )),
                  child: const Text('Clear'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(_draft),
                  child: const Text('Apply'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
