import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indexd_stack_dev/indexd_stack_dev.dart';

void main() {
  testWidgets('scaleIn scales and fades the incoming page', (tester) async {
    final controller = LazyStackController(maxCachedPages: 2);

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: LazyLoadIndexedStack(
          controller: controller,
          animation: IndexdAnimationType.scaleIn,
          animationDuration: const Duration(milliseconds: 200),
          scaleBegin: 0.95,
          children: const [
            Center(child: Text('A')),
            Center(child: Text('B')),
          ],
        ),
      ),
    );

    controller.switchTo(1, 2);
    await tester.pump();

    final incomingScaleFinder = find.ancestor(
      of: find.text('B'),
      matching: find.byType(ScaleTransition),
    );
    final initialScale =
        tester.widget<ScaleTransition>(incomingScaleFinder).scale.value;
    final incomingFadeFinder = find.ancestor(
      of: find.text('B'),
      matching: find.byType(FadeTransition),
    );
    final initialOpacity =
        tester.widget<FadeTransition>(incomingFadeFinder).opacity.value;

    // Incoming starts small and transparent, then settles.
    expect(initialScale, greaterThanOrEqualTo(0.95));
    expect(initialScale, lessThan(1.0));
    expect(incomingFadeFinder, findsOneWidget);
    expect(initialOpacity, moreOrLessEquals(0.0));

    await tester.pump(const Duration(milliseconds: 100));

    final midIncomingOpacity =
        tester.widget<FadeTransition>(incomingFadeFinder).opacity.value;
    final outgoingFadeFinder = find.ancestor(
      of: find.text('A'),
      matching: find.byType(FadeTransition),
    );
    final midOutgoingOpacity =
        tester.widget<FadeTransition>(outgoingFadeFinder).opacity.value;

    // Mid-flight: a clean cross-dissolve — the two opacities are complements
    // (constant total luminance, no Material "dip").
    expect(midIncomingOpacity, greaterThan(0.0));
    expect(midIncomingOpacity, lessThan(1.0));
    expect(midOutgoingOpacity, greaterThan(0.0));
    expect(midOutgoingOpacity, lessThan(1.0));
    expect(midIncomingOpacity + midOutgoingOpacity, moreOrLessEquals(1.0));

    await tester.pumpAndSettle();

    final settledScale =
        tester.widget<ScaleTransition>(incomingScaleFinder).scale.value;
    final settledOpacity =
        tester.widget<FadeTransition>(incomingFadeFinder).opacity.value;

    expect(settledScale, moreOrLessEquals(1.0));
    expect(settledOpacity, moreOrLessEquals(1.0));
    expect(tester.takeException(), isNull);
  });

  test('scaleBegin asserts the supported range', () {
    final controller = LazyStackController();

    expect(
      () => LazyLoadIndexedStack(
        controller: controller,
        scaleBegin: 0.94,
        children: const [SizedBox()],
      ),
      throwsAssertionError,
    );
    expect(
      () => LazyLoadIndexedStack(
        controller: controller,
        scaleBegin: 1.0,
        children: const [SizedBox()],
      ),
      throwsAssertionError,
    );
    expect(
      () => LazyLoadIndexedStack(
        controller: controller,
        scaleBegin: 0.95,
        children: const [SizedBox()],
      ),
      returnsNormally,
    );
    expect(
      () => LazyLoadIndexedStack(
        controller: controller,
        scaleBegin: 0.99,
        children: const [SizedBox()],
      ),
      returnsNormally,
    );

    controller.dispose();
  });

  test('scaleBegin defaults to a subtle scale offset', () {
    final controller = LazyStackController();

    final stack = LazyLoadIndexedStack(
      controller: controller,
      children: const [SizedBox()],
    );

    expect(stack.scaleBegin, 0.98);

    controller.dispose();
  });
}
