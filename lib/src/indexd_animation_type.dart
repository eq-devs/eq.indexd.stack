/// Transition style for `LazyLoadIndexedStack`.
///
/// **Tab shells:** prefer [scaleIn] (~320ms) or [fade] (~200–250ms).
/// Use [sharedAxisHorizontal] / [sharedAxisVertical] only when direction
/// should feel spatial. Keep [none] when you want zero animation overhead
/// (package default).
enum IndexdAnimationType {
  /// Instant switch; no [AnimationController] allocated.
  none,

  /// Simple crossfade. Good light tab transition (~200–250ms).
  fade,

  /// Material fade-through (fade + scale).
  fadeThrough,

  /// Quiet iOS-style settle (fade + tiny bilateral scale). Best default for
  /// bottom-nav tab shells; prefer ~320ms.
  scaleIn,

  /// Horizontal slide + fade. Heavier; use when axis motion matters.
  sharedAxisHorizontal,

  /// Vertical slide + fade. Heavier; use when axis motion matters.
  sharedAxisVertical,
}
