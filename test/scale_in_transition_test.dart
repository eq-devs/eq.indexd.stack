import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indexd_stack_dev/indexd_stack_dev.dart';

const _kScaleBegin = 0.992;
const _kDuration = Duration(milliseconds: 320);

Finder _scaleOf(String label) => find.ancestor(
      of: find.text(label, skipOffstage: false),
      matching: find.byType(ScaleTransition),
    );

Finder _fadeOf(String label) => find.ancestor(
      of: find.text(label, skipOffstage: false),
      matching: find.byType(FadeTransition),
    );

double _scale(WidgetTester tester, String label) =>
    tester.widget<ScaleTransition>(_scaleOf(label)).scale.value;

double _opacity(WidgetTester tester, String label) =>
    tester.widget<FadeTransition>(_fadeOf(label)).opacity.value;

Finder _tickerModeOf(String label) => find.ancestor(
      of: find.text(label, skipOffstage: false),
      matching: find.byType(TickerMode),
    );

bool _tickerEnabled(WidgetTester tester, String label) {
  final element = tester.element(find.text(label, skipOffstage: false));
  TickerMode? mode;
  element.visitAncestorElements((ancestor) {
    final widget = ancestor.widget;
    if (widget is TickerMode) {
      mode = widget;
      return false;
    }
    return true;
  });
  return mode!.enabled;
}

Future<LazyStackController> _pumpScaleIn(
  WidgetTester tester, {
  int pageCount = 3,
  int maxCachedPages = 3,
  bool disposeUnused = false,
  Duration duration = _kDuration,
  IndexdAnimationType animation = IndexdAnimationType.scaleIn,
}) async {
  final controller = LazyStackController(
    maxCachedPages: maxCachedPages,
    disposeUnused: disposeUnused,
  );

  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: LazyLoadIndexedStack(
        controller: controller,
        animation: animation,
        animationDuration: duration,
        children: [
          for (var i = 0; i < pageCount; i++)
            Center(child: Text('P$i')),
        ],
      ),
    ),
  );

  addTearDown(controller.dispose);
  return controller;
}

