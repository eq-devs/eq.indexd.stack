import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indexd_stack_dev/indexd_stack_dev.dart';

void main() {
  testWidgets(
    'relayout of a hidden cached page does not dirty the stack '
    '(hidden children are relayout boundaries)',
    (tester) async {
      final controller = LazyStackController(maxCachedPages: 3);

      // Center gives the stack loose constraints — the case where, without
      // parentUsesSize: false, hidden children could never become relayout
      // boundaries and would propagate their relayout into the stack.
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: LazyLoadIndexedStack(
              controller: controller,
              children: const [
                SizedBox(key: ValueKey('page0'), width: 100, height: 100),
                SizedBox(key: ValueKey('page1'), width: 100, height: 100),
              ],
            ),
          ),
        ),
      );

      // Cache page 0, then hide it behind page 1.
      controller.switchTo(1, 2);
      await tester.pumpAndSettle();

      final stackRender =
          tester.renderObject(find.byType(LazyLoadIndexedStack));
      final hiddenRender =
          tester.renderObject(find.byKey(const ValueKey('page0')));

      expect(stackRender.debugNeedsLayout, isFalse);

      // Simulate the hidden page changing size (async data, growing list…).
      hiddenRender.markNeedsLayout();

      expect(hiddenRender.debugNeedsLayout, isTrue);
      expect(stackRender.debugNeedsLayout, isFalse,
          reason: 'a hidden page relayout must stop at its own boundary '
              'instead of relaying out the whole stack');

      await tester.pump();
      expect(tester.takeException(), isNull);

      // The hidden page still works when it becomes active again.
      controller.switchTo(0, 2);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byKey(const ValueKey('page0'))),
          const Size(100, 100));
    },
  );
}
