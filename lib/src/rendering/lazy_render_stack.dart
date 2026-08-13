import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../indexd_paint_order.dart';

/// Multi-child stack that paints/hit-tests only the active (and optional
/// outgoing) child. Not part of the public package API.
class LazyRenderStack extends MultiChildRenderObjectWidget {
  final int index;
  final int previousIndex;
  final AlignmentGeometry alignment;
  final TextDirection? textDirection;
  final StackFit fit;
  final IndexdPaintOrder paintOrder;
  final Clip clipBehavior;

  const LazyRenderStack({
    super.key,
    required this.index,
    required this.previousIndex,
    required this.alignment,
    this.textDirection,
    this.fit = StackFit.expand,
    this.paintOrder = IndexdPaintOrder.incomingOnTop,
    this.clipBehavior = Clip.hardEdge,
    required super.children,
  });

  @override
  RenderObject createRenderObject(BuildContext context) {
    return RenderLazyStack(
      index: index,
      previousIndex: previousIndex,
      alignment: alignment,
      textDirection: textDirection ?? Directionality.maybeOf(context),
      fit: fit,
      paintOrder: paintOrder,
      clipBehavior: clipBehavior,
    );
  }

  @override
  void updateRenderObject(BuildContext context, RenderLazyStack renderObject) {
    renderObject
      ..index = index
      ..previousIndex = previousIndex
      ..alignment = alignment
      ..textDirection = textDirection ?? Directionality.maybeOf(context)
      ..fit = fit
      ..paintOrder = paintOrder
      ..clipBehavior = clipBehavior;
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
  StackFit _fit;
  IndexdPaintOrder _paintOrder;
  Clip _clipBehavior;

  RenderLazyStack({
    required int index,
    required int previousIndex,
    required AlignmentGeometry alignment,
    TextDirection? textDirection,
    StackFit fit = StackFit.expand,
    IndexdPaintOrder paintOrder = IndexdPaintOrder.incomingOnTop,
    Clip clipBehavior = Clip.hardEdge,
  })  : _index = index,
        _previousIndex = previousIndex,
        _alignment = alignment,
        _textDirection = textDirection,
        _fit = fit,
        _paintOrder = paintOrder,
        _clipBehavior = clipBehavior;

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

  StackFit get fit => _fit;
  set fit(StackFit value) {
    if (_fit == value) return;
    _fit = value;
    markNeedsLayout();
  }

  IndexdPaintOrder get paintOrder => _paintOrder;
  set paintOrder(IndexdPaintOrder value) {
    if (_paintOrder == value) return;
    _paintOrder = value;
    markNeedsPaint();
  }

  Clip get clipBehavior => _clipBehavior;
  set clipBehavior(Clip value) {
    if (_clipBehavior == value) return;
    _clipBehavior = value;
    markNeedsPaint();
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
    // parentUsesSize: false, which makes each one its own relayout boundary.
    //
    // [StackFit.expand] matches ant's tab shell: participating pages fill the
    // viewport so the quiet 0.992 scale reads as a full-bleed settle.
    RenderBox? activeChild;
    RenderBox? previousChild;
    Size maxSize = Size.zero;

    final bool expand = _fit == StackFit.expand;
    if (expand) {
      size = constraints.biggest;
    }

    final BoxConstraints childConstraints = expand
        ? BoxConstraints.tight(size)
        : (_fit == StackFit.loose ? constraints.loosen() : constraints);

    int childIndex = 0;
    RenderBox? child = firstChild;
    while (child != null) {
      final bool sizesStack = childIndex == _index ||
          (_previousIndex >= 0 && childIndex == _previousIndex);
      child.layout(childConstraints, parentUsesSize: sizesStack);
      if (sizesStack) {
        if (childIndex == _index) activeChild = child;
        if (childIndex == _previousIndex) previousChild = child;
        if (!expand) {
          maxSize = Size(
            child.size.width > maxSize.width ? child.size.width : maxSize.width,
            child.size.height > maxSize.height
                ? child.size.height
                : maxSize.height,
          );
        }
      }
      child = childAfter(child);
      childIndex++;
    }

    if (!expand) {
      size = (activeChild == null && previousChild == null)
          ? constraints.biggest
          : constraints.constrain(maxSize);
    }

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
    if (_clipBehavior == Clip.none) {
      _paintChildren(context, offset);
      return;
    }
    context.pushClipRect(
      needsCompositing,
      offset,
      Offset.zero & size,
      _paintChildren,
      clipBehavior: _clipBehavior,
    );
  }

  void _paintChildren(PaintingContext context, Offset offset) {
    final previousChild =
        _previousIndex >= 0 ? _getChild(_previousIndex) : null;
    final activeChild = _getChild(_index);

    void paintChild(RenderBox? box) {
      if (box == null) return;
      final LazyStackParentData data = box.parentData! as LazyStackParentData;
      context.paintChild(box, data.offset + offset);
    }

    if (previousChild != null && previousChild == activeChild) {
      paintChild(activeChild);
      return;
    }

    switch (_paintOrder) {
      case IndexdPaintOrder.outgoingOnTop:
        paintChild(activeChild);
        paintChild(previousChild);
      case IndexdPaintOrder.incomingOnTop:
        paintChild(previousChild);
        paintChild(activeChild);
      case IndexdPaintOrder.stack:
        // Flutter Stack / ant: higher child index paints on top.
        if (_previousIndex >= 0 && _previousIndex > _index) {
          paintChild(activeChild);
          paintChild(previousChild);
        } else {
          paintChild(previousChild);
          paintChild(activeChild);
        }
    }
  }
}
