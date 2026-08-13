import 'package:flutter/widgets.dart';

import '../controller/lazy_stack_controller.dart';
import '../indexd_animation_type.dart';
import '../indexd_paint_order.dart';
import '../rendering/lazy_render_stack.dart';
import '../transitions/scale_in_page_transition.dart';
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
  /// quiet scale transitions read as full-bleed (ant tab-shell parity).
  final StackFit fit;

  /// Which page paints on top during a transition. When `null`:
  /// - [IndexdAnimationType.scaleIn] → [IndexdPaintOrder.stack] (ant / Flutter Stack)
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
  }

  void _onAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _previousIndex = _currentIndex;
      if (widget.animation == IndexdAnimationType.scaleIn) {
        _animController?.value = 0;
      }
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
        _previousIndex = _currentIndex;
      } else if (_animController == null) {
        _setupAnimationControllerIfNeeded();
      } else {
        _animController!.duration = _effectiveDuration;
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
    final newIndex = widget.controller.currentIndex;
    if (newIndex != _currentIndex) {
      if (!mounted) return;
      _previousIndex = _currentIndex;
      _currentIndex = newIndex;
      _isForward = newIndex > _previousIndex;

      if (widget.animation != IndexdAnimationType.none &&
          _animController != null) {
        _transitions.ensureBuilt(
          animation: widget.animation,
          isForward: _isForward,
          controller: _animController!,
        );
        _animController!.forward(from: 0.0);
      } else {
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
      builder: (context, _, __) {
        if (widget.animation == IndexdAnimationType.scaleIn &&
            _animController != null) {
          return _buildScaleInStack();
        }
        return _buildLazyRenderStack();
      },
    );
  }

  Widget _buildScaleInStack() {
    final controller = _animController!;
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final loadedIndexes = widget.controller.loadedIndexes;
        final bool animating = controller.isAnimating;
        return Stack(
          fit: widget.fit,
          alignment: widget.alignment,
          clipBehavior: Clip.hardEdge,
          children: [
            for (var i = 0; i < widget.children.length; i++)
              _ScaleInLayer(
                index: i,
                current: _currentIndex,
                fromIndex: _previousIndex,
                toIndex: _currentIndex,
                animating: animating,
                animation: controller,
                child: (loadedIndexes.contains(i) ||
                        (animating && i == _previousIndex))
                    ? widget.children[i]
                    : const SizedBox.shrink(),
              ),
          ],
        );
      },
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

class _ScaleInLayer extends StatelessWidget {
  const _ScaleInLayer({
    required this.index,
    required this.current,
    required this.fromIndex,
    required this.toIndex,
    required this.animating,
    required this.animation,
    required this.child,
  });

  final int index;
  final int current;
  final int fromIndex;
  final int toIndex;
  final bool animating;
  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isIncoming = animating && index == toIndex;
    final isOutgoing = animating && index == fromIndex;
    final isActiveIdle = !animating && index == current;
    final visible = isIncoming || isOutgoing || isActiveIdle;

    if (!visible) {
      return Offstage(
        offstage: true,
        child: TickerMode(enabled: false, child: child),
      );
    }

    Widget content = TickerMode(
      enabled: isIncoming || isActiveIdle,
      child: child,
    );

    if (animating && (isIncoming || isOutgoing)) {
      content = ScaleInPageTransition(
        animation: animation,
        isIncoming: isIncoming,
        child: content,
      );
    }

    return IgnorePointer(
      ignoring: !(isIncoming || isActiveIdle),
      child: content,
    );
  }
}
