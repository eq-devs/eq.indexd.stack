import 'package:flutter/widgets.dart';

import 'stack_transition_animations.dart';

/// Quiet tab switch: fade + tiny scale only — no horizontal slide.
///
/// Same recipe as ant `AntTabPageTransition`. Owns the [CurvedAnimation] so
/// [FadeTransition] / [ScaleTransition] can tick without rebuilding the stack.
class ScaleInPageTransition extends StatefulWidget {
  const ScaleInPageTransition({
    super.key,
    required this.animation,
    required this.child,
    required this.isIncoming,
  });

  final Animation<double> animation;
  final Widget child;
  final bool isIncoming;

  @override
  State<ScaleInPageTransition> createState() => _ScaleInPageTransitionState();
}

class _ScaleInPageTransitionState extends State<ScaleInPageTransition> {
  late CurvedAnimation _curved;
  late Animation<double> _fade;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _bind();
  }

  void _bind() {
    _curved = CurvedAnimation(
      parent: widget.animation,
      curve: kScaleInCurve,
      reverseCurve: kScaleInCurve.flipped,
    );
    _fade = Tween<double>(
      begin: widget.isIncoming ? 0.0 : 1.0,
      end: widget.isIncoming ? 1.0 : 0.0,
    ).animate(_curved);
    _scale = Tween<double>(
      begin: widget.isIncoming ? kScaleInBegin : 1.0,
      end: widget.isIncoming ? 1.0 : kScaleInBegin,
    ).animate(_curved);
  }

  @override
  void didUpdateWidget(covariant ScaleInPageTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animation != widget.animation ||
        oldWidget.isIncoming != widget.isIncoming) {
      _curved.dispose();
      _bind();
    }
  }

  @override
  void dispose() {
    _curved.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: ScaleTransition(
        scale: _scale,
        alignment: Alignment.center,
        child: widget.child,
      ),
    );
  }
}
