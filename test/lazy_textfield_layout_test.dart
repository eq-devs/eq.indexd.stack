import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indexd_stack_dev/indexd_stack_dev.dart';

void main() {
  testWidgets(
    'cached page containing a TextField is laid out and does not throw on '
    'switch away/back',
    (tester) async {
      final controller = LazyStackController(maxCachedPages: 3);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LazyLoadIndexedStack(
              controller: controller,
              children: const [
                // Tab A: contains a TextField (RenderEditable).
                Center(child: TextField()),
                // Tab B.
                Center(child: Text('B')),
              ],
            ),
          ),
        ),
      );

      // Load + render tab A so its TextField subtree is mounted.
      expect(find.byType(TextField), findsOneWidget);

      // Switch to B — A stays loaded (cached) and remains attached.
      controller.switchTo(1, 2);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Switch back to A — the cached TextField subtree must still be valid.
      controller.switchTo(0, 2);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(TextField), findsOneWidget);
    },
  );
}
