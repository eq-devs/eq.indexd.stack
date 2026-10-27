import 'package:flutter/foundation.dart';
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
///
/// Use [LazyLoadIndexedStack.builder] to construct pages on demand instead of
/// passing them all up front.
@immutable
final class LazyLoadIndexedStack extends StatefulWidget {
  /// The pages, or `null` when built with [LazyLoadIndexedStack.builder].
  ///
  /// A page's [Widget.key] identifies it, so a keyed page keeps its State
  /// when the list is reordered (as long as its new index is still loaded).
  final List<Widget>? children;

  /// Builds the page at an index. Only called for loaded pages. `null`
  /// unless built with [LazyLoadIndexedStack.builder].
  final IndexedWidgetBuilder? itemBuilder;

  final int? _itemCount;

  /// Number of pages.
  int get itemCount => children?.length ?? _itemCount!;

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
    required List<Widget> this.children,
    this.alignment = AlignmentDirectional.topStart,
    this.textDirection,
    this.animation = IndexdAnimationType.none,
    this.animationDuration,
    this.fit = StackFit.expand,
    this.paintOrder,
  })  : itemBuilder = null,
        _itemCount = null;

  /// Builds pages on demand. [itemBuilder] runs only for pages the
  /// controller has loaded, so unvisited pages are never constructed.
  const LazyLoadIndexedStack.builder({
    super.key,
    required this.controller,
    required int itemCount,
    required IndexedWidgetBuilder this.itemBuilder,
    this.alignment = AlignmentDirectional.topStart,
    this.textDirection,
    this.animation = IndexdAnimationType.none,
    this.animationDuration,
    this.fit = StackFit.expand,
    this.paintOrder,
  })  : assert(itemCount >= 0),
        children = null,
        _itemCount = itemCount;

  @override
  State<LazyLoadIndexedStack> createState() => _LazyLoadIndexedStackState();
}

