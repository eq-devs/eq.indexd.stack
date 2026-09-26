import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indexd_stack_dev/indexd_stack_dev.dart';
import 'package:indexd_stack_dev/src/rendering/lazy_render_stack.dart';

/// Counts how many times each page's build method runs.
class _BuildCounter extends StatelessWidget {
  final List<int> builds;
  final int slot;
  const _BuildCounter(this.builds, this.slot);

  @override
  Widget build(BuildContext context) {
    builds[slot]++;
    return Center(child: Text('P$slot'));
  }
}

/// Counts how many times each page's performLayout actually runs.
class _LayoutCounter extends SingleChildRenderObjectWidget {
  final List<int> counts;
  final int slot;
  const _LayoutCounter(this.counts, this.slot, {super.child});

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderLayoutCounter(counts, slot);
}

class _RenderLayoutCounter extends RenderProxyBox {
  _RenderLayoutCounter(this.counts, this.slot);
  final List<int> counts;
  final int slot;

  @override
  void performLayout() {
    counts[slot]++;
    super.performLayout();
  }
}

/// Counts initState calls so we can tell whether a page's State survived.
class _StatefulPage extends StatefulWidget {
  final String label;
  final Map<String, int> inits;
  const _StatefulPage(this.label, this.inits);

  @override
  State<_StatefulPage> createState() => _StatefulPageState();
}

class _StatefulPageState extends State<_StatefulPage> {
  @override
  void initState() {
    super.initState();
    widget.inits.update(widget.label, (v) => v + 1, ifAbsent: () => 1);
  }

  @override
  Widget build(BuildContext context) => Center(child: Text(widget.label));
}

Widget _app(Widget child) =>
    Directionality(textDirection: TextDirection.ltr, child: child);

