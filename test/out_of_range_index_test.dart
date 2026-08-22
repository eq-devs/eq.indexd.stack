import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indexd_stack_dev/indexd_stack_dev.dart';

void main() {
  testWidgets(
    'switchTo with an index past children.length is a safe no-op '
    '(pageCount is synced automatically, no totalPages footgun anymore)',
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

      expect(controller.pageCount, 3);

      // Index 4 is out of range for 3 children; switchTo now rejects it
      // itself instead of relying on the caller to pass a matching
      // totalPages every call.
      controller.switchTo(4);
      await tester.pump();

      expect(controller.currentIndex, 0);
      expect(find.text('P0'), findsOneWidget);
      expect(tester.takeException(), isNull);
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

      controller.switchTo(2);
      await tester.pumpAndSettle();

      expect(find.text('P2'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'asserts if pageCount is set manually to a value larger than '
    'children.length, bypassing the automatic sync',
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

      // Simulates driving the controller without the widget keeping
      // pageCount honest — the widget-level assert is the last line of
      // defense for that case. ChangeNotifier.notifyListeners() catches
      // and reports listener exceptions itself rather than letting them
      // propagate to the caller, so the assertion surfaces via
      // FlutterError reporting (tester.takeException()), not as a
      // synchronous throw here.
      controller.pageCount = 5;
      controller.switchTo(4);

      expect(tester.takeException(), isAssertionError);
    },
  );
}
