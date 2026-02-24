import 'dart:collection';
import 'dart:math' as math;
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

part 'util.dart';

enum IndexdAnimationType {
  none,
  fade,
  fadeThrough,
  sharedAxisHorizontal,
  sharedAxisVertical,
}

class LazyLoadIndexedStack extends StatefulWidget {
  final List<Widget> children;
  final LazyStackController controller;
  final AlignmentGeometry alignment;
  final TextDirection? textDirection;
  final IndexdAnimationType animation;
  final Duration animationDuration;

  const LazyLoadIndexedStack({
    super.key,
    required this.controller,
    required this.children,
    this.alignment = AlignmentDirectional.topStart,
    this.textDirection,
    this.animation = IndexdAnimationType.none,
    this.animationDuration = const Duration(milliseconds: 300),
  });

  @override
  State<LazyLoadIndexedStack> createState() => _LazyLoadIndexedStackState();
}

class _LazyLoadIndexedStackState extends State<LazyLoadIndexedStack>
    with SingleTickerProviderStateMixin {
  AnimationController? _animController;
  int _previousIndex = -1;
  int _currentIndex = 0;
  bool _isForward = true;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.controller.currentIndex;
    _previousIndex = _currentIndex;

    _setupAnimationControllerIfNeeded();

    widget.controller.addListener(_onControllerChanged);
  }

  void _setupAnimationControllerIfNeeded() {
    if (widget.animation != IndexdAnimationType.none) {
      _animController = AnimationController(
        vsync: this,
        duration: widget.animationDuration,
        value: 1.0,
      );
    }
  }

  @override
  void didUpdateWidget(covariant LazyLoadIndexedStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
    }

    // Handle dynamic toggling between animated and non-animated types
    if (oldWidget.animation != widget.animation) {
      if (widget.animation == IndexdAnimationType.none) {
        _animController?.dispose();
        _animController = null;
      } else if (_animController == null) {
        _setupAnimationControllerIfNeeded();
      }
    }

    if (oldWidget.animationDuration != widget.animationDuration &&
        _animController != null) {
      _animController!.duration = widget.animationDuration;
    }
  }

  void _onControllerChanged() {
    final newIndex = widget.controller.currentIndex;
    if (newIndex != _currentIndex) {
      if (mounted) {
        setState(() {
          _previousIndex = _currentIndex;
          _currentIndex = newIndex;
          _isForward = newIndex > _previousIndex;
        });

        if (widget.animation != IndexdAnimationType.none &&
            _animController != null) {
          _animController!.forward(from: 0.0);
        }
      }
    } else {
      // Just rebuild for cache/loaded changes without animating
      setState(() {});
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    _animController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loadedIndexes = widget.controller.loadedIndexes;
    final visibleChildren = List<Widget>.filled(
      widget.children.length,
      const SizedBox.shrink(),
    );

    for (final i in loadedIndexes) {
      if (i < widget.children.length) {
        final isIncoming = i == _currentIndex;

        // Zero-overhead path: No animations at all
        if (widget.animation == IndexdAnimationType.none ||
            _animController == null) {
          visibleChildren[i] = TickerMode(
            enabled: isIncoming,
            child: widget.children[i],
          );
          continue;
        }

        // Animated path
        final isOutgoing = i == _previousIndex;
        final isAnimating = _animController!.isAnimating;
        final isEnabled = isIncoming || (isOutgoing && isAnimating);

        Widget child = TickerMode(
          enabled: isEnabled,
          child: widget.children[i],
        );

        if (isEnabled) {
          child = AnimatedBuilder(
            animation: _animController!,
            builder: (context, child) {
              return _buildTransition(child!, isIncoming);
            },
            child: child,
          );
        }

        visibleChildren[i] = child;
      }
    }

    return _LazyRenderStack(
      index: _currentIndex,
      previousIndex:
          (_animController?.isAnimating ?? false) ? _previousIndex : -1,
      alignment: widget.alignment,
      textDirection: widget.textDirection ?? Directionality.maybeOf(context),
      children: visibleChildren,
    );
  }

  Widget _buildTransition(Widget child, bool isIncoming) {
    switch (widget.animation) {
      case IndexdAnimationType.fade:
        return FadeTransition(
          opacity: isIncoming
              ? _animController!
              : ReverseAnimation(_animController!),
          child: child,
        );

      case IndexdAnimationType.fadeThrough:
        if (isIncoming) {
          final fade = CurvedAnimation(
            parent: _animController!,
            curve: const Interval(0.35, 1.0, curve: Curves.easeIn),
          );
          final scale = Tween<double>(begin: 0.92, end: 1.0).animate(
            CurvedAnimation(
              parent: _animController!,
              curve: const Interval(0.35, 1.0, curve: Curves.easeOutCubic),
            ),
          );
          return FadeTransition(
            opacity: fade,
            child: ScaleTransition(scale: scale, child: child),
          );
        } else {
          final fade = 1.0 -
              CurvedAnimation(
                parent: _animController!,
                curve: const Interval(0.0, 0.35, curve: Curves.easeOut),
              ).value;
          return Opacity(
            opacity: fade.clamp(0.0, 1.0),
            child: child,
          );
        }

      case IndexdAnimationType.sharedAxisHorizontal:
      case IndexdAnimationType.sharedAxisVertical:
        final bool isHorizontal =
            widget.animation == IndexdAnimationType.sharedAxisHorizontal;
        final double sign = _isForward ? 1.0 : -1.0;

        if (isIncoming) {
          final fade = CurvedAnimation(
            parent: _animController!,
            curve: const Interval(0.3, 1.0, curve: Curves.easeIn),
          );
          final slide = Tween<Offset>(
            begin:
                isHorizontal ? Offset(sign * 0.15, 0) : Offset(0, sign * 0.15),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: _animController!,
            curve: Curves.fastOutSlowIn,
          ));
          return FadeTransition(
            opacity: fade,
            child: SlideTransition(position: slide, child: child),
          );
        } else {
          final fade = 1.0 -
              CurvedAnimation(
                parent: _animController!,
                curve: const Interval(0.0, 0.3, curve: Curves.easeOut),
              ).value;
          final slide = Tween<Offset>(
            begin: Offset.zero,
            end: isHorizontal
                ? Offset(-sign * 0.15, 0)
                : Offset(0, -sign * 0.15),
          ).animate(CurvedAnimation(
            parent: _animController!,
            curve: Curves.fastOutSlowIn,
          ));
          return Opacity(
            opacity: fade.clamp(0.0, 1.0),
            child: SlideTransition(position: slide, child: child),
          );
        }

      case IndexdAnimationType.none:
        return child;
    }
  }
}

