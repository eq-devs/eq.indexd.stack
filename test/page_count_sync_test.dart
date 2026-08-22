import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indexd_stack_dev/indexd_stack_dev.dart';

void main() {
  testWidgets('pageCount is synced from children.length on mount',
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
  });

  testWidgets('pageCount re-syncs when children.length changes at runtime',
      (tester) async {
    final controller = LazyStackController();

    Widget build(int childCount) => Directionality(
          textDirection: TextDirection.ltr,
          child: LazyLoadIndexedStack(
            controller: controller,
            children: [
              for (var i = 0; i < childCount; i++) Center(child: Text('P$i')),
            ],
          ),
        );

    await tester.pumpWidget(build(4));
    addTearDown(controller.dispose);
    expect(controller.pageCount, 4);

    // A tab gets removed (e.g. feature-flagged off) at runtime.
    await tester.pumpWidget(build(2));
    expect(controller.pageCount, 2);

    // The now out-of-range index is safely rejected, not silently accepted.
    controller.switchTo(3);
    await tester.pump();
    expect(controller.currentIndex, 0);
    expect(tester.takeException(), isNull);

    // A previously-unreachable index becomes valid again once children
    // grows back.
    await tester.pumpWidget(build(4));
    expect(controller.pageCount, 4);
    controller.switchTo(3);
    await tester.pumpAndSettle();
    expect(controller.currentIndex, 3);
    expect(find.text('P3'), findsOneWidget);
  });

  testWidgets('pageCount is synced onto a newly-swapped controller',
      (tester) async {
    final controllerA = LazyStackController();
    final controllerB = LazyStackController();

    Widget build(LazyStackController controller) => Directionality(
          textDirection: TextDirection.ltr,
          child: LazyLoadIndexedStack(
            controller: controller,
            children: const [
              Center(child: Text('P0')),
              Center(child: Text('P1')),
              Center(child: Text('P2')),
            ],
          ),
        );

    await tester.pumpWidget(build(controllerA));
    addTearDown(controllerA.dispose);
    expect(controllerA.pageCount, 3);
    expect(controllerB.pageCount, isNull);

    await tester.pumpWidget(build(controllerB));
    addTearDown(controllerB.dispose);

    expect(controllerB.pageCount, 3);
  });
}
