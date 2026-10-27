import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indexd_stack_dev/indexd_stack_dev.dart';

void main() {
  testWidgets('shrinking children below the current index shows the last page',
      (tester) async {
    final controller = LazyStackController();
    addTearDown(controller.dispose);

    Widget build(int count) => Directionality(
          textDirection: TextDirection.ltr,
          child: LazyLoadIndexedStack(
            controller: controller,
            children: [for (var i = 0; i < count; i++) Text('P$i')],
          ),
        );

    await tester.pumpWidget(build(3));
    controller.switchTo(2);
    await tester.pumpAndSettle();

    await tester.pumpWidget(build(2));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('P1').hitTestable(), findsOneWidget);

    controller.switchTo(0);
    await tester.pumpAndSettle();
    expect(find.text('P0').hitTestable(), findsOneWidget);
  });
}
