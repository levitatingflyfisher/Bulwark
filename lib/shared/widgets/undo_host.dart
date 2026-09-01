import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openhearth_design/openhearth_design.dart';

// The fleet ruling on undo, as Bulwark applies it: a change a person makes on
// purpose (activate, queue, set aside, set into the wall, repoint) happens at
// once, with no "are you sure?", and offers Undo through the bar below. The
// offer never times out: it stays until the person taps Undo, dismisses it,
// or makes another change. Erase all data is the one act that asks first.

/// The one Undo offer for the whole app.
///
/// A change often leaves the screen it was made on (the detail page pops,
/// graduation takes the card off Today), so a bar placed on that screen would
/// vanish with it. The controller lives as long as the app and [UndoHost]
/// shows its bar below every screen.
///
/// Read it BEFORE awaiting the change: the widget that asked may leave the
/// tree with it, and a disposed widget's `ref` throws.
final undoControllerProvider = Provider<OhUndoController>((ref) {
  final controller = OhUndoController();
  ref.onDispose(controller.dispose);
  return controller;
});

/// Wraps the app's navigator (from `MaterialApp.builder`) and keeps the
/// pending Undo bar pinned under it. It never times out.
class UndoHost extends ConsumerStatefulWidget {
  const UndoHost({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<UndoHost> createState() => _UndoHostState();
}

class _UndoHostState extends ConsumerState<UndoHost> {
  // The bar's buttons carry tooltips, which need an Overlay; the navigator's
  // own overlay sits below this widget, so the host brings one.
  late final OverlayEntry _entry = OverlayEntry(builder: _buildFrame);

  @override
  void didUpdateWidget(UndoHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.child != widget.child) _entry.markNeedsBuild();
  }

  Widget _buildFrame(BuildContext context) {
    final controller = ref.read(undoControllerProvider);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final showing = controller.pending != null;
        return Column(
          children: [
            Expanded(
              // While the bar shows it takes the bottom safe area, so the
              // screen above does not pad for the gesture bar a second time.
              // The tree shape stays the same either way, so the navigator
              // keeps its state.
              child: MediaQuery.removePadding(
                context: context,
                removeBottom: showing,
                child: widget.child,
              ),
            ),
            OhUndoBar(controller: controller, commitOnDispose: false),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Overlay(initialEntries: [_entry]);
  }
}