void main() {
  group('preloads requested alongside a switch', () {
    testWidgets('are built a frame after the switch (animation: none)',
        (tester) async {
      final builds = [0, 0, 0];
      final controller = LazyStackController(maxCachedPages: 3);
      addTearDown(controller.dispose);

      await tester.pumpWidget(_app(LazyLoadIndexedStack(
        controller: controller,
        children: [for (var i = 0; i < 3; i++) _BuildCounter(builds, i)],
      )));

      controller.switchTo(1);
      controller.preloadAdjacentPages();
      await tester.pump();

      expect(builds[1], 1, reason: 'the new page builds in the switch frame');
      expect(builds[2], 0, reason: 'the preload must not share that frame');
      expect(controller.isLoaded(2), isTrue);

      await tester.pump();
      expect(builds[2], 1, reason: 'the preload builds on the next frame');
    });

    testWidgets('are built after the transition finishes (scaleIn)',
        (tester) async {
      final builds = [0, 0, 0];
      final controller = LazyStackController(maxCachedPages: 3);
      addTearDown(controller.dispose);

      await tester.pumpWidget(_app(LazyLoadIndexedStack(
        controller: controller,
        animation: IndexdAnimationType.scaleIn,
        children: [for (var i = 0; i < 3; i++) _BuildCounter(builds, i)],
      )));

      controller.switchTo(1);
      controller.preloadAdjacentPages();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 160));
      expect(builds[2], 0, reason: 'no preload build mid-transition');

      await tester.pumpAndSettle();
      expect(builds[2], 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('outside a switch are still built immediately', (tester) async {
      final builds = [0, 0, 0];
      final controller = LazyStackController(maxCachedPages: 3);
      addTearDown(controller.dispose);

      await tester.pumpWidget(_app(LazyLoadIndexedStack(
        controller: controller,
        children: [for (var i = 0; i < 3; i++) _BuildCounter(builds, i)],
      )));

      controller.preloadPage(2);
      await tester.pump();
      expect(builds[2], 1);
    });
  });

  testWidgets('hidden cached pages are not re-laid out while the stack resizes',
      (tester) async {
    final counts = [0, 0, 0];
    final controller = LazyStackController(maxCachedPages: 3);
    addTearDown(controller.dispose);
    final height = ValueNotifier<double>(400);
    addTearDown(height.dispose);

    await tester.pumpWidget(_app(Align(
      alignment: Alignment.topLeft,
      child: ValueListenableBuilder<double>(
        valueListenable: height,
        builder: (context, h, child) =>
            SizedBox(width: 300, height: h, child: child),
        child: LazyLoadIndexedStack(
          controller: controller,
          children: [
            for (var i = 0; i < 3; i++)
              _LayoutCounter(counts, i,
                  child: SizedBox.expand(key: ValueKey('page$i'))),
          ],
        ),
      ),
    )));

    controller.switchTo(1);
    await tester.pumpAndSettle();
    controller.switchTo(2);
    await tester.pumpAndSettle();
    controller.switchTo(0);
    await tester.pumpAndSettle();

    final before = List<int>.from(counts);

    // Simulate a keyboard animation: the stack shrinks over several frames.
    for (var h = 380.0; h >= 300; h -= 20) {
      height.value = h;
      await tester.pump();
    }

    expect(counts[0], before[0] + 5, reason: 'active page follows the resize');
    expect(counts[1], before[1], reason: 'hidden page keeps old layout');
    expect(counts[2], before[2], reason: 'hidden page keeps old layout');

    // A hidden page picks up the current size the moment it is shown.
    controller.switchTo(1);
    await tester.pump();
    expect(tester.getSize(find.byKey(const ValueKey('page1'))),
        const Size(300, 300));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a controller notification that changes nothing does not rebuild',
      (tester) async {
    final controller = LazyStackController(maxCachedPages: 3);
    addTearDown(controller.dispose);

    await tester.pumpWidget(_app(LazyLoadIndexedStack(
      controller: controller,
      children: const [Text('P0'), Text('P1')],
    )));

    Widget stackWidget() => tester.element(find.byType(LazyRenderStack)).widget;
    final before = stackWidget();

    // Only page 0 is loaded, so reset() leaves the cache as it was.
    controller.reset();
    await tester.pump();
    expect(identical(stackWidget(), before), isTrue);

    // A notification that does change the cache still rebuilds.
    controller.preloadPage(1);
    await tester.pump();
    expect(identical(stackWidget(), before), isFalse);
    expect(find.text('P1', skipOffstage: false), findsOneWidget);
  });

  testWidgets('taps reach only the active page after switching around',
      (tester) async {
    final taps = [0, 0, 0];
    final controller = LazyStackController(maxCachedPages: 3);
    addTearDown(controller.dispose);

    await tester.pumpWidget(_app(LazyLoadIndexedStack(
      controller: controller,
      children: [
        for (var i = 0; i < 3; i++)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => taps[i]++,
            child: const SizedBox.expand(),
          ),
      ],
    )));

    for (final i in [1, 2, 0, 2]) {
      controller.switchTo(i);
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(10, 10));
    }

    expect(taps, [1, 1, 2]);
  });

  group('clipping', () {
    Iterable<ClipRectLayer> clipLayers(WidgetTester tester) =>
        tester.layers.whereType<ClipRectLayer>();

    testWidgets('no clip layer while idle with StackFit.expand',
        (tester) async {
      final controller = LazyStackController(maxCachedPages: 3);
      addTearDown(controller.dispose);

      await tester.pumpWidget(_app(LazyLoadIndexedStack(
        controller: controller,
        animation: IndexdAnimationType.sharedAxisHorizontal,
        children: const [Text('P0'), Text('P1')],
      )));

      expect(clipLayers(tester), isEmpty);

      controller.switchTo(1);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(clipLayers(tester), isNotEmpty,
          reason: 'a sliding transition can overflow, so it is clipped');

      await tester.pumpAndSettle();
      expect(clipLayers(tester), isEmpty);
    });
  });

  testWidgets('changing the animation type keeps every cached page State',
      (tester) async {
    final inits = <String, int>{};
    final controller = LazyStackController(maxCachedPages: 3);
    addTearDown(controller.dispose);

    Widget build(IndexdAnimationType animation) => _app(LazyLoadIndexedStack(
          controller: controller,
          animation: animation,
          children: [
            _StatefulPage('A', inits),
            _StatefulPage('B', inits),
          ],
        ));

    await tester.pumpWidget(build(IndexdAnimationType.none));
    controller.switchTo(1);
    await tester.pumpAndSettle();
    expect(inits, {'A': 1, 'B': 1});

    for (final type in [
      IndexdAnimationType.scaleIn,
      IndexdAnimationType.fade,
      IndexdAnimationType.sharedAxisVertical,
      IndexdAnimationType.none,
    ]) {
      await tester.pumpWidget(build(type));
      await tester.pumpAndSettle();
      expect(inits, {'A': 1, 'B': 1},
          reason: 'switching to $type must not recreate cached pages');
    }
    expect(tester.takeException(), isNull);
  });
}
