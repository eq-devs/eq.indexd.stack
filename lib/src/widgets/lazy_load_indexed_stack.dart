import 'package:flutter/widgets.dart';

import '../controller/lazy_stack_controller.dart';
import '../indexd_animation_type.dart';
import '../indexd_paint_order.dart';
import '../rendering/lazy_render_stack.dart';
import '../transitions/stack_transition_animations.dart';

/// Lazy-loading indexed stack with optional tab transitions.
///
/// Defaults keep overhead at zero (`animation: [IndexdAnimationType.none]`).
/// For bottom-navigation shells, use `animation: IndexdAnimationType.scaleIn`
/// — duration defaults to [kScaleInDuration] (320ms).
@immutable
final class LazyLoadIndexedStack extends StatefulWidget {
  final List<Widget> children;
  final LazyStackController controller;
  final AlignmentGeometry alignment;
  final TextDirection? textDirection;

  /// Transition type. Defaults to [IndexdAnimationType.none] (no controller).
  final IndexdAnimationType animation;

  /// Duration for animated types. When `null`, uses a type default:
  /// - [IndexdAnimationType.scaleIn] → [kScaleInDuration] (320ms)
  /// - fade / fadeThrough / shared-axis → [kDefaultAnimationDuration] (200ms)
  final Duration? animationDuration;

  /// How participating pages are sized. Defaults to [StackFit.expand] so
  /// quiet scale transitions read as full-bleed.
  final StackFit fit;

  /// Which page paints on top during a transition. When `null`:
  /// - [IndexdAnimationType.scaleIn] → [IndexdPaintOrder.stack] (Flutter Stack)
  /// - others → [IndexdPaintOrder.incomingOnTop]
  final IndexdPaintOrder? paintOrder;

