import 'dart:collection';
import 'package:flutter/material.dart';

part 'util.dart';

class EQLazyLoadIndexedStack extends ListenableBuilder {
  final List<Widget> children;
  final AlignmentGeometry alignment;
  final StackFit sizing;
  final TextDirection? textDirection;

  EQLazyLoadIndexedStack(
      {super.key,
      required EQLazyStackController controller,
      required this.children,
      this.alignment = AlignmentDirectional.topStart,
      this.sizing = StackFit.loose,
      this.textDirection,
      super.child})
      : super(
          listenable: controller,
          builder: (context, _) {
            final currentIndex = controller.currentIndex;
            final loadedIndexes = controller.loadedIndexes;
            final visibleChildren =
                List<Widget>.filled(children.length, const SizedBox.shrink());

            for (final i in loadedIndexes) {
              if (i < children.length) {
                visibleChildren[i] = KeyedSubtree(
                  key: ValueKey('lc$i'),
                  child: TickerMode(
                    enabled: i == currentIndex,
                    child: children[i],
                  ),
                );
              }
            }

            return IndexedStack(
              index: currentIndex,
              alignment: alignment,
              textDirection: textDirection,
              sizing: sizing,
              children: visibleChildren,
            );
          },
        );
}
