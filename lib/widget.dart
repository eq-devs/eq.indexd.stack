import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; 


part 'util.dart';

@immutable
class EQLazyLoadIndexedStack extends StatelessWidget {
  /// Controller that manages which pages are loaded and visible
  final EQLazyStackController controller;

  /// List of child widgets to display
  final List<Widget> children;

  /// How to align the non-positioned and partially-positioned children in the stack
  final AlignmentGeometry alignment;

  /// How to size the non-positioned children in the stack
  final StackFit sizing;

  /// The text direction to use for [alignment]
  final TextDirection? textDirection;

  /// Creates a stack that shows a single child from a list, with very aggressive lazy loading
  const EQLazyLoadIndexedStack({
    super.key,
    required this.controller,
    required this.children,
    this.alignment = AlignmentDirectional.topStart,
    this.sizing = StackFit.loose,
    this.textDirection,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final loadedChildren = <Widget>[];
        for (int i = 0; i < children.length; i++) {
          if (controller.isLoaded(i)) {
            loadedChildren.add(
              Offstage(
                offstage: i != controller.currentIndex,
                child: TickerMode(
                  enabled: i == controller.currentIndex,
                  child: KeyedSubtree(
                    key: ValueKey('lazy_child_$i'),
                    child: children[i],
                  ),
                ),
              ),
            );
          }
        }

        return Stack(
          alignment: alignment,
          textDirection: textDirection,
          fit: sizing,
          children: loadedChildren,
        );
      },
    );
  }
}
