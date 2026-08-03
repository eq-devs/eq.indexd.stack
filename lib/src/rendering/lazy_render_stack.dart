import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Multi-child stack that paints/hit-tests only the active (and optional
/// outgoing) child. Not part of the public package API.
class LazyRenderStack extends MultiChildRenderObjectWidget {
  final int index;
  final int previousIndex;
  final AlignmentGeometry alignment;
  final TextDirection? textDirection;

  const LazyRenderStack({
    super.key,
    required this.index,
    required this.previousIndex,
    required this.alignment,
    this.textDirection,
    required super.children,
  });

  @override
  RenderObject createRenderObject(BuildContext context) {
    return RenderLazyStack(
      index: index,
      previousIndex: previousIndex,
      alignment: alignment,
      textDirection: textDirection ?? Directionality.maybeOf(context),
    );
  }

  @override
  void updateRenderObject(BuildContext context, RenderLazyStack renderObject) {
    renderObject
      ..index = index
      ..previousIndex = previousIndex
      ..alignment = alignment
      ..textDirection = textDirection ?? Directionality.maybeOf(context);
  }
}

class LazyStackParentData extends ContainerBoxParentData<RenderBox> {}

class RenderLazyStack extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, LazyStackParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, LazyStackParentData> {
  int _index;
  int _previousIndex;
  AlignmentGeometry _alignment;
  TextDirection? _textDirection;

  RenderLazyStack({
    required int index,
    required int previousIndex,
    required AlignmentGeometry alignment,
    TextDirection? textDirection,
  })  : _index = index,
        _previousIndex = previousIndex,
        _alignment = alignment,
        _textDirection = textDirection;

  int get index => _index;
  set index(int value) {
    if (_index == value) return;
    _index = value;
    markNeedsLayout();
  }

  int get previousIndex => _previousIndex;
  set previousIndex(int value) {
    if (_previousIndex == value) return;
    _previousIndex = value;
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
    if (child.parentData is! LazyStackParentData) {
      child.parentData = LazyStackParentData();
    }
  }

  RenderBox? _getChild(int targetIndex) {
    if (targetIndex < 0) return null;
    int currentIndex = 0;
    RenderBox? child = firstChild;
    while (child != null) {
      if (currentIndex == targetIndex) {
        return child;
      }
      child = childAfter(child);
      currentIndex++;
    }
    return null;
  }

  @override
  void performLayout() {
    // Every attached child MUST be laid out each pass (Flutter's layout
    // contract). Only the active child — and the outgoing child while a
    // transition is running — determine the stack's size, so only they are
    // laid out with parentUsesSize: true. Hidden children use
    // parentUsesSize: false, which makes each one its own relayout boundary:
    // a size change inside a hidden cached page relays out that page alone
    // instead of dirtying the whole stack.
    RenderBox? activeChild;
    RenderBox? previousChild;
    Size maxSize = Size.zero;
    int childIndex = 0;
    RenderBox? child = firstChild;
    while (child != null) {
      final bool sizesStack = childIndex == _index ||
          (_previousIndex >= 0 && childIndex == _previousIndex);
      child.layout(constraints, parentUsesSize: sizesStack);
      if (sizesStack) {
        if (childIndex == _index) activeChild = child;
        if (childIndex == _previousIndex) previousChild = child;
        maxSize = Size(
          child.size.width > maxSize.width ? child.size.width : maxSize.width,
          child.size.height > maxSize.height
              ? child.size.height
              : maxSize.height,
        );
      }
      child = childAfter(child);
      childIndex++;
    }

    size = (activeChild == null && previousChild == null)
        ? constraints.biggest
        : constraints.constrain(maxSize);

    // Only the active and outgoing children are painted or hit-tested, so
    // only their offsets matter — and hidden children's sizes cannot be read
    // here anyway (laid out with parentUsesSize: false). When a hidden child
    // becomes active, the index setter marks this stack for relayout and its
    // offset is computed then.
    final Alignment resolvedAlignment = alignment.resolve(textDirection);
    for (final positioned in <RenderBox?>[activeChild, previousChild]) {
      if (positioned == null) continue;
      final childParentData = positioned.parentData! as LazyStackParentData;
      childParentData.offset =
          resolvedAlignment.alongOffset((size - positioned.size) as Offset);
    }
  }

  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) {
    final active = _getChild(_index);
    if (active != null) visitor(active);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    final activeChild = _getChild(_index);
    if (activeChild != null) {
      final LazyStackParentData childParentData =
          activeChild.parentData! as LazyStackParentData;
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
    final previousChild =
        _previousIndex >= 0 ? _getChild(_previousIndex) : null;
    final activeChild = _getChild(_index);

    if (previousChild != null && previousChild != activeChild) {
      final LazyStackParentData previousData =
          previousChild.parentData! as LazyStackParentData;
      context.paintChild(previousChild, previousData.offset + offset);
    }

    if (activeChild != null) {
      final LazyStackParentData activeData =
          activeChild.parentData! as LazyStackParentData;
      context.paintChild(activeChild, activeData.offset + offset);
    }
  }
}
