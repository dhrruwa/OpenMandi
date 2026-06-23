import 'package:flutter/widgets.dart';
import '../theme/spacing.dart';

/// Wraps a tappable surface with a subtle press-scale, honouring reduced motion.
class Tappable extends StatefulWidget {
  const Tappable({
    super.key,
    required this.child,
    this.onTap,
    this.scale = 0.98,
    this.semanticLabel,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double scale;
  final String? semanticLabel;

  @override
  State<Tappable> createState() => _TappableState();
}

class _TappableState extends State<Tappable> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.of(context).disableAnimations;
    final pressed = _down && !reduce ? widget.scale : 1.0;
    return Semantics(
      button: widget.onTap != null,
      label: widget.semanticLabel,
      child: GestureDetector(
        onTap: widget.onTap,
        onTapDown: (_) => setState(() => _down = true),
        onTapUp: (_) => setState(() => _down = false),
        onTapCancel: () => setState(() => _down = false),
        behavior: HitTestBehavior.opaque,
        child: AnimatedScale(
          scale: pressed,
          duration: Motion.fast,
          curve: const Cubic(0.22, 1, 0.36, 1),
          child: widget.child,
        ),
      ),
    );
  }
}
