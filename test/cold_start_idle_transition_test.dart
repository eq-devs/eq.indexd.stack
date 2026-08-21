import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indexd_stack_dev/indexd_stack_dev.dart';

Finder _fadeOf(String label) => find.ancestor(
      of: find.text(label, skipOffstage: false),
      matching: find.byType(FadeTransition),
    );

Finder _scaleOf(String label) => find.ancestor(
      of: find.text(label, skipOffstage: false),
      matching: find.byType(ScaleTransition),
    );

Finder _slideOf(String label) => find.ancestor(
      of: find.text(label, skipOffstage: false),
      matching: find.byType(SlideTransition),
    );

double _opacity(WidgetTester tester, String label) =>
    tester.widget<FadeTransition>(_fadeOf(label)).opacity.value;

double _scale(WidgetTester tester, String label) =>
    tester.widget<ScaleTransition>(_scaleOf(label)).scale.value;

Offset _slide(WidgetTester tester, String label) =>
    tester.widget<SlideTransition>(_slideOf(label)).position.value;

Future<LazyStackController> _pump(
  WidgetTester tester,
  IndexdAnimationType animation,
) async {
  final controller = LazyStackController();
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: LazyLoadIndexedStack(
        controller: controller,
        animation: animation,
        children: const [
          Center(child: Text('P0')),
          Center(child: Text('P1')),
        ],
      ),
    ),
  );
  addTearDown(controller.dispose);
  return controller;
}

void main() {
  group('cold start: idle initial page renders fully settled, no switchTo', () {
    testWidgets('fade: initial page is fully opaque on first pump',
        (tester) async {
      await _pump(tester, IndexdAnimationType.fade);
      expect(_opacity(tester, 'P0'), moreOrLessEquals(1.0));
      expect(tester.takeException(), isNull);
    });

    testWidgets('fadeThrough: initial page is fully opaque and full scale',
        (tester) async {
      await _pump(tester, IndexdAnimationType.fadeThrough);
      expect(_opacity(tester, 'P0'), moreOrLessEquals(1.0));
      expect(_scale(tester, 'P0'), moreOrLessEquals(1.0));
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'sharedAxisHorizontal: initial page is fully opaque with zero slide',
        (tester) async {
      await _pump(tester, IndexdAnimationType.sharedAxisHorizontal);
      expect(_opacity(tester, 'P0'), moreOrLessEquals(1.0));
      final offset = _slide(tester, 'P0');
      expect(offset.dx, moreOrLessEquals(0.0));
      expect(offset.dy, moreOrLessEquals(0.0));
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'sharedAxisVertical: initial page is fully opaque with zero slide',
        (tester) async {
      await _pump(tester, IndexdAnimationType.sharedAxisVertical);
      expect(_opacity(tester, 'P0'), moreOrLessEquals(1.0));
      final offset = _slide(tester, 'P0');
      expect(offset.dx, moreOrLessEquals(0.0));
      expect(offset.dy, moreOrLessEquals(0.0));
      expect(tester.takeException(), isNull);
    });
  });

  group('didUpdateWidget: idle page re-settles when animation type changes',
      () {
    testWidgets('none -> fade while idle settles synchronously (no switchTo)',
        (tester) async {
      final controller = LazyStackController();
      Widget build(IndexdAnimationType animation) => Directionality(
            textDirection: TextDirection.ltr,
            child: LazyLoadIndexedStack(
              controller: controller,
              animation: animation,
              children: const [
                Center(child: Text('P0')),
                Center(child: Text('P1')),
              ],
            ),
          );

      await tester.pumpWidget(build(IndexdAnimationType.none));
      addTearDown(controller.dispose);

      await tester.pumpWidget(build(IndexdAnimationType.fade));

      expect(_opacity(tester, 'P0'), moreOrLessEquals(1.0));
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'fade -> sharedAxisHorizontal while idle re-settles (existing controller)',
        (tester) async {
      final controller = LazyStackController();
      Widget build(IndexdAnimationType animation) => Directionality(
            textDirection: TextDirection.ltr,
            child: LazyLoadIndexedStack(
              controller: controller,
              animation: animation,
              children: const [
                Center(child: Text('P0')),
                Center(child: Text('P1')),
              ],
            ),
          );

      await tester.pumpWidget(build(IndexdAnimationType.fade));
      addTearDown(controller.dispose);

      await tester.pumpWidget(build(IndexdAnimationType.sharedAxisHorizontal));

      expect(_opacity(tester, 'P0'), moreOrLessEquals(1.0));
      final offset = _slide(tester, 'P0');
      expect(offset.dx, moreOrLessEquals(0.0));
      expect(tester.takeException(), isNull);
    });
  });
}
