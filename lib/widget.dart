import 'dart:collection';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

part 'util.dart';

class LazyLoadIndexedStack extends ListenableBuilder {
  final List<Widget> children;
  final LazyStackController controller;
  final AlignmentGeometry alignment;
  final TextDirection? textDirection;

  LazyLoadIndexedStack({
    super.key,
    required this.controller,
    required this.children,
    this.alignment = AlignmentDirectional.topStart,
    this.textDirection,
  }) : super(
          listenable: controller,
          builder: (context, _) {
            final currentIndex = controller.currentIndex;
            final loadedIndexes = controller.loadedIndexes;
            final visibleChildren =
                List<Widget>.filled(children.length, const SizedBox.shrink());

            for (final i in loadedIndexes) {
              if (i < children.length) {
                // TickerMode pauses animations for inactive tabs
                visibleChildren[i] = TickerMode(
                  enabled: i == currentIndex,
                  child: children[i],
                );
              }
            }

            return _LazyRenderStack(
              index: currentIndex,
              alignment: alignment,
              textDirection: textDirection ?? Directionality.maybeOf(context),
              children: visibleChildren,
            );
          },
        );
}

/// A highly optimized custom IndexedStack that bypasses layout computation
/// entirely for non-active background children. Native IndexedStack lays out
/// ALL children, but this specifically only lays out the actively viewed child.
class _LazyRenderStack extends MultiChildRenderObjectWidget {
  final int index;
  final AlignmentGeometry alignment;
  final TextDirection? textDirection;

  const _LazyRenderStack({
    required this.index,
    required this.alignment,
    this.textDirection,
    required super.children,
  });

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderLazyStack(
      index: index,
      alignment: alignment,
      textDirection: textDirection ?? Directionality.maybeOf(context),
    );
  }

  @override
  void updateRenderObject(
      BuildContext context, _RenderLazyStack renderObject) {
    renderObject
      ..index = index
      ..alignment = alignment
      ..textDirection = textDirection ?? Directionality.maybeOf(context);
  }
}

class _LazyStackParentData extends ContainerBoxParentData<RenderBox> {
  // Allows the parent RenderObject to optionally track alignment manually if needed.
}

class _RenderLazyStack extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _LazyStackParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _LazyStackParentData> {
  int _index;
  AlignmentGeometry _alignment;
  TextDirection? _textDirection;

  _RenderLazyStack({
    required int index,
    required AlignmentGeometry alignment,
    TextDirection? textDirection,
  })  : _index = index,
        _alignment = alignment,
        _textDirection = textDirection;

  int get index => _index;
  set index(int value) {
    if (_index == value) return;
    _index = value;
    markNeedsLayout();
  }

  AlignmentGeometry get alignment => _alignment;
  set alignment(AlignmentGeometry value) {
    if (_alignment == value) return;
    _alignment = value;
    markNeedsLayout();
  }

  TextDirection? get textDirection => _textDirection;
  set textDirection(TextDirection? value) {
    if (_textDirection == value) return;
    _textDirection = value;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _LazyStackParentData) {
      child.parentData = _LazyStackParentData();
    }
  }

  RenderBox? get _activeChild {
    int currentIndex = 0;
    RenderBox? child = firstChild;
    while (child != null) {
      if (currentIndex == _index) {
        return child;
      }
      child = childAfter(child);
      currentIndex++;
    }
    return null;
  }

  @override
  void performLayout() {
    final activeChild = _activeChild;

    if (activeChild == null) {
      size = constraints.biggest;
      return;
    }

    // ONLY the active child is laid out.
    // Native IndexedStack lays out EVERY child. We completely skip it here.
    activeChild.layout(constraints, parentUsesSize: true);

    // Determines the final size based on the single active child and constraints.
    size = constraints.constrain(activeChild.size);

    // Apply alignment
    final Alignment resolvedAlignment = alignment.resolve(textDirection);
    final _LazyStackParentData childParentData =
        activeChild.parentData! as _LazyStackParentData;

    // Position using alignment relative to the chosen size.
    childParentData.offset =
        resolvedAlignment.alongOffset((size - activeChild.size) as Offset);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    // Only the active child receives gestures
    final activeChild = _activeChild;
    if (activeChild != null) {
      final _LazyStackParentData childParentData =
          activeChild.parentData! as _LazyStackParentData;
      return result.addWithPaintOffset(
        offset: childParentData.offset,
        position: position,
        hitTest: (BoxHitTestResult result, Offset transformed) {
          assert(transformed == position - childParentData.offset);
          return activeChild.hitTest(result, position: transformed);
        },
      );
    }
    return false;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    // Native IndexedStack also only paints the active child, so we mirror that.
    final activeChild = _activeChild;
    if (activeChild != null) {
      final _LazyStackParentData childParentData =
          activeChild.parentData! as _LazyStackParentData;
      context.paintChild(activeChild, childParentData.offset + offset);
    }
  }
}
