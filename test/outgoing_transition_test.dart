import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indexd_stack_dev/indexd_stack_dev.dart';

void main() {
  testWidgets(
    'outgoing page stays in the tree and animates out even when the '
    'controller evicts it during a transition (disposeUnused)',
    (tester) async {
      // disposeUnused + maxCachedPages: 1 guarantees the outgoing page is
      // dropped from the controller the moment we switch away.
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
              children: const [
                Center(child: Text('A')),
                Center(child: Text('B')),
              ],
            ),
          ),
        ),
      );

      expect(find.text('A'), findsOneWidget);

      // Switch to B. The controller immediately evicts A, but it must remain
      // mounted while the fade transition runs so it can animate out.
      controller.switchTo(1, 2);
      await tester.pump(); // start the transition
      await tester.pump(const Duration(milliseconds: 100)); // mid-transition

      // The controller no longer caches A...
      expect(controller.isLoaded(0), isFalse);
      // ...but the outgoing page is still in the tree, fading out.
      expect(find.text('A'), findsOneWidget);
      expect(find.text('B'), findsOneWidget);

      // After the transition completes, the outgoing page is gone.
      await tester.pumpAndSettle();
      expect(find.text('A'), findsNothing);
      expect(find.text('B'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