class _LazyLoadIndexedStackState extends State<LazyLoadIndexedStack>
    with SingleTickerProviderStateMixin {
  AnimationController? _animController;
  int _previousIndex = -1;
  int _currentIndex = 0;
  bool _isForward = true;

  /// True between `forward()` and `completed`. A plain field, not
  /// [AnimationController.isAnimating], so the stack is not rebuilt every
  /// frame.
  bool _pageAnimating = false;

  /// True from an index change until the end of that frame. While it (or
  /// [_pageAnimating]) is set, pages preloaded alongside the switch are held
  /// back so they don't build in the same frame as the incoming page.
  bool _deferPreloads = false;
  bool _hasHeldPreloads = false;

  /// Pages mounted by the last build, and the controller cache it used.
  final Set<int> _builtIndexes = <int>{};
  Set<int>? _builtLoadedIndexes;

  /// One key per page so its State survives a change of transition wrapper
  /// (e.g. [IndexdAnimationType.none] → [IndexdAnimationType.scaleIn]) and a
  /// reorder of keyed pages. Keyed by the page's own [Widget.key], or by its
  /// index when it has none.
  final Map<Object, GlobalKey> _pageKeys = <Object, GlobalKey>{};

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
    syncLazyStackPageCount(widget.controller, widget.itemCount);
    assert(
      widget.controller.currentIndex >= 0 &&
          widget.controller.currentIndex < widget.itemCount,
      'LazyStackController.currentIndex (${widget.controller.currentIndex}) '
      'is out of range for LazyLoadIndexedStack (${widget.itemCount} pages).',
    );
    _currentIndex = _clampIndex(widget.controller.currentIndex);
    _previousIndex = _currentIndex;
    _setupAnimationControllerIfNeeded();
    widget.controller.addListener(_onControllerChanged);
    // Pages the controller already holds (e.g. preloadIndexes) build a frame
    // after the initial page instead of alongside it.
    _deferPreloadsThisFrame();
  }

  /// Keeps the displayed index in range in release builds, where the
  /// out-of-range asserts don't run.
  int _clampIndex(int index) {
    final int count = widget.itemCount;
    if (count == 0 || index < 0) return 0;
    return index < count ? index : count - 1;
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
      syncLazyStackPageCount(widget.controller, widget.itemCount);
      widget.controller.addListener(_onControllerChanged);

      _animController?.stop();
      _animController?.value = 0;
      _pageAnimating = false;
      _currentIndex = _clampIndex(widget.controller.currentIndex);
      _previousIndex = _currentIndex;
    } else if (oldWidget.itemCount != widget.itemCount) {
      syncLazyStackPageCount(widget.controller, widget.itemCount);
      _currentIndex = _clampIndex(_currentIndex);
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
    } else if (oldWidget.animationDuration != widget.animationDuration &&
        _animController != null) {
      _animController!.duration = _effectiveDuration;
    }
  }

  void _onControllerChanged() {
    if (!mounted) return;
    final int rawIndex = widget.controller.currentIndex;
    assert(
      rawIndex >= 0 && rawIndex < widget.itemCount,
      'LazyStackController.currentIndex ($rawIndex) is out of range for '
      'LazyLoadIndexedStack (${widget.itemCount} pages). This should not '
      'happen: pageCount is synced automatically from the page count. In '
      'release builds the stack shows the nearest valid page instead.',
    );
    final int newIndex = _clampIndex(rawIndex);
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
      _deferPreloadsThisFrame();
      _buildVersion.value++;
    } else if (!setEquals(
        widget.controller.loadedIndexes, _builtLoadedIndexes)) {
      _buildVersion.value++;
    }
  }

  void _deferPreloadsThisFrame() {
    if (_deferPreloads) return;
    _deferPreloads = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _deferPreloads = false;
      if (mounted && _hasHeldPreloads && !_pageAnimating) {
        _buildVersion.value++;
      }
    });
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
      builder: (context, _, __) => _buildLazyRenderStack(context),
    );
  }

  Widget _buildLazyRenderStack(BuildContext context) {
    final loadedIndexes = widget.controller.loadedIndexes;
    final int itemCount = widget.itemCount;
    final visibleChildren = List<Widget>.filled(
      itemCount,
      const SizedBox.shrink(),
    );

    final bool isAnimating = _animController?.isAnimating ?? false;
    // The displayed page is always built, even if the controller's cache
    // doesn't hold it (e.g. its index was clamped), and the outgoing page
    // stays built until its transition ends.
    final Set<int> renderIndexes = <int>{
      _currentIndex,
      ...loadedIndexes,
      if (isAnimating && _previousIndex >= 0) _previousIndex,
    };

    final bool holdPreloads = _deferPreloads || _pageAnimating;
    _hasHeldPreloads = false;
    _builtLoadedIndexes = loadedIndexes;
    final Set<int> built = <int>{};
    final Set<Object> builtIds = <Object>{};

    for (final i in renderIndexes) {
      if (i < 0 || i >= itemCount) continue;

      final isIncoming = i == _currentIndex;

      if (holdPreloads && !isIncoming && !_builtIndexes.contains(i)) {
        _hasHeldPreloads = true;
        continue;
      }
      built.add(i);

      final Widget page =
          widget.children?[i] ?? widget.itemBuilder!(context, i);
      // A duplicate key falls back to the index so two pages never share a
      // GlobalKey.
      Object id = page.key ?? i;
      if (!builtIds.add(id)) {
        id = i;
        builtIds.add(id);
      }

      Widget child = TickerMode(
        key: _pageKeys.putIfAbsent(id, GlobalKey.new),
        enabled: isIncoming,
        child: RepaintBoundary(child: page),
      );

      if (widget.animation == IndexdAnimationType.none ||
          _animController == null) {
        visibleChildren[i] = child;
        continue;
      }

      final isOutgoing = i == _previousIndex;
      final isParticipating = isIncoming || (isOutgoing && isAnimating);

      child = _transitions.wrap(
        child: child,
        animation: widget.animation,
        controller: _animController!,
        isIncoming: isIncoming,
        isParticipating: isParticipating,
      );

      visibleChildren[i] = child;
    }
    _builtIndexes
      ..clear()
      ..addAll(built);
    // A page that wasn't built this frame is unmounted, so its key has
    // nothing left to preserve.
    _pageKeys.removeWhere((id, _) => !builtIds.contains(id));

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
