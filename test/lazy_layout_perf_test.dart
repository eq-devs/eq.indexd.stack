import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indexd_stack_dev/indexd_stack_dev.dart';

/// A child that counts how many times its [performLayout] actually runs.
/// Flutter's `RenderObject.layout()` early-returns (without calling
/// performLayout) when the child is clean and its constraints are unchanged,
/// so this counter reveals real layout work — not just `.layout()` calls.
class _CountingChild extends SingleChildRenderObjectWidget {
  final List<int> counts;
  final int slot;
  const _CountingChild({
    required this.counts,
    required this.slot,
    super.child,
  });

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderCounting(counts, slot);

  @override
  void updateRenderObject(BuildContext context, _RenderCounting renderObject) {
    renderObject
      ..counts = counts
      ..slot = slot;
  }
}

class _RenderCounting extends RenderProxyBox {
  _RenderCounting(this.counts, this.slot);
  List<int> counts;
  int slot;

  @override
  void performLayout() {
    counts[slot]++;
    super.performLayout();
  }
}

void main() {
  testWidgets(
    'switching tabs does not re-run performLayout on clean cached pages',
    (tester) async {
      final controller = LazyStackController(maxCachedPages: 3);
      final counts = [0, 0, 0];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LazyLoadIndexedStack(
              controller: controller,
              children: [
                for (var i = 0; i < 3; i++)
                  _CountingChild(
                    counts: counts,
                    slot: i,
                    child: const SizedBox.expand(),
                  ),
              ],
            ),
          ),
        ),
      );

      // Load all three pages so they are real, cached, attached subtrees.
      controller.switchTo(1, 3);
      await tester.pumpAndSettle();
      controller.switchTo(2, 3);
      await tester.pumpAndSettle();
      controller.switchTo(0, 3);
      await tester.pumpAndSettle();

      final before = List<int>.from(counts);

      // Switch tabs with no content or constraint changes.
      controller.switchTo(1, 3);
      await tester.pumpAndSettle();
      controller.switchTo(0, 3);
      await tester.pumpAndSettle();

      // Every child is clean and gets the same (tight) constraints, so
      // layout() early-returns for all of them — performLayout must not run
      // again. This proves laying out all attached children each pass adds no
      // real layout work for cached pages.
      expect(counts, equals(before),
          reason: 'cached pages should not re-run performLayout on a switch');
    },
  );
}
