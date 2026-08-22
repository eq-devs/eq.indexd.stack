import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indexd_stack_dev/indexd_stack_dev.dart';

void main() {
  testWidgets(
    'asserts when controller.switchTo is called with a totalPages that '
    'does not match children.length, instead of silently going blank',
    (tester) async {
      final controller = LazyStackController();

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: LazyLoadIndexedStack(
            controller: controller,
            children: const [
              Center(child: Text('P0')),
              Center(child: Text('P1')),
              Center(child: Text('P2')),
            ],
          ),
        ),
      );
      addTearDown(controller.dispose);

      // totalPages (5) does not match children.length (3): a stale or
      // miscalculated constant, or a tab count that shrank at runtime.
      // ChangeNotifier.notifyListeners() catches and reports listener
      // exceptions itself rather than letting them propagate to the
      // caller, so the assertion surfaces via FlutterError reporting
      // (tester.takeException()), not as a synchronous throw here.
      controller.switchTo(4, 5);

      expect(tester.takeException(), isAssertionError);
    },
  );

  testWidgets(
    'does not assert for a controller.currentIndex within children.length',
    (tester) async {
      final controller = LazyStackController();

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: LazyLoadIndexedStack(
            controller: controller,
            children: const [
              Center(child: Text('P0')),
              Center(child: Text('P1')),
              Center(child: Text('P2')),
            ],
          ),
        ),
      );
      addTearDown(controller.dispose);

      controller.switchTo(2, 3);
      await tester.pumpAndSettle();

      expect(find.text('P2'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
