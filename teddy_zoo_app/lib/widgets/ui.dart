import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme.dart';

const _bearSvg =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48" fill="none" stroke="#1C1714" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"><circle cx="13" cy="13" r="5"/><circle cx="35" cy="13" r="5"/><circle cx="24" cy="26" r="14"/><ellipse cx="24" cy="30" rx="6" ry="4.5"/><circle cx="18.5" cy="22" r="1.3" fill="#1C1714"/><circle cx="29.5" cy="22" r="1.3" fill="#1C1714"/></svg>';
const pawSvg =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100" fill="#1C1714"><path d="M50 44c-14 0-28 12-28 26 0 8 6 12 13 12 6 0 10-3 15-3s9 3 15 3c7 0 13-4 13-12 0-14-14-26-28-26z"/><ellipse cx="22" cy="40" rx="9" ry="12" transform="rotate(-22 22 40)"/><ellipse cx="40" cy="24" rx="9.5" ry="13"/><ellipse cx="60" cy="24" rx="9.5" ry="13"/><ellipse cx="78" cy="40" rx="9" ry="12" transform="rotate(22 78 40)"/></svg>';

/// Round-cornered avatar on the brand ground: the elephant icon for
/// elephants (and unknown species), a line bear for bears, a paw for the rest.
class Avatar extends StatelessWidget {
  const Avatar(this.species, {super.key, this.size = 52, this.shadow = false});
  final String? species;
  final double size;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    final b = Brand.of(context);
    final s = (species ?? '').toLowerCase();
    Widget child;
    if (s == 'elephant' || s.isEmpty) {
      child = SvgPicture.asset('assets/brand/icon.svg', width: size, height: size, fit: BoxFit.cover);
    } else {
      child = Padding(
        padding: EdgeInsets.all(size * .12),
        child: SvgPicture.string(s == 'bear' ? _bearSvg : pawSvg, colorFilter: ColorFilter.mode(b.onBrand, BlendMode.srcIn)),
      );
    }
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: b.brand,
        borderRadius: BorderRadius.circular(size * .3),
        boxShadow: shadow ? [BoxShadow(color: b.brand.withValues(alpha: .45), blurRadius: 36, offset: const Offset(0, 16))] : null,
      ),
      child: child,
    );
  }
}

class Wordmark extends StatelessWidget {
  const Wordmark({super.key, this.height = 22});
  final double height;
  @override
  Widget build(BuildContext context) => SvgPicture.asset('assets/brand/wordmark.svg', height: height, semanticsLabel: 'IoME');
}

/// The card: --card ground, 22 radius, soft shadow.
class Card22 extends StatelessWidget {
  const Card22({super.key, required this.child, this.padding, this.onTap, this.opacity = 1});
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final b = Brand.of(context);
    Widget w = Container(
      decoration: BoxDecoration(color: b.card, borderRadius: BorderRadius.circular(Brand.rCard), boxShadow: b.shadow),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(Brand.rCard),
          child: Padding(padding: padding ?? EdgeInsets.zero, child: child),
        ),
      ),
    );
    if (opacity != 1) w = Opacity(opacity: opacity, child: w);
    return w;
  }
}

enum BtnKind { primary, secondary, quiet, danger }

/// .btn / .btn.secondary / .btn.quiet / .btn.danger
class Btn extends StatelessWidget {
  const Btn(this.label, {super.key, this.onPressed, this.kind = BtnKind.primary, this.icon, this.expand = true});
  final String label;
  final VoidCallback? onPressed;
  final BtnKind kind;
  final Widget? icon;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final b = Brand.of(context);
    final disabled = onPressed == null;
    final (bg, fg, border, h) = switch (kind) {
      BtnKind.primary => (b.brand, b.onBrand, null, 52.0),
      BtnKind.secondary => (Colors.transparent, b.ink, b.line, 52.0),
      BtnKind.quiet => (Colors.transparent, b.mute, null, 44.0),
      BtnKind.danger => (Colors.transparent, b.err, null, 44.0),
    };
    final child = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[IconTheme(data: IconThemeData(color: fg, size: 22), child: icon!), const SizedBox(width: 10)],
        Flexible(child: Text(label, textAlign: TextAlign.center, style: display(size: 16, color: fg, letterSpacing: .3))),
      ],
    );
    return Opacity(
      opacity: disabled ? .45 : 1,
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(Brand.rCtl),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(Brand.rCtl),
          child: Container(
            constraints: BoxConstraints(minHeight: h),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Brand.rCtl),
              border: border != null ? Border.all(color: border, width: 2) : null,
            ),
            child: Center(child: child),
          ),
        ),
      ),
    );
  }
}

