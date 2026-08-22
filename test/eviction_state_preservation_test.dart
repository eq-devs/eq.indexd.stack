import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indexd_stack_dev/indexd_stack_dev.dart';

/// Tracks State lifecycle so we can prove the outgoing page's State survives
/// the exit transition (no re-initState) even after the controller evicts it,
/// and is disposed exactly once when the transition completes.
class _LifecyclePage extends StatefulWidget {
  final String label;
  final Map<String, int> initCounts;
  final Map<String, int> disposeCounts;

  const _LifecyclePage({
    required this.label,
    required this.initCounts,
    required this.disposeCounts,
  });

  @override
  State<_LifecyclePage> createState() => _LifecyclePageState();
}

class _LifecyclePageState extends State<_LifecyclePage> {
  @override
  void initState() {
    super.initState();
    widget.initCounts.update(widget.label, (v) => v + 1, ifAbsent: () => 1);
  }

  @override
  void dispose() {
    widget.disposeCounts
        .update(widget.label, (v) => v + 1, ifAbsent: () => 1);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Center(child: Text(widget.label));
}

void main() {
  testWidgets(
    'evicted outgoing page keeps its State alive during the exit transition '
    'and is disposed exactly once after it completes',
    (tester) async {
      final initCounts = <String, int>{};
      final disposeCounts = <String, int>{};

      // disposeUnused + maxCachedPages: 1 evicts the outgoing page from the
      // controller the moment we switch away.
      final controller = LazyStackController(
        maxCachedPages: 1,
        disposeUnused: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LazyLoadIndexedStack(
              controller: controller,
              animation: IndexdAnimationType.fade,
              animationDuration: const Duration(milliseconds: 200),
              children: [
                _LifecyclePage(
                  label: 'A',
                  initCounts: initCounts,
                  disposeCounts: disposeCounts,
                ),
                _LifecyclePage(
                  label: 'B',
                  initCounts: initCounts,
                  disposeCounts: disposeCounts,
                ),
              ],
            ),
          ),
        ),
      );

      expect(initCounts['A'], 1);

      controller.switchTo(1);
      await tester.pump(); // start the transition
      await tester.pump(const Duration(milliseconds: 100)); // mid-transition

      // The controller evicted A, but the live State animates out — it must
      // not have been rebuilt from scratch (no second initState) nor disposed.
      expect(controller.isLoaded(0), isFalse);
      expect(initCounts['A'], 1,
          reason: 'outgoing page must not be re-created to animate out');
      expect(disposeCounts['A'], isNull,
          reason: 'outgoing page must stay alive while animating out');

      // Once the transition settles, the eviction takes effect.
      await tester.pumpAndSettle();
      expect(initCounts['A'], 1);
      expect(disposeCounts['A'], 1);
      expect(tester.takeException(), isNull);
    },
  );
}
