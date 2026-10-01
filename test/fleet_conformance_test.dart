import 'package:oh_fleet_conformance/oh_fleet_conformance.dart';

void main() => runFleetConformance(const FleetAppConfig(
      appId: 'bulwark',
      // Lora/Nunito come bundled from openhearth_design's package fonts,
      // so nothing falls back to a web font: a character they cannot draw
      // is a box on a real phone. C7 sweeps lib/ for any.
      // C8: a bare IconButton.filled paints its glyph in ohStyle's ambient
      // iconTheme color, which is the same color as its own fill — a
      // button that's there but unreadable. OhIconButton pins it right.
      checks: {
        // C13: the PWA loads nothing from Google's CDNs. web/flutter_bootstrap.js
        // points CanvasKit and the engine's fallback fonts at this origin.
        FleetCheck.c13WebSelfHosted,
        ...FleetAppConfig.withBundledFonts,
        FleetCheck.c8IconButtons,
        // C10: no raw exception text on screen; failures go through
        // OhErrorState, the exception only behind Details.
        FleetCheck.c10RawErrors,
        // C11: every top-bar action has a name; Bulwark's are icon plus a
        // visible word (Menu, Filters, the theme toggle).
        FleetCheck.c11IconLabels,
        // C9: every routed screen has a way in.
        FleetCheck.c9Routes,
        // C12: the basalt accent stays well clear of the urgency red (and
        // Bulwark's own error role is clay; nothing here is red).
        FleetCheck.c12AccentVsError,
        // C5-primaryScreens: these run the 360dp x 1.3 reach sweep and the
        // 320dp x 3.0 overflow sweep in test/a11y/primary_action_sweep_test.
        FleetCheck.c5PrimaryScreens,
      },
      primaryActionScreens: {'HomeScreen', 'CheckinScreen'},
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