/// .pill and .pill.primary
class Pill extends StatelessWidget {
  const Pill(this.label, {super.key, this.onPressed, this.primary = false, this.expand = false});
  final String label;
  final VoidCallback? onPressed;
  final bool primary;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final b = Brand.of(context);
    final w = Opacity(
      opacity: onPressed == null ? .45 : 1,
      child: Material(
        color: primary ? b.brand : b.paper,
        borderRadius: BorderRadius.circular(Brand.rPill),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(Brand.rPill),
          child: Container(
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Brand.rPill),
              border: primary ? null : Border.all(color: b.line, width: 1.5),
            ),
            alignment: Alignment.center,
            child: Text(label, style: body(size: 14, weight: FontWeight.w500, color: primary ? b.onBrand : b.ink)),
          ),
        ),
      ),
    );
    return expand ? SizedBox(width: double.infinity, child: w) : w;
  }
}

/// .textbtn (accent coloured text button in the top bar)
class TextBtn extends StatelessWidget {
  const TextBtn(this.label, {super.key, this.onPressed});
  final String label;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) {
    final b = Brand.of(context);
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(minimumSize: const Size(44, 44), padding: const EdgeInsets.symmetric(horizontal: 12), foregroundColor: b.accent),
      child: Text(label, style: body(size: 15, weight: FontWeight.w500, color: b.accent)),
    );
  }
}

/// .back — chevron plus optional label, in --mute.
class BackLink extends StatelessWidget {
  const BackLink({super.key, this.label, required this.onTap});
  final String? label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final b = Brand.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Brand.rPill),
      child: Container(
        constraints: const BoxConstraints(minHeight: 44),
        padding: const EdgeInsets.only(right: 8),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.chevron_left_rounded, color: b.mute, size: 28),
          if (label != null) Text(label!, style: body(size: 15, weight: FontWeight.w500, color: b.mute)),
        ]),
      ),
    );
  }
}

class Eyebrow extends StatelessWidget {
  const Eyebrow(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) =>
      Text(text.toUpperCase(), style: body(size: 12, weight: FontWeight.w600, color: Brand.of(context).mute, letterSpacing: 1.4));
}

class Sub extends StatelessWidget {
  const Sub(this.text, {super.key, this.align, this.color});
  final String text;
  final TextAlign? align;
  final Color? color;
  @override
  Widget build(BuildContext context) => Text(text, textAlign: align, style: body(size: 13, color: color ?? Brand.of(context).mute));
}

class Lead extends StatelessWidget {
  const Lead(this.text, {super.key, this.align});
  final String text;
  final TextAlign? align;
  @override
  Widget build(BuildContext context) => Text(text, textAlign: align, style: body(size: 15, color: Brand.of(context).mute));
}

class H1 extends StatelessWidget {
  const H1(this.text, {super.key, this.size = 28, this.align});
  final String text;
  final double size;
  final TextAlign? align;
  @override
  Widget build(BuildContext context) => Text(text, textAlign: align, style: display(size: size, color: Brand.of(context).ink, height: 1.15));
}

class H2 extends StatelessWidget {
  const H2(this.text, {super.key, this.size = 17});
  final String text;
  final double size;
  @override
  Widget build(BuildContext context) => Text(text, style: display(size: size, color: Brand.of(context).ink));
}

/// Status dot: off (--line), on (--brand) or busy (blinking --brand).
class Dot extends StatefulWidget {
  const Dot({super.key, this.on = false, this.busy = false, this.size = 10});
  final bool on, busy;
  final double size;
  @override
  State<Dot> createState() => _DotState();
}

class _DotState extends State<Dot> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 1));
  @override
  void initState() {
    super.initState();
    if (widget.busy) _c.repeat();
  }

  @override
  void didUpdateWidget(Dot old) {
    super.didUpdateWidget(old);
    if (widget.busy && !_c.isAnimating) _c.repeat();
    if (!widget.busy && _c.isAnimating) _c.stop();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final b = Brand.of(context);
    final dot = Container(width: widget.size, height: widget.size, decoration: BoxDecoration(shape: BoxShape.circle, color: widget.on || widget.busy ? b.brand : b.line));
    if (!widget.busy) return dot;
    return AnimatedBuilder(
      animation: _c,
      builder: (_, child) => Opacity(opacity: _c.value < .5 ? 1 : .25, child: child),
      child: dot,
    );
  }
}

