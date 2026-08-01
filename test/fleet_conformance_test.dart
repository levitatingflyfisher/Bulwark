import 'package:oh_fleet_conformance/oh_fleet_conformance.dart';

void main() => runFleetConformance(const FleetAppConfig(
      appId: 'bulwark',
      // Bundles its own type, so nothing falls back to a web font — a
      // character the bundled families cannot draw is a box on a
      // real phone. C7 sweeps lib/ for any.
      // C8: a bare IconButton.filled paints its glyph in ohStyle's ambient
      // iconTheme color, which is the same color as its own fill — a
      // button that's there but unreadable. OhIconButton pins it right.
      checks: {
        ...FleetAppConfig.withBundledFonts,
        FleetCheck.c8IconButtons,
      },
      // Tier-T (zero visual change): only the Material TextTheme ladder comes
      // from openhearth_design; the basalt/mortar/lichen identity stays
      // app-local. None of those hex values coincide with canonical tokens,
      // so no allowedTokenLiterals are needed.
      styleTier: StyleTier.tokens,
      // The exact manifest surface — deliberately NO INTERNET: the privacy
      // claim is structural (the release APK cannot reach the web).
      androidPermissions: {
        'android.permission.POST_NOTIFICATIONS',
        'android.permission.VIBRATE',
        'android.permission.RECEIVE_BOOT_COMPLETED',
      },
      // C4 v2 — the release MERGED surface: source permissions plus
      // what plugins and the manifest merge inject. Bites when an APK
      // build has left a merged manifest under build/ (dev box).
      mergedAndroidPermissions: {
        'android.permission.POST_NOTIFICATIONS',
        'android.permission.RECEIVE_BOOT_COMPLETED',
        'android.permission.VIBRATE',
        'com.openhearth.bulwark.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION',
      },
    ));
