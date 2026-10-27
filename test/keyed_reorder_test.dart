import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indexd_stack_dev/indexd_stack_dev.dart';

class _Page extends StatefulWidget {
  const _Page(this.label, this.inits, {super.key});
  final String label;
  final Map<String, int> inits;

  @override
  State<_Page> createState() => _PageState();
}

class _PageState extends State<_Page> {
  @override
  void initState() {
    super.initState();
    widget.inits.update(widget.label, (v) => v + 1, ifAbsent: () => 1);
  }

  @override
  Widget build(BuildContext context) => Text(widget.label);
}

Widget _app(Widget child) =>
    Directionality(textDirection: TextDirection.ltr, child: child);

void main() {
  for (final animation in [
    IndexdAnimationType.none,
    IndexdAnimationType.fade
  ]) {
    testWidgets('keyed pages keep their State across a reorder ($animation)',
        (tester) async {
      final inits = <String, int>{};
      final controller = LazyStackController(maxCachedPages: 3);
      addTearDown(controller.dispose);
      final a = _Page('A', inits, key: const ValueKey('A'));
      final b = _Page('B', inits, key: const ValueKey('B'));

      await tester.pumpWidget(_app(LazyLoadIndexedStack(
        controller: controller,
        animation: animation,
        children: [a, b],
      )));
      controller.switchTo(1);
      await tester.pumpAndSettle();

      await tester.pumpWidget(_app(LazyLoadIndexedStack(
        controller: controller,
        animation: animation,
        children: [b, a],
      )));
      await tester.pumpAndSettle();

      expect(inits, {'A': 1, 'B': 1});
      // Index 1 now holds A.
      expect(find.text('A').hitTestable(), findsOneWidget);
    });
  }

  testWidgets('duplicate page keys fall back to the index instead of throwing',
      (tester) async {
    final controller = LazyStackController(preloadIndexes: [1]);
    addTearDown(controller.dispose);

    await tester.pumpWidget(_app(LazyLoadIndexedStack(
      controller: controller,
      children: const [
        Text('X', key: ValueKey('dup')),
        Text('Y', key: ValueKey('dup')),
      ],
    )));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Y', skipOffstage: false), findsOneWidget);
  });
}