/// A highly optimized custom IndexedStack that bypasses layout computation
/// entirely for non-active background children. Native IndexedStack lays out
/// ALL children, but this specifically only lays out the actively viewed child.
class _LazyRenderStack extends MultiChildRenderObjectWidget {
  final int index;
  final int previousIndex;
  final AlignmentGeometry alignment;
  final TextDirection? textDirection;

  const _LazyRenderStack({
    required this.index,
    required this.previousIndex,
    required this.alignment,
    this.textDirection,
    required super.children,
  });

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderLazyStack(
      index: index,
      previousIndex: previousIndex,
      alignment: alignment,
      textDirection: textDirection ?? Directionality.maybeOf(context),
    );
  }

  @override
  void updateRenderObject(BuildContext context, _RenderLazyStack renderObject) {
    renderObject
      ..index = index
      ..previousIndex = previousIndex
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
  int _previousIndex;
  AlignmentGeometry _alignment;
  TextDirection? _textDirection;

  _RenderLazyStack({
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
    if (child.parentData is! _LazyStackParentData) {
      child.parentData = _LazyStackParentData();
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
    final activeChild = _getChild(_index);
    final previousChild =
        _previousIndex >= 0 ? _getChild(_previousIndex) : null;

    if (activeChild == null && previousChild == null) {
      size = constraints.biggest;
      return;
    }

    Size maxSize = Size.zero;

    if (activeChild != null) {
      activeChild.layout(constraints, parentUsesSize: true);
      maxSize = activeChild.size;
    }

    if (previousChild != null && previousChild != activeChild) {
      previousChild.layout(constraints, parentUsesSize: true);
      if (previousChild.size.width > maxSize.width ||
          previousChild.size.height > maxSize.height) {
        maxSize = Size(
          math.max(maxSize.width, previousChild.size.width),
          math.max(maxSize.height, previousChild.size.height),
        );
      }
    }

    size = constraints.constrain(maxSize);

    final Alignment resolvedAlignment = alignment.resolve(textDirection);

    if (activeChild != null) {
      final _LazyStackParentData activeData =
          activeChild.parentData! as _LazyStackParentData;
      activeData.offset =
          resolvedAlignment.alongOffset((size - activeChild.size) as Offset);
    }

    if (previousChild != null && previousChild != activeChild) {
      final _LazyStackParentData previousData =
          previousChild.parentData! as _LazyStackParentData;
      previousData.offset =
          resolvedAlignment.alongOffset((size - previousChild.size) as Offset);
    }
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    // Only the incoming/active child receives gestures
    final activeChild = _getChild(_index);
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
    final previousChild =
        _previousIndex >= 0 ? _getChild(_previousIndex) : null;
    final activeChild = _getChild(_index);

    // Paint outgoing child first (bottom layer)
    if (previousChild != null && previousChild != activeChild) {
      final _LazyStackParentData previousData =
          previousChild.parentData! as _LazyStackParentData;
      context.paintChild(previousChild, previousData.offset + offset);
    }

    // Paint incoming child (top layer)
    if (activeChild != null) {
      final _LazyStackParentData activeData =
          activeChild.parentData! as _LazyStackParentData;
      context.paintChild(activeChild, activeData.offset + offset);
    }
  }
}
