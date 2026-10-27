import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indexd_stack_dev/indexd_stack_dev.dart';

class _Logged extends StatelessWidget {
  const _Logged(this.label, this.log);
  final String label;
  final List<String> log;

  @override
  Widget build(BuildContext context) {
    log.add(label);
    return Text(label);
  }
}

void main() {
  for (final animation in [
    IndexdAnimationType.none,
    IndexdAnimationType.scaleIn
  ]) {
    testWidgets(
        'preloadIndexes build a frame after the initial page ($animation)',
        (tester) async {
      final log = <String>[];
      final controller = LazyStackController(preloadIndexes: [1, 2]);
      addTearDown(controller.dispose);

      await tester.pumpWidget(Directionality(
        textDirection: TextDirection.ltr,
        child: LazyLoadIndexedStack(
          controller: controller,
          animation: animation,
          children: [
            _Logged('A', log),
            _Logged('B', log),
            _Logged('C', log),
          ],
        ),
      ));
      expect(log, ['A']);
      expect(controller.isLoaded(1), isTrue);

      await tester.pump();
      expect(log, unorderedEquals(['A', 'B', 'C']));
    });
  }
}
