import 'package:bulwark/features/adoption/domain/checkin.dart';
import 'package:bulwark/features/adoption/domain/enums.dart';
import 'package:bulwark/features/adoption/domain/habit_state.dart';
import 'package:bulwark/features/adoption/domain/pulse.dart';
import 'package:bulwark/features/adoption/domain/wall_layout.dart';
import 'package:bulwark/features/adoption/presentation/progress_screen.dart';
import 'package:bulwark/features/adoption/presentation/providers.dart';
import 'package:bulwark/features/adoption/presentation/wall_painter.dart';
import 'package:bulwark/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/content_builders.dart';

ActiveHabit _graduated(String id, {DateTime? at}) => ActiveHabit(
      state: HabitState(
        interventionId: id,
        status: HabitStatus.graduated,
        activatedAt: DateTime(2026, 1, 1),
        graduatedAt: at ?? DateTime(2026, 2, 1),
        createdAt: DateTime(2026, 1, 1),
      ),
      intervention: intervention(id: id),
    );

ActiveHabit _active(String id) => ActiveHabit(
      state: HabitState(
        interventionId: id,
        status: HabitStatus.active,
        activatedAt: DateTime(2026, 1, 1),
        createdAt: DateTime(2026, 1, 1),
      ),
      intervention: intervention(id: id),
    );

Widget _screen({
  List<ActiveHabit> graduated = const [],
  List<ActiveHabit> active = const [],
  List<Pulse> pulses = const [],
  List<Checkin> checkins = const [],
  double textScale = 1.0,
}) =>
    ProviderScope(
      overrides: [
        graduatedHabitsProvider.overrideWith((ref) async => graduated),
        activeHabitsProvider.overrideWith((ref) async => active),
        allPulsesProvider.overrideWith((ref) async => pulses),
        allCheckinsProvider.overrideWith((ref) async => checkins),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: const ProgressScreen(),
      ),
    );

void main() {
  testWidgets('the wall renders with no stones', (tester) async {
    await tester.pumpWidget(_screen());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('wall-canvas')), findsOneWidget);
    expect(find.textContaining('Nothing here yet'), findsOneWidget);
  });

  testWidgets('one graduated habit shows a stone and the made-automatic list',
      (tester) async {
    await tester.pumpWidget(_screen(graduated: [_graduated('g1')]));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('wall-canvas')), findsOneWidget);
    expect(find.text('g1'), findsOneWidget); // made-automatic row
    expect(tester.takeException(), isNull);
  });

  testWidgets('twelve graduated habits render without overflow', (tester) async {
    final many = [for (var i = 0; i < 12; i++) _graduated('g$i')];
    await tester.pumpWidget(_screen(graduated: many));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('wall-canvas')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('active habits render as forming stones on the wall',
      (tester) async {
    await tester.pumpWidget(_screen(
      graduated: [_graduated('g1')],
      active: [_active('a1'), _active('a2')],
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('wall-canvas')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an eroded graduated habit offers a repoint', (tester) async {
    // Two consecutive shaky weekly pulses for g1 -> eroded.
    final w0 = DateTime(2026, 3, 2); // a Monday
    final pulses = [
      Pulse(interventionId: 'g1', weekStart: w0, result: PulseResult.shaky),
      Pulse(
          interventionId: 'g1',
          weekStart: w0.add(const Duration(days: 7)),
          result: PulseResult.shaky),
    ];
    await tester.pumpWidget(_screen(
      graduated: [_graduated('g1'), _graduated('g2')],
      pulses: pulses,
    ));
    await tester.pumpAndSettle();

    // 'Repoint' (exact) is the row's affordance; the sheet's button reads
    // 'Repoint (make it active again)', so this match is unambiguous.
    expect(find.text('Repoint'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the adherence trend stays legible at 320dp and 3.0x text',
      (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(320, 900);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // Eight weekly buckets so the trend draws its full, most-crowded row.
    final checkins = [
      for (var w = 0; w < 8; w++)
        Checkin(
          interventionId: 'a',
          date: DateTime(2026, 1, 5).add(Duration(days: w * 7)),
          result: CheckinResult.did,
        ),
    ];
    await tester.pumpWidget(_screen(checkins: checkins, textScale: 3.0));
    await tester.pumpAndSettle();

    // The trend sits below the tall 3× wall section, so the ListView leaves it
    // un-inflated; scroll the (unique) section header in to lay out the labels
    // just below it at 320 dp.
    await tester.scrollUntilVisible(
      find.text('Weekly adherence'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    // The '100%' / 'M/d' labels are FittedBox-scaled, so they render on one
    // line without overflowing the narrow columns.
    expect(find.textContaining('%'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping a set stone reveals the habit', (tester) async {
    await tester.pumpWidget(_screen(
      graduated: [_graduated('g1', at: DateTime(2026, 2, 1))],
    ));
    await tester.pumpAndSettle();

    final wall = tester.getRect(find.byKey(const Key('wall-canvas')));
    final columns = WallGeometry.columnsFor(wall.width);
    final placements = const WallLayout().pack(
      graduatedCount: 1,
      activeCount: 0,
      erodedIds: const [],
      coursesWidth: columns,
    );
    final stones = WallGeometry.stones(placements, wall.size, columns);
    await tester.tapAt(wall.topLeft + stones.first.cell.center);
    await tester.pumpAndSettle();

    // The reveal sheet — unique wording not shown in the list.
    expect(find.textContaining('Made automatic on'), findsOneWidget);
    expect(find.text('g1'), findsWidgets);
  });
}
