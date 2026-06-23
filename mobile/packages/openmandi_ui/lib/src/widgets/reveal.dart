import 'package:flutter/widgets.dart';
import '../theme/spacing.dart';

/// Staggered fade-up on first build. Reveal enhances already-laid-out content:
/// if animations are disabled, the child shows immediately at full opacity.
class Reveal extends StatefulWidget {
  const Reveal({super.key, required this.child, this.delay = Duration.zero});

  final Widget child;
  final Duration delay;

  @override
  State<Reveal> createState() => _RevealState();
}

class _RevealState extends State<Reveal> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: Motion.base,
  );
  late final Animation<double> _fade =
      CurvedAnimation(parent: _c, curve: const Cubic(0.22, 1, 0.36, 1));

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(widget.delay, () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) return widget.child;
    return AnimatedBuilder(
      animation: _fade,
      builder: (context, child) => Opacity(
        opacity: _fade.value,
        child: Transform.translate(
          offset: Offset(0, (1 - _fade.value) * 10),
          child: child,
        ),
      ),
      child: widget.child,
    );
  }
}
