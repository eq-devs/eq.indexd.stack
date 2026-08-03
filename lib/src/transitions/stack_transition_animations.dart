import 'package:flutter/widgets.dart';

import '../indexd_animation_type.dart';

/// Soft iOS-like settle curve — same as ant `AntTabPageTransition`.
const Curve kScaleInCurve = Cubic(0.22, 1.0, 0.36, 1.0);

/// Quiet scale offset — same as ant `AntTabPageTransition` (`0.992` ↔ `1.0`).
const double kScaleInBegin = 0.992;

/// Cached curved animations for lazy-stack page transitions.
///
/// Rebuild only when [IndexdAnimationType] (or shared-axis direction) changes.
final class StackTransitionAnimations {
  static const inertScale = AlwaysStoppedAnimation(1.0);
  static const inertOpacity = AlwaysStoppedAnimation(1.0);
  static const inertSlide = AlwaysStoppedAnimation(Offset.zero);

  CurvedAnimation? _inFade;
  CurvedAnimation? _outFade;
  CurvedAnimation? _inScale;
  Animation<double>? _inScaleAnim;
  Animation<double>? _outScaleAnim;
  Animation<double>? _scaleInIncomingOpacity;
  Animation<double>? _scaleInOutgoingOpacity;
  Animation<Offset>? _inSlide;
  Animation<Offset>? _outSlide;
  Animation<double>? _acReverse;
  Animation<double>? _outFadeReverse;

  IndexdAnimationType? _builtForAnimation;
  bool _builtForForward = true;

  void ensureBuilt({
    required IndexdAnimationType animation,
    required bool isForward,
    required AnimationController controller,
  }) {
    final bool directionSensitive =
        animation == IndexdAnimationType.sharedAxisHorizontal ||
            animation == IndexdAnimationType.sharedAxisVertical;
    if (_builtForAnimation == animation &&
        (!directionSensitive || _builtForForward == isForward)) {
      return;
    }
    _build(animation: animation, isForward: isForward, controller: controller);
    _builtForAnimation = animation;
    _builtForForward = isForward;
  }