/// The IoME heart, beating, used as the "online" live dot.
class Heart extends StatefulWidget {
  const Heart({super.key, this.size = 13});
  final double size;
  @override
  State<Heart> createState() => _HeartState();
}

class _HeartState extends State<Heart> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  double _scale(double t) {
    if (t < .15) return 1 + .25 * (t / .15);
    if (t < .30) return 1.25 - .25 * ((t - .15) / .15);
    if (t < .45) return 1 + .15 * ((t - .30) / .15);
    if (t < .60) return 1.15 - .15 * ((t - .45) / .15);
    return 1;
  }

  @override
  Widget build(BuildContext context) {
    final b = Brand.of(context);
    return AnimatedBuilder(
      animation: _c,
      builder: (_, child) => Transform.scale(scale: _scale(_c.value), child: child),
      child: SvgPicture.asset('assets/brand/heart.svg', width: widget.size, height: widget.size * 12 / 13, colorFilter: ColorFilter.mode(b.brand, BlendMode.srcIn)),
    );
  }
}

/// .status row: dot/heart + text, red when bad.
class StatusRow extends StatelessWidget {
  const StatusRow(this.text, {super.key, this.on = false, this.busy = false, this.bad = false, this.heart = false});
  final String text;
  final bool on, busy, bad, heart;
  @override
  Widget build(BuildContext context) {
    final b = Brand.of(context);
    return Row(children: [
      heart ? const Heart() : Dot(on: on, busy: busy),
      const SizedBox(width: 8),
      Expanded(child: Text(text, style: body(size: 14, color: bad ? b.err : b.mute))),
    ]);
  }
}

/// .badge.mine / .badge.linked
class Tag extends StatelessWidget {
  const Tag(this.text, {super.key, this.mine = true});
  final String text;
  final bool mine;
  @override
  Widget build(BuildContext context) {
    final b = Brand.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: mine ? b.brand : b.accentSoft, borderRadius: BorderRadius.circular(Brand.rPill)),
      child: Text(text.toUpperCase(), style: body(size: 11, weight: FontWeight.w600, color: mine ? b.onBrand : b.accent, letterSpacing: .7, height: 1.4)),
    );
  }
}

/// .seg — segmented control on the --line track.
class Seg<T> extends StatelessWidget {
  const Seg({super.key, required this.value, required this.items, required this.onChanged, this.small = false, this.enabled = true});
  final T value;
  final List<(T, String)> items;
  final ValueChanged<T>? onChanged;
  final bool small;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final b = Brand.of(context);
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: b.line, borderRadius: BorderRadius.circular(Brand.rCtl)),
      child: Row(
        mainAxisSize: small ? MainAxisSize.min : MainAxisSize.max,
        children: [
          for (final (i, (v, l)) in items.indexed) ...[
            if (i > 0) const SizedBox(width: 2),
            _segBtn(b, v, l),
          ],
        ],
      ),
    );
  }

  Widget _segBtn(Brand b, T v, String l) {
    final sel = v == value;
    final btn = Opacity(
      opacity: enabled ? 1 : .45,
      child: Material(
        color: sel ? b.card : Colors.transparent,
        borderRadius: BorderRadius.circular(11),
        elevation: sel ? 1 : 0,
        shadowColor: Colors.black.withValues(alpha: .4),
        child: InkWell(
          onTap: enabled && onChanged != null ? () => onChanged!(v) : null,
          borderRadius: BorderRadius.circular(11),
          child: Container(
            constraints: BoxConstraints(minHeight: small ? 36 : 42),
            padding: EdgeInsets.symmetric(horizontal: small ? 12 : 4),
            alignment: Alignment.center,
            child: Text(l, style: body(size: small ? 14 : 15, weight: FontWeight.w500, color: sel ? b.ink : b.mute)),
          ),
        ),
      ),
    );
    return small ? btn : Expanded(child: btn);
  }
}

