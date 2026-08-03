import 'package:flutter/widgets.dart';

import '../controller/lazy_stack_controller.dart';
import '../indexd_animation_type.dart';
import '../rendering/lazy_render_stack.dart';
import '../transitions/stack_transition_animations.dart';

/// Lazy-loading indexed stack with optional tab transitions.
///
/// Defaults keep overhead at zero (`animation: [IndexdAnimationType.none]`).
/// For bottom-navigation shells, use `animation: IndexdAnimationType.scaleIn`
/// with `animationDuration: Duration(milliseconds: 320)`.
@immutable
final class LazyLoadIndexedStack extends StatefulWidget {
  final List<Widget> children;
  final LazyStackController controller;
  final AlignmentGeometry alignment;
  final TextDirection? textDirection;

  /// Transition type. Defaults to [IndexdAnimationType.none] (no controller).
  final IndexdAnimationType animation;

  /// Duration for all animated types. Recommended:
  /// - [IndexdAnimationType.scaleIn]: ~320ms
  /// - [IndexdAnimationType.fade], [IndexdAnimationType.fadeThrough],
  ///   shared-axis: ~200–250ms
  final Duration animationDuration;

  const LazyLoadIndexedStack({
    super.key,
    required this.controller,
    required this.children,
    this.alignment = AlignmentDirectional.topStart,
    this.textDirection,
    this.animation = IndexdAnimationType.none,
    this.animationDuration = const Duration(milliseconds: 200),
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
      duration: widget.animationDuration,
      value: 1.0,
    )..addStatusListener(_onAnimationStatus);
  }

  void _onAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
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
      _animController?.value = 1.0;
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
      }
      _buildVersion.value++;
    }

    if (oldWidget.animationDuration != widget.animationDuration &&
        _animController != null) {
      _animController!.duration = widget.animationDuration;
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
            enabled: isParticipating,
            child: RepaintBoundary(child: widget.children[i]),
          );

          child = AnimatedBuilder(
            animation: isParticipating
                ? _animController!
                : const AlwaysStoppedAnimation<double>(0.0),
            builder: (context, child) {
              return _transitions.wrap(
                child: child!,
                animation: widget.animation,
                controller: _animController!,
                isIncoming: isIncoming,
                isParticipating: isParticipating,
              );
            },
            child: child,
          );

          visibleChildren[i] = child;
        }

        return LazyRenderStack(
          index: _currentIndex,
          previousIndex: isAnimating ? _previousIndex : -1,
          alignment: widget.alignment,
          textDirection:
              widget.textDirection ?? Directionality.maybeOf(context),
          children: visibleChildren,
        );
      },
    );
  }
}
