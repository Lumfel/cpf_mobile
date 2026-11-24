import 'package:material_ui/material_ui.dart';

/// Subtle entrance transition (fade + gentle upward slide) with zero lingering
/// timers so widget tests (`pumpAndSettle`) remain fast and deterministic.
class FadeSlideIn extends StatelessWidget {
  const FadeSlideIn({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 240),
    this.offsetY = 10,
  });

  final Widget child;
  final Duration duration;
  final double offsetY;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, value, builtChild) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * offsetY),
            child: builtChild,
          ),
        );
      },
      child: child,
    );
  }
}