/// .chip
class Chip40 extends StatelessWidget {
  const Chip40(this.label, {super.key, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final b = Brand.of(context);
    return Material(
      color: selected ? b.ink : b.card,
      borderRadius: BorderRadius.circular(Brand.rPill),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Brand.rPill),
        child: Container(
          constraints: const BoxConstraints(minHeight: 40),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(Brand.rPill), border: selected ? null : Border.all(color: b.line, width: 1.5)),
          alignment: Alignment.center,
          child: Text(label, style: display(size: 15, weight: FontWeight.w500, color: selected ? b.paper : b.ink)),
        ),
      ),
    );
  }
}

/// .rows card: rows separated by hairlines.
class RowsCard extends StatelessWidget {
  const RowsCard({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) {
    final b = Brand.of(context);
    return Card22(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(children: [
        for (final (i, c) in children.indexed) ...[
          if (i > 0) Divider(height: 1, thickness: 1, color: b.line),
          c,
        ],
      ]),
    );
  }
}

/// One .rows row: key on the left, value (+ chevron) on the right.
class KvRow extends StatelessWidget {
  const KvRow(this.k, {super.key, this.v, this.valueWidget, this.onTap, this.chevron = false, this.mono = false, this.minHeight = 52});
  final String k;
  final String? v;
  final Widget? valueWidget;
  final VoidCallback? onTap;
  final bool chevron, mono;
  final double minHeight;
  @override
  Widget build(BuildContext context) {
    final b = Brand.of(context);
    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: BoxConstraints(minHeight: minHeight),
        child: Row(children: [
          Text(k, style: body(size: 15, color: b.mute)),
          const SizedBox(width: 12),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: valueWidget ??
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Flexible(child: Text(v ?? '', textAlign: TextAlign.right, overflow: TextOverflow.ellipsis, style: mono ? monoStyle(context) : body(size: 15, weight: FontWeight.w500, color: b.ink))),
                    if (chevron) ...[const SizedBox(width: 6), Icon(Icons.chevron_right_rounded, size: 18, color: b.line)],
                  ]),
            ),
          ),
        ]),
      ),
    );
  }
}

TextStyle monoStyle(BuildContext context, {double size = 15, double? letterSpacing}) => mono(size: size, color: Brand.of(context).ink, letterSpacing: letterSpacing);

/// .mini — avatar + two lines + dot, used for link lists.
class MiniRow extends StatelessWidget {
  const MiniRow({super.key, required this.species, required this.title, required this.sub, required this.online});
  final String? species;
  final String title;
  final String sub;
  final bool online;
  @override
  Widget build(BuildContext context) {
    final b = Brand.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 44),
      child: Row(children: [
        Avatar(species, size: 36),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: body(size: 16, weight: FontWeight.w500, color: b.ink)),
            Sub(sub),
          ]),
        ),
        Dot(on: online),
      ]),
    );
  }
}

/// .field label + control
class Field extends StatelessWidget {
  const Field(this.label, {super.key, required this.child, this.help});
  final String label;
  final Widget child;
  final String? help;
  @override
  Widget build(BuildContext context) {
    final b = Brand.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: body(size: 13, weight: FontWeight.w600, color: b.mute)),
      const SizedBox(height: 6),
      child,
      if (help != null) ...[const SizedBox(height: 6), Text(help!, style: body(size: 12, color: b.mute))],
    ]);
  }
}

/// WiFi signal bars (1–4 of 4).
class Bars extends StatelessWidget {
  const Bars(this.n, {super.key});
  final int n;
  @override
  Widget build(BuildContext context) {
    final b = Brand.of(context);
    return SizedBox(
      width: 24,
      height: 18,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var k = 1; k <= 4; k++) ...[
            if (k > 1) const SizedBox(width: 3),
            Container(width: 4, height: 2.0 + k * 4, decoration: BoxDecoration(color: n >= k ? b.ink : b.line, borderRadius: BorderRadius.circular(2))),
          ],
        ],
      ),
    );
  }
}

int barsFor(int rssi) => rssi > -55 ? 4 : rssi > -65 ? 3 : rssi > -75 ? 2 : 1;

/// .radio
class Radio22 extends StatelessWidget {
  const Radio22(this.on, {super.key});
  final bool on;
  @override
  Widget build(BuildContext context) {
    final b = Brand.of(context);
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(shape: BoxShape.circle, color: b.card, border: Border.all(color: on ? b.brand : b.line, width: 1.5)),
      child: on ? Center(child: Container(width: 10, height: 10, decoration: BoxDecoration(shape: BoxShape.circle, color: b.brand))) : null,
    );
  }
}