  void _build({
    required IndexdAnimationType animation,
    required bool isForward,
    required AnimationController controller,
  }) {
    dispose();
    final ac = controller;

    switch (animation) {
      case IndexdAnimationType.fade:
        _acReverse = ReverseAnimation(ac);
        break;

      case IndexdAnimationType.fadeThrough:
        _inFade = CurvedAnimation(
          parent: ac,
          curve: const Interval(0.2, 1.0, curve: Curves.easeOut),
        );
        _outFade = CurvedAnimation(
          parent: ac,
          curve: const Interval(0.0, 0.4, curve: Curves.easeIn),
        );
        _inScale = CurvedAnimation(
          parent: ac,
          curve: Curves.fastLinearToSlowEaseIn,
        );
        _inScaleAnim = Tween<double>(begin: 0.96, end: 1.0).animate(_inScale!);
        _outFadeReverse = ReverseAnimation(_outFade!);
        break;

      case IndexdAnimationType.scaleIn:
        // Pure Flutter equivalent of ant `AntTabPageTransition`.
        _inScale = CurvedAnimation(
          parent: ac,
          curve: kScaleInCurve,
          reverseCurve: kScaleInCurve.flipped,
        );
        final inOpacity =
            Tween<double>(begin: 0.0, end: 1.0).animate(_inScale!);
        _scaleInIncomingOpacity = inOpacity;
        _scaleInOutgoingOpacity = ReverseAnimation(inOpacity);
        _inScaleAnim =
            Tween<double>(begin: kScaleInBegin, end: 1.0).animate(_inScale!);
        _outScaleAnim =
            Tween<double>(begin: 1.0, end: kScaleInBegin).animate(_inScale!);
        break;

      case IndexdAnimationType.sharedAxisHorizontal:
      case IndexdAnimationType.sharedAxisVertical:
        final bool isHorizontal =
            animation == IndexdAnimationType.sharedAxisHorizontal;
        final double sign = isForward ? 1.0 : -1.0;

        _inFade = CurvedAnimation(
          parent: ac,
          curve: const Interval(0.2, 1.0, curve: Curves.easeOut),
        );
        _outFade = CurvedAnimation(
          parent: ac,
          curve: const Interval(0.0, 0.4, curve: Curves.easeIn),
        );
        _inSlide = Tween<Offset>(
          begin: isHorizontal ? Offset(sign * 0.07, 0) : Offset(0, sign * 0.07),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: ac,
          curve: Curves.fastOutSlowIn,
        ));
        _outSlide = Tween<Offset>(
          begin: Offset.zero,
          end: isHorizontal ? Offset(-sign * 0.07, 0) : Offset(0, -sign * 0.07),
        ).animate(CurvedAnimation(
          parent: ac,
          curve: Curves.fastOutSlowIn,
        ));
        _outFadeReverse = ReverseAnimation(_outFade!);
        break;

      case IndexdAnimationType.none:
        break;
    }
  }

  /// Wraps [child] with the active transition for [animation].
  Widget wrap({
    required Widget child,
    required IndexdAnimationType animation,
    required AnimationController controller,
    required bool isIncoming,
    required bool isParticipating,
  }) {
    switch (animation) {
      case IndexdAnimationType.fade:
        return FadeTransition(
          opacity: isParticipating
              ? (isIncoming ? controller : _acReverse!)
              : inertOpacity,
          child: child,
        );

      case IndexdAnimationType.fadeThrough:
        final Animation<double> opacity;
        final Animation<double> scale;

        if (!isParticipating) {
          opacity = inertOpacity;
          scale = inertScale;
        } else if (isIncoming) {
          opacity = _inFade ?? controller;
          scale = _inScaleAnim ?? controller;
        } else {
          opacity = _outFadeReverse ?? _acReverse!;
          scale = inertScale;
        }

        return FadeTransition(
          opacity: opacity,
          child: ScaleTransition(scale: scale, child: child),
        );

      case IndexdAnimationType.scaleIn:
        final Animation<double> opacity;
        final Animation<double> scale;

        if (!isParticipating) {
          opacity = inertOpacity;
          scale = inertScale;
        } else if (isIncoming) {
          opacity = _scaleInIncomingOpacity ?? controller;
          scale = _inScaleAnim ?? inertScale;
        } else {
          opacity = _scaleInOutgoingOpacity ?? inertOpacity;
          scale = _outScaleAnim ?? inertScale;
        }

        return FadeTransition(
          opacity: opacity,
          child: ScaleTransition(
            scale: scale,
            alignment: Alignment.center,
            child: child,
          ),
        );

      case IndexdAnimationType.sharedAxisHorizontal:
      case IndexdAnimationType.sharedAxisVertical:
        final Animation<double> opacity;
        final Animation<Offset> slide;

        if (!isParticipating) {
          opacity = inertOpacity;
          slide = inertSlide;
        } else if (isIncoming) {
          opacity = _inFade ?? controller;
          slide = _inSlide ?? inertSlide;
        } else {
          opacity = _outFadeReverse ?? _acReverse!;
          slide = _outSlide ?? inertSlide;
        }

        return FadeTransition(
          opacity: opacity,
          child: SlideTransition(position: slide, child: child),
        );

      case IndexdAnimationType.none:
        return child;
    }
  }

  void dispose() {
    _builtForAnimation = null;
    _inFade?.dispose();
    _outFade?.dispose();
    _inScale?.dispose();
    _inFade = null;
    _outFade = null;
    _inScale = null;
    _inScaleAnim = null;
    _outScaleAnim = null;
    _scaleInIncomingOpacity = null;
    _scaleInOutgoingOpacity = null;
    _inSlide = null;
    _outSlide = null;
    _acReverse = null;
    _outFadeReverse = null;
  }
}