void main() {
  group('scaleIn start / mid / end', () {
    testWidgets('incoming starts at 0.992 / 0 and outgoing at 1.0 / 1.0',
        (tester) async {
      final controller = await _pumpScaleIn(tester, pageCount: 2);

      controller.switchTo(1, 2);
      await tester.pump();

      expect(_scale(tester, 'P1'), moreOrLessEquals(_kScaleBegin));
      expect(_opacity(tester, 'P1'), moreOrLessEquals(0.0));
      expect(_scale(tester, 'P0'), moreOrLessEquals(1.0));
      expect(_opacity(tester, 'P0'), moreOrLessEquals(1.0));
    });

    testWidgets('mid-flight opacities are exact complements', (tester) async {
      final controller = await _pumpScaleIn(tester, pageCount: 2);

      controller.switchTo(1, 2);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 160));

      final inOp = _opacity(tester, 'P1');
      final outOp = _opacity(tester, 'P0');

      expect(inOp, greaterThan(0.0));
      expect(inOp, lessThan(1.0));
      expect(outOp, greaterThan(0.0));
      expect(outOp, lessThan(1.0));
      expect(inOp + outOp, moreOrLessEquals(1.0));
    });

    testWidgets('mid-flight both pages scale toward each other', (tester) async {
      final controller = await _pumpScaleIn(tester, pageCount: 2);

      controller.switchTo(1, 2);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 160));

      final inScale = _scale(tester, 'P1');
      final outScale = _scale(tester, 'P0');

      expect(inScale, greaterThan(_kScaleBegin));
      expect(inScale, lessThan(1.0));
      expect(outScale, lessThan(1.0));
      expect(outScale, greaterThan(_kScaleBegin));
      expect(inScale + outScale, moreOrLessEquals(1.0 + _kScaleBegin));
    });

    testWidgets('fade and scale share the same progress', (tester) async {
      final controller = await _pumpScaleIn(tester, pageCount: 2);

      controller.switchTo(1, 2);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 160));

      final inOp = _opacity(tester, 'P1');
      final inScale = _scale(tester, 'P1');
      final scaleProgress = (inScale - _kScaleBegin) / (1.0 - _kScaleBegin);

      expect(scaleProgress, moreOrLessEquals(inOp, epsilon: 0.001));
    });

    testWidgets('settles to full scale and opacity on incoming page',
        (tester) async {
      final controller = await _pumpScaleIn(tester, pageCount: 2);

      controller.switchTo(1, 2);
      await tester.pumpAndSettle();

      expect(find.text('P1'), findsOneWidget);
      expect(find.byType(ScaleTransition), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('scaleIn direction and repeats', () {
    testWidgets('backward switch uses the same quiet settle', (tester) async {
      final controller = await _pumpScaleIn(tester, pageCount: 2);

      controller.switchTo(1, 2);
      await tester.pumpAndSettle();

      controller.switchTo(0, 2);
      await tester.pump();

      expect(_scale(tester, 'P0'), moreOrLessEquals(_kScaleBegin));
      expect(_opacity(tester, 'P0'), moreOrLessEquals(0.0));
      expect(_scale(tester, 'P1'), moreOrLessEquals(1.0));
      expect(_opacity(tester, 'P1'), moreOrLessEquals(1.0));

      await tester.pump(const Duration(milliseconds: 160));
      expect(
        _opacity(tester, 'P0') + _opacity(tester, 'P1'),
        moreOrLessEquals(1.0),
      );

      await tester.pumpAndSettle();
      expect(find.text('P0'), findsOneWidget);
      expect(find.byType(ScaleTransition), findsNothing);
    });

    testWidgets('rapid successive switches settle without errors',
        (tester) async {
      final controller = await _pumpScaleIn(tester, pageCount: 3);

      controller.switchTo(1, 3);
      await tester.pump();
      controller.switchTo(2, 3);
      await tester.pump();
      controller.switchTo(0, 3);
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('P0'), findsOneWidget);
      expect(find.byType(ScaleTransition), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('multiple full switches keep settling cleanly', (tester) async {
      final controller = await _pumpScaleIn(tester, pageCount: 3);

      for (final target in [1, 2, 0, 1]) {
        controller.switchTo(target, 3);
        await tester.pumpAndSettle();
        expect(find.text('P$target'), findsOneWidget);
        expect(find.byType(ScaleTransition), findsNothing);
      }

      expect(tester.takeException(), isNull);
    });
  });

  group('scaleIn tree / participation', () {
    testWidgets('does not use SlideTransition', (tester) async {
      final controller = await _pumpScaleIn(tester, pageCount: 2);

      controller.switchTo(1, 2);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(SlideTransition), findsNothing);
      expect(find.byType(ScaleTransition), findsWidgets);
      expect(find.byType(FadeTransition), findsWidgets);
    });

    testWidgets('non-participating cached page stays inert at 1.0',
        (tester) async {
      final controller = await _pumpScaleIn(
        tester,
        pageCount: 3,
        maxCachedPages: 3,
      );

      controller.switchTo(2, 3);
      await tester.pumpAndSettle();
      controller.switchTo(0, 3);
      await tester.pumpAndSettle();

      controller.switchTo(1, 3);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 160));

      expect(controller.isLoaded(2), isTrue);
      expect(find.text('P2', skipOffstage: false), findsOneWidget);
      expect(_scaleOf('P2'), findsNothing);
    });

    testWidgets(
      'outgoing page still scales out when controller evicts it mid-transition',
      (tester) async {
        final controller = await _pumpScaleIn(
          tester,
          pageCount: 2,
          maxCachedPages: 1,
          disposeUnused: true,
        );

        controller.switchTo(1, 2);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 160));

        expect(controller.isLoaded(0), isFalse);
        expect(find.text('P0'), findsOneWidget);
        expect(_scale(tester, 'P0'), lessThan(1.0));
        expect(_opacity(tester, 'P0'), lessThan(1.0));
        expect(_opacity(tester, 'P0') + _opacity(tester, 'P1'),
            moreOrLessEquals(1.0));

        await tester.pumpAndSettle();
        expect(find.text('P0'), findsNothing);
        expect(find.text('P1'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('ScaleTransition is centered', (tester) async {
      final controller = await _pumpScaleIn(tester, pageCount: 2);

      controller.switchTo(1, 2);
      await tester.pump();

      final scale = tester.widget<ScaleTransition>(_scaleOf('P1'));
      expect(scale.alignment, Alignment.center);
    });
  });

  group('scaleIn ticker mode', () {
    testWidgets('outgoing page is frozen the instant the transition starts',
        (tester) async {
      final controller = await _pumpScaleIn(tester, pageCount: 2);

      controller.switchTo(1, 2);
      await tester.pump();

      expect(_tickerEnabled(tester, 'P1'), isTrue);
      expect(_tickerEnabled(tester, 'P0'), isFalse);
    });

    testWidgets('outgoing page stays frozen for the rest of the transition',
        (tester) async {
      final controller = await _pumpScaleIn(tester, pageCount: 2);

      controller.switchTo(1, 2);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 160));

      expect(_tickerEnabled(tester, 'P1'), isTrue);
      expect(_tickerEnabled(tester, 'P0'), isFalse);
    });

    testWidgets(
        'active idle page keeps ticking once settled; cached page stays frozen',
        (tester) async {
      final controller = await _pumpScaleIn(tester, pageCount: 2);

      controller.switchTo(1, 2);
      await tester.pumpAndSettle();

      expect(_tickerEnabled(tester, 'P1'), isTrue);
      expect(_tickerEnabled(tester, 'P0'), isFalse);
    });
  });

  group('scaleIn config and animation swaps', () {
    testWidgets('respects a custom animationDuration', (tester) async {
      final controller = await _pumpScaleIn(
        tester,
        pageCount: 2,
        duration: const Duration(milliseconds: 100),
      );

      controller.switchTo(1, 2);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(_opacity(tester, 'P1'), greaterThan(0.0));
      expect(_opacity(tester, 'P1'), lessThan(1.0));

      await tester.pump(const Duration(milliseconds: 60));
      expect(find.text('P1'), findsOneWidget);
    });

    testWidgets('switching into scaleIn from fade works', (tester) async {
      final controller = LazyStackController(maxCachedPages: 2);

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: LazyLoadIndexedStack(
            controller: controller,
            animation: IndexdAnimationType.fade,
            animationDuration: _kDuration,
            children: const [
              Center(child: Text('P0')),
              Center(child: Text('P1')),
            ],
          ),
        ),
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: LazyLoadIndexedStack(
            controller: controller,
            animation: IndexdAnimationType.scaleIn,
            animationDuration: _kDuration,
            children: const [
              Center(child: Text('P0')),
              Center(child: Text('P1')),
            ],
          ),
        ),
      );

      controller.switchTo(1, 2);
      await tester.pump();

      expect(_scale(tester, 'P1'), moreOrLessEquals(_kScaleBegin));
      expect(_opacity(tester, 'P1'), moreOrLessEquals(0.0));

      await tester.pumpAndSettle();
      expect(find.text('P1'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('switching from scaleIn to none stops allocating transitions',
        (tester) async {
      final controller = LazyStackController(maxCachedPages: 2);

      Widget build(IndexdAnimationType animation) {
        return Directionality(
          textDirection: TextDirection.ltr,
          child: LazyLoadIndexedStack(
            controller: controller,
            animation: animation,
            animationDuration: _kDuration,
            children: const [
              Center(child: Text('P0')),
              Center(child: Text('P1')),
            ],
          ),
        );
      }

      await tester.pumpWidget(build(IndexdAnimationType.scaleIn));
      addTearDown(controller.dispose);

      controller.switchTo(1, 2);
      await tester.pumpAndSettle();

      await tester.pumpWidget(build(IndexdAnimationType.none));
      controller.switchTo(0, 2);
      await tester.pump();

      expect(find.byType(ScaleTransition), findsNothing);
      expect(find.byType(FadeTransition), findsNothing);
      expect(find.text('P0'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('scaleIn defaults duration to kScaleInDuration when omitted',
        (tester) async {
      final controller = LazyStackController();
      final stack = LazyLoadIndexedStack(
        controller: controller,
        animation: IndexdAnimationType.scaleIn,
        children: const [SizedBox()],
      );

      expect(stack.animation, IndexdAnimationType.scaleIn);
      expect(stack.animationDuration, isNull);
      expect(kScaleInDuration, const Duration(milliseconds: 320));
      controller.dispose();
    });

    testWidgets('scaleIn opacity/scale track scaleIn formulas at sample times',
        (tester) async {
      final controller = await _pumpScaleIn(tester, pageCount: 2);

      double curved(double t) => const Cubic(0.22, 1.0, 0.36, 1.0).transform(t);

      void expectAt(double t) {
        final c = curved(t);
        expect(_opacity(tester, 'P1'), moreOrLessEquals(c, epsilon: 0.02));
        expect(_opacity(tester, 'P0'), moreOrLessEquals(1 - c, epsilon: 0.02));
        expect(
          _scale(tester, 'P1'),
          moreOrLessEquals(
            _kScaleBegin + (1.0 - _kScaleBegin) * c,
            epsilon: 0.002,
          ),
        );
        expect(
          _scale(tester, 'P0'),
          moreOrLessEquals(
            1.0 + (_kScaleBegin - 1.0) * c,
            epsilon: 0.002,
          ),
        );
      }

      controller.switchTo(1, 2);
      await tester.pump(); // t ≈ 0
      expectAt(0.0);

      await tester.pump(const Duration(milliseconds: 80)); // 0.25 of 320
      expectAt(0.25);

      await tester.pump(const Duration(milliseconds: 80)); // 0.5
      expectAt(0.5);

      await tester.pump(const Duration(milliseconds: 80)); // 0.75
      expectAt(0.75);

      await tester.pump(const Duration(milliseconds: 79)); // ~1.0, still in-flight
      expectAt(0.996875);
    });
  });
}