/// Step progress: 4 short bars, the first [on] lit.
class Steps extends StatelessWidget {
  const Steps(this.on, {super.key, this.total = 4});
  final int on, total;
  @override
  Widget build(BuildContext context) {
    final b = Brand.of(context);
    return Row(mainAxisSize: MainAxisSize.min, children: [
      for (var i = 0; i < total; i++) ...[
        if (i > 0) const SizedBox(width: 6),
        Container(width: 24, height: 6, decoration: BoxDecoration(color: i < on ? b.brand : b.line, borderRadius: BorderRadius.circular(3))),
      ],
    ]);
  }
}

/// Scanning animation: four brand bars blinking in turn.
class ScanningBars extends StatefulWidget {
  const ScanningBars({super.key});
  @override
  State<ScanningBars> createState() => _ScanningBarsState();
}

class _ScanningBarsState extends State<ScanningBars> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final b = Brand.of(context);
    return AnimatedBuilder(
      animation: _c,
      builder: (_, _) => Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var k = 0; k < 4; k++) ...[
            if (k > 0) const SizedBox(width: 6),
            Opacity(
              opacity: ((_c.value - k / 6) % 1) < .5 ? 1 : .25,
              child: Container(width: 6, height: const [8.0, 14.0, 20.0, 24.0][k], decoration: BoxDecoration(color: b.brand, borderRadius: BorderRadius.circular(2))),
            ),
          ],
        ],
      ),
    );
  }
}

/// Standard screen scaffold: paper ground, 16 px gutters, safe areas, 420 max width.
class Screen extends StatelessWidget {
  const Screen({super.key, required this.top, required this.children, this.bottom, this.scroll = true});
  final Widget top;
  final List<Widget> children;
  final Widget? bottom;
  final bool scroll;

  @override
  Widget build(BuildContext context) {
    final b = Brand.of(context);
    final col = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SizedBox(height: 48, child: top),
      const SizedBox(height: 12),
      for (final (i, c) in children.indexed) ...[if (i > 0) const SizedBox(height: 16), c],
    ]);
    return Scaffold(
      backgroundColor: b.paper,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Column(children: [
                Expanded(
                  child: scroll
                      ? SingleChildScrollView(padding: EdgeInsets.only(bottom: bottom != null ? 16 : 24), child: col)
                      : col,
                ),
                if (bottom != null) Padding(padding: const EdgeInsets.only(bottom: 16, top: 8), child: bottom),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet with the grab handle, matching .sheet.
Future<T?> showSheet<T>(BuildContext context, {required Widget Function(BuildContext) builder}) {
  final b = Brand.of(context);
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    barrierColor: const Color(0x731C1714),
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * .88),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(16, 10, 16, math.max(16, MediaQuery.paddingOf(ctx).bottom)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: b.line, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 14),
            builder(ctx),
          ]),
        ),
      ),
    ),
  );
}

Future<bool> confirm(BuildContext context, String message, {String ok = 'OK'}) async {
  final b = Brand.of(context);
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel', style: body(size: 15, weight: FontWeight.w500, color: b.mute))),
        TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(ok, style: body(size: 15, weight: FontWeight.w600, color: b.accent))),
      ],
    ),
  );
  return r ?? false;
}

Future<void> alert(BuildContext context, String message) => showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(message),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text('OK', style: body(size: 15, weight: FontWeight.w600, color: Brand.of(ctx).accent)))],
      ),
    );

Future<String?> promptText(BuildContext context, String message, {String? hint}) async {
  final ctl = TextEditingController();
  final b = Brand.of(context);
  final r = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(message),
        const SizedBox(height: 12),
        TextField(controller: ctl, autofocus: true, decoration: InputDecoration(hintText: hint), textCapitalization: TextCapitalization.words, onSubmitted: (v) => Navigator.pop(ctx, v)),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: body(size: 15, weight: FontWeight.w500, color: b.mute))),
        TextButton(onPressed: () => Navigator.pop(ctx, ctl.text), child: Text('OK', style: body(size: 15, weight: FontWeight.w600, color: b.accent))),
      ],
    ),
  );
  return r;
}

void toast(BuildContext context, String text) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text), duration: const Duration(milliseconds: 1500)));
}
