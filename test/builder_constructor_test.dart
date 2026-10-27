import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indexd_stack_dev/indexd_stack_dev.dart';

void main() {
  testWidgets('itemBuilder runs only for loaded pages', (tester) async {
    final calls = <int>{};
    final controller = LazyStackController();
    addTearDown(controller.dispose);

    Widget build(int count) => Directionality(
          textDirection: TextDirection.ltr,
          child: LazyLoadIndexedStack.builder(
            controller: controller,
            itemCount: count,
            itemBuilder: (context, i) {
              calls.add(i);
              return Text('P$i');
            },
          ),
        );

    await tester.pumpWidget(build(5));
    expect(controller.pageCount, 5);
    expect(calls, {0});

    controller.switchTo(3);
    await tester.pumpAndSettle();
    expect(calls, {0, 3});
    expect(find.text('P3').hitTestable(), findsOneWidget);

    await tester.pumpWidget(build(2));
    await tester.pumpAndSettle();
    expect(controller.pageCount, 2);
    expect(find.text('P1').hitTestable(), findsOneWidget);
  });

  test('deprecated isListenMemoryPressure still maps to the new flag', () {
    TestWidgetsFlutterBinding.ensureInitialized();
    // ignore: deprecated_member_use_from_same_package
    final controller = LazyStackController(isListenMemoryPressure: true);
    expect(controller.listenToMemoryPressure, isTrue);
    controller.dispose();
  });
}
