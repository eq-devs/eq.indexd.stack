import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indexd_stack_dev/indexd_stack_dev.dart';

Widget _app(Widget child) =>
    Directionality(textDirection: TextDirection.ltr, child: child);

void main() {
  testWidgets('IntrinsicHeight sizes the stack to the active page',
      (tester) async {
    final controller = LazyStackController();
    addTearDown(controller.dispose);
    final key = GlobalKey();

    await tester.pumpWidget(_app(Center(
      child: IntrinsicHeight(
        child: LazyLoadIndexedStack(
          key: key,
          controller: controller,
          fit: StackFit.loose,
          children: const [
            SizedBox(width: 50, height: 40),
            SizedBox(width: 50, height: 80),
          ],
        ),
      ),
    )));
    final box = key.currentContext!.findRenderObject()! as RenderBox;
    expect(box.size.height, 40);

    controller.switchTo(1);
    await tester.pumpAndSettle();
    expect(box.size.height, 80);
  });

  testWidgets('getDryLayout matches performLayout and does not throw',
      (tester) async {
    final controller = LazyStackController();
    addTearDown(controller.dispose);
    final looseKey = GlobalKey();
    final expandKey = GlobalKey();
    const constraints = BoxConstraints(maxWidth: 300, maxHeight: 300);

    await tester.pumpWidget(_app(Column(children: [
      ConstrainedBox(
        constraints: constraints,
        child: LazyLoadIndexedStack(
          key: looseKey,
          controller: controller,
          fit: StackFit.loose,
          children: const [SizedBox(width: 50, height: 40)],
        ),
      ),
      ConstrainedBox(
        constraints: constraints,
        child: LazyLoadIndexedStack(
          key: expandKey,
          controller: LazyStackController(),
          children: const [SizedBox(width: 50, height: 40)],
        ),
      ),
    ])));

    final loose = looseKey.currentContext!.findRenderObject()! as RenderBox;
    final expand = expandKey.currentContext!.findRenderObject()! as RenderBox;
    expect(loose.getDryLayout(constraints), const Size(50, 40));
    expect(loose.getDryLayout(constraints), loose.size);
    expect(expand.getDryLayout(constraints), const Size(300, 300));
    expect(tester.takeException(), isNull);
  });

  testWidgets('aligns to the active page baseline, wet and dry',
      (tester) async {
    final controller = LazyStackController();
    addTearDown(controller.dispose);
    final stackKey = GlobalKey();
    final rowKey = GlobalKey();

    await tester.pumpWidget(_app(Align(
      alignment: Alignment.topLeft,
      child: Row(
        key: rowKey,
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          SizedBox(
            width: 100,
            height: 30,
            child: LazyLoadIndexedStack(
              key: stackKey,
              controller: controller,
              fit: StackFit.loose,
              children: const [Text('small', style: TextStyle(fontSize: 10))],
            ),
          ),
          const Text('big', style: TextStyle(fontSize: 40)),
        ],
      ),
    )));

    // Without a baseline the stack would sit at the top of the row.
    expect(tester.getTopLeft(find.byKey(stackKey)).dy, greaterThan(0));

    final row = rowKey.currentContext!.findRenderObject()! as RenderBox;
    expect(row.getDryLayout(row.constraints), row.size);
    expect(tester.takeException(), isNull);
  });
}
