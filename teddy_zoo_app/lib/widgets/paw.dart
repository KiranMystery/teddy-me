import 'dart:math' as math;

import 'package:flutter_svg/flutter_svg.dart';
import 'package:material_ui/material_ui.dart';

import '../theme.dart';
import 'ui.dart';

/// The 220 px paw button with the ripple rings and the wobble while held.
class PawButton extends StatefulWidget {
  const PawButton({required this.on, required this.enabled, required this.onDown, required this.onUp});
  final bool on, enabled;
  final VoidCallback onDown, onUp;
  @override
  State<PawButton> createState() => _PawButtonState();
}

class _PawButtonState extends State<PawButton> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));

  @override
  void didUpdateWidget(PawButton old) {
    super.didUpdateWidget(old);
    if (widget.on && !_c.isAnimating) _c.repeat();
    if (!widget.on && _c.isAnimating) _c.reset();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final b = Brand.of(context);
    final reduce = MediaQuery.disableAnimationsOf(context);
    const d = 220.0;
    Widget ring(double phase) => AnimatedBuilder(
          animation: _c,
          builder: (_, _) {
            if (!widget.on || reduce) return const SizedBox.shrink();
            final t = (_c.value + phase) % 1;
            return Opacity(
              opacity: (.7 * (1 - t)).clamp(0.0, 1.0),
              child: Transform.scale(scale: .93 + .42 * t, child: Container(width: d, height: d, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: b.brand, width: 3)))),
            );
          },
        );
    final light = Color.lerp(b.brand, Colors.white, .25)!;
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: widget.enabled ? (_) => widget.onDown() : null,
      onPointerUp: (_) => widget.onUp(),
      onPointerCancel: (_) => widget.onUp(),
      child: SizedBox(
        width: d + 80,
        height: d + 40,
        child: Stack(alignment: Alignment.center, children: [
          ring(0),
          ring(.5),
          AnimatedBuilder(
            animation: _c,
            builder: (_, child) {
              final wobble = widget.on && !reduce ? math.sin(_c.value * 2 * math.pi * 7.5) * 1.5 * math.pi / 180 : 0.0;
              return Transform.rotate(angle: wobble, child: Transform.scale(scale: widget.on ? .93 : 1, child: child));
            },
            child: Semantics(
              button: true,
              label: 'Hold to buzz',
              child: Opacity(
                opacity: widget.enabled ? 1 : .55,
                child: Container(
                  width: d,
                  height: d,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(center: const Alignment(-.3, -.44), radius: .75, colors: [light, b.brand], stops: const [0, .7]),
                    boxShadow: [
                      BoxShadow(color: b.brand.withValues(alpha: .45), blurRadius: widget.on ? 14 : 36, offset: Offset(0, widget.on ? 6 : 16)),
                    ],
                  ),
                  foregroundDecoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: widget.on ? Alignment.topCenter : Alignment.bottomCenter,
                      end: widget.on ? Alignment.center : const Alignment(0, .3),
                      colors: [Colors.black.withValues(alpha: widget.on ? .22 : .18), Colors.transparent],
                    ),
                  ),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    AnimatedScale(
                      scale: widget.on ? 1.08 : 1,
                      duration: const Duration(milliseconds: 80),
                      child: SvgPicture.string(pawSvg, width: 96, height: 96, colorFilter: ColorFilter.mode(b.onBrand, BlendMode.srcIn)),
                    ),
                    const SizedBox(height: 4),
                    Text((widget.on ? 'buzzing' : 'hold to buzz').toUpperCase(), style: display(size: 14, color: b.onBrand, letterSpacing: 1.7)),
                  ]),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

