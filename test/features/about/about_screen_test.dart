import 'package:bulwark/core/app_info.dart';
import 'package:bulwark/features/about/presentation/about_screen.dart';
import 'package:bulwark/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app({double textScale = 1.0}) => MaterialApp(
      theme: AppTheme.light,
      home: const AboutScreen(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
    );

/// Tall viewport so the whole About list is built (a ListView lazily skips
/// off-screen children, which finders can't reach).
void _tallView(WidgetTester tester) {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(420, 2600);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  testWidgets('shows the one idea, the tagline, and the local-first claim',
      (tester) async {
    _tallView(tester);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.text('A wall between you and entropy.'), findsOneWidget);
    expect(find.textContaining('never leaves this device'), findsOneWidget);
    expect(find.textContaining('free and open-source'), findsOneWidget);
    expect(find.textContaining('not medical advice'), findsOneWidget);
    expect(find.text('Version ${AppInfo.appVersion}'), findsOneWidget);
    expect(
      find.widgetWithText(OutlinedButton, 'Open-source licenses'),
      findsOneWidget,
    );
  });

  testWidgets('the licenses button opens the license page', (tester) async {
    _tallView(tester);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(OutlinedButton, 'Open-source licenses'));
    await tester.pumpAndSettle();
    expect(find.byType(LicensePage), findsOneWidget);
  });

  for (final scale in [1.0, 3.0]) {
    testWidgets('About holds at 320dp width and ${scale}x text', (tester) async {
      // Tall so every section (incl. the licenses button) lays out under 320 —
      // a short viewport would let the ListView skip building lower widgets.
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(320, 4000);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_app(textScale: scale));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
