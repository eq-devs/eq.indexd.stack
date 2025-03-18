import 'package:flutter/material.dart';

part 'util.dart';

@immutable
final class EQIndexdStack extends StatelessWidget {
  const EQIndexdStack({
    super.key,
    required this.controller,
    this.alignment = AlignmentDirectional.topStart,
    this.sizing = StackFit.loose,
    this.textDirection,
  });

  final EQIndexdStackController controller;
  final AlignmentGeometry alignment;
  final StackFit sizing;
  final TextDirection? textDirection;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, child) => IndexedStack(
        index: controller.currentIndex,
        alignment: alignment,
        sizing: sizing,
        textDirection: textDirection,
        children: controller.page,
      ),
    );
  }
}