  const LazyLoadIndexedStack({
    super.key,
    required this.controller,
    required this.children,
    this.alignment = AlignmentDirectional.topStart,
    this.textDirection,
    this.animation = IndexdAnimationType.none,
    this.animationDuration,
    this.fit = StackFit.expand,
    this.paintOrder,
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
  /// True between `forward()` and `completed`. Only consulted in
  /// [didUpdateWidget] — not read from [AnimationController.isAnimating]
  /// inside [build], so the stack is not rebuilt every frame.
  bool _pageAnimating = false;

  final ValueNotifier<int> _buildVersion = ValueNotifier<int>(0);
  final StackTransitionAnimations _transitions = StackTransitionAnimations();

  Duration get _effectiveDuration {
    if (widget.animationDuration != null) return widget.animationDuration!;
    return widget.animation == IndexdAnimationType.scaleIn
        ? kScaleInDuration
        : kDefaultAnimationDuration;
  }

  IndexdPaintOrder get _effectivePaintOrder {
    if (widget.paintOrder != null) return widget.paintOrder!;
    return widget.animation == IndexdAnimationType.scaleIn
        ? IndexdPaintOrder.stack
        : IndexdPaintOrder.incomingOnTop;
  }

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.controller.currentIndex;
    assert(
      _currentIndex >= 0 && _currentIndex < widget.children.length,
      'LazyStackController.currentIndex ($_currentIndex) is out of range '
      'for LazyLoadIndexedStack.children (length ${widget.children.length}). '
      'The controller has no reference to children.length — check that every '
      'switchTo/preloadPage/preloadAdjacentPages call passes a totalPages '
      'that matches children.length, especially if the tab count can change '
      'at runtime.',
    );
    _previousIndex = _currentIndex;
    _setupAnimationControllerIfNeeded();
    widget.controller.addListener(_onControllerChanged);
  }

  void _setupAnimationControllerIfNeeded() {
    if (widget.animation == IndexdAnimationType.none) return;
    _animController = AnimationController(
      vsync: this,
      duration: _effectiveDuration,
    )..addStatusListener(_onAnimationStatus);
    _settleIdleController();
  }

  /// Forces the controller + [_transitions] into the "just finished a
  /// forward transition into this page" state, synchronously, so the
  /// idle initial/current page never renders through a null/zero-value
  /// fallback in [StackTransitionAnimations.wrap].
  void _settleIdleController() {
    _transitions.ensureBuilt(
      animation: widget.animation,
      isForward: true,
      controller: _animController!,
    );
    if (_animController!.value != 1.0) {
      _animController!.value = 1.0;
    }
  }

  void _onAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _pageAnimating = false;
      _previousIndex = _currentIndex;
      _buildVersion.value++;
    }
  }

  @override
  void didUpdateWidget(covariant LazyLoadIndexedStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);

      _animController?.stop();
      _animController?.value = 0;
      _pageAnimating = false;
      _currentIndex = widget.controller.currentIndex;
      _previousIndex = _currentIndex;
      _buildVersion.value++;
    }

    if (oldWidget.animation != widget.animation) {
      if (widget.animation == IndexdAnimationType.none) {
        _transitions.dispose();
        _animController?.removeStatusListener(_onAnimationStatus);
        _animController?.dispose();
        _animController = null;
        _pageAnimating = false;
        _previousIndex = _currentIndex;
      } else if (_animController == null) {
        _setupAnimationControllerIfNeeded();
      } else {
        _animController!.duration = _effectiveDuration;
        if (!_pageAnimating) {
          _settleIdleController();
        }
      }
      _buildVersion.value++;
    } else if (oldWidget.animationDuration != widget.animationDuration &&
        _animController != null) {
      _animController!.duration = _effectiveDuration;
    }

    if (oldWidget.paintOrder != widget.paintOrder ||
        oldWidget.fit != widget.fit) {
      _buildVersion.value++;
    }
  }

  void _onControllerChanged() {
    if (!mounted) return;
    final newIndex = widget.controller.currentIndex;
    assert(
      newIndex >= 0 && newIndex < widget.children.length,
      'LazyStackController.currentIndex ($newIndex) is out of range for '
      'LazyLoadIndexedStack.children (length ${widget.children.length}). '
      'The controller has no reference to children.length — check that every '
      'switchTo/preloadPage/preloadAdjacentPages call passes a totalPages '
      'that matches children.length, especially if the tab count can change '
      'at runtime. Left unfixed, the stack silently stops painting and stops '
      'responding to hit-tests for the affected page.',
    );
    if (newIndex != _currentIndex) {
      _previousIndex = _currentIndex;
      _currentIndex = newIndex;
      _isForward = newIndex > _previousIndex;

      if (widget.animation != IndexdAnimationType.none &&
          _animController != null) {
        _pageAnimating = true;
        _transitions.ensureBuilt(
          animation: widget.animation,
          isForward: _isForward,
          controller: _animController!,
        );
        _animController!.forward(from: 0.0);
      } else {
        _pageAnimating = false;
        _previousIndex = _currentIndex;
      }
      _buildVersion.value++;
    } else {
      _buildVersion.value++;
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    _transitions.dispose();
    _animController?.removeStatusListener(_onAnimationStatus);
    _animController?.dispose();
    _buildVersion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: _buildVersion,
      builder: (context, _, __) => _buildLazyRenderStack(),
    );
  }

  Widget _buildLazyRenderStack() {
    final loadedIndexes = widget.controller.loadedIndexes;
    final visibleChildren = List<Widget>.filled(
      widget.children.length,
      const SizedBox.shrink(),
    );

    final bool isAnimating = _animController?.isAnimating ?? false;
    final Iterable<int> renderIndexes = (isAnimating &&
            _previousIndex >= 0 &&
            !loadedIndexes.contains(_previousIndex))
        ? loadedIndexes.followedBy(<int>[_previousIndex])
        : loadedIndexes;

    for (final i in renderIndexes) {
      if (i >= widget.children.length) continue;

      final isIncoming = i == _currentIndex;

      if (widget.animation == IndexdAnimationType.none ||
          _animController == null) {
        visibleChildren[i] = TickerMode(
          enabled: isIncoming,
          child: RepaintBoundary(child: widget.children[i]),
        );
        continue;
      }

      final isOutgoing = i == _previousIndex;
      final isParticipating = isIncoming || (isOutgoing && isAnimating);

      Widget child = TickerMode(
        enabled: isIncoming,
        child: RepaintBoundary(child: widget.children[i]),
      );

      child = _transitions.wrap(
        child: child,
        animation: widget.animation,
        controller: _animController!,
        isIncoming: isIncoming,
        isParticipating: isParticipating,
      );

      visibleChildren[i] = child;
    }

    return LazyRenderStack(
      index: _currentIndex,
      previousIndex: isAnimating ? _previousIndex : -1,
      alignment: widget.alignment,
      textDirection: widget.textDirection ?? Directionality.maybeOf(context),
      fit: widget.fit,
      paintOrder: _effectivePaintOrder,
      children: visibleChildren,
    );
  }
}
