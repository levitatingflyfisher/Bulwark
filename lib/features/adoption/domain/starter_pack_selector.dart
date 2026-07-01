import 'package:bulwark/features/adoption/domain/enums.dart';
import 'package:bulwark/features/adoption/domain/profile.dart';
import 'package:bulwark/features/library/domain/content_library.dart';
import 'package:bulwark/features/library/domain/enums.dart';
import 'package:bulwark/features/library/domain/intervention.dart';

/// Proposes the onboarding starter pack: the highest-affinity, lowest-friction
/// interventions the user can act on tonight. Pure and deterministic — same
/// (profile, library) always yields the same ordered list.
class StarterPackSelector {
  const StarterPackSelector();

  /// Goal → category affinity weights. A category absent from a goal's map
  /// scores 0 for that goal.
  static const Map<Goal, Map<Category, int>> affinity = {
    Goal.sleep: {
      Category.sleep: 3,
      Category.stress: 2,
      Category.environment: 1,
    },
    Goal.energy: {
      Category.metabolic: 3,
      Category.nutrition: 2,
      Category.sleep: 1,
    },
    Goal.pain: {
      Category.musculoskeletal: 3,
      Category.stress: 2,
      Category.nutrition: 1,
    },
    Goal.longevity: {
      Category.metabolic: 3,
      Category.nutrition: 2,
      Category.musculoskeletal: 1,
    },
    Goal.immune: {
      Category.nutrition: 3,
      Category.sleep: 2,
      Category.hygiene: 1,
    },
    Goal.general: {
      Category.sleep: 2,
      Category.nutrition: 2,
      Category.stress: 1,
      Category.musculoskeletal: 1,
    },
  };

  List<Intervention> select(Profile profile, ContentLibrary library) {
    final size = profile.pace.starterPackSize;
    final weights = affinity[profile.goal] ?? const {};

    final eligible = library.all
        .where((i) =>
            i.isActivatable &&
            i.cost.tier == CostTier.free &&
            i.timeCostMinutes <= 10 &&
            profile.hasAnchor(i.trigger.anchor))
        .toList();

    int scoreOf(Intervention i) {
      final aff = weights[i.category] ?? 0;
      final phaseBias = i.defaultPhase == 1 ? 1 : 0;
      return aff * 10 + phaseBias;
    }

    eligible.sort((a, b) {
      final byScore = scoreOf(b).compareTo(scoreOf(a)); // higher score first
      if (byScore != 0) return byScore;
      final byPhase = a.defaultPhase.compareTo(b.defaultPhase); // earlier phase
      if (byPhase != 0) return byPhase;
      return a.id.compareTo(b.id); // id makes the order total → deterministic
    });

    return eligible.take(size).toList();
  }
}
