import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../theme/app_theme.dart';
import 'responsive.dart';

/// White surface with a thin border. No shadows anywhere in the app.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final Color? color;
  final Color? borderColor;
  final double radius;
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.color,
    this.borderColor,
    this.radius = 10,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: color ?? C.surface,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: borderColor ?? C.line),
    ),
    child: child,
  );
}

/// Tracks hover / press and animates a subtle scale. Used by buttons and clickable cards.
class HoverBuilder extends StatefulWidget {
  final VoidCallback? onTap;
  final double hoverScale;
  final Widget Function(BuildContext context, bool hover) builder;
  const HoverBuilder({
    super.key,
    required this.builder,
    this.onTap,
    this.hoverScale = 1.02,
  });
  @override
  State<HoverBuilder> createState() => _HoverBuilderState();
}

class _HoverBuilderState extends State<HoverBuilder> {
  bool hover = false, pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => hover = true),
      onExit: (_) => setState(() {
        hover = false;
        pressed = false;
      }),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (_) => setState(() => pressed = true) : null,
        onTapUp: enabled ? (_) => setState(() => pressed = false) : null,
        onTapCancel: enabled ? () => setState(() => pressed = false) : null,
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: !enabled
              ? 1
              : pressed
              ? .97
              : hover
              ? widget.hoverScale
              : 1,
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          child: widget.builder(context, hover && enabled),
        ),
      ),
    );
  }
}

/// Lifts a clickable card slightly on hover.
class HoverLift extends StatefulWidget {
  final Widget child;
  const HoverLift({super.key, required this.child});
  @override
  State<HoverLift> createState() => _HoverLiftState();
}

class _HoverLiftState extends State<HoverLift> {
  bool hover = false;
  @override
  Widget build(BuildContext context) => MouseRegion(
    onEnter: (_) => setState(() => hover = true),
    onExit: (_) => setState(() => hover = false),
    child: AnimatedSlide(
      offset: hover ? const Offset(0, -.012) : Offset.zero,
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      child: widget.child,
    ),
  );
}

class PrimaryButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final double height;
  final bool expand;
  final bool busy;
  const PrimaryButton(
    this.label, {
    super.key,
    this.icon,
    this.onTap,
    this.height = 40,
    this.expand = true,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null && !busy;
    final btn = HoverBuilder(
      onTap: enabled ? onTap : null,
      hoverScale: 1.0,
      builder: (context, hover) => AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        height: height,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: !enabled
              ? C.brand.withValues(alpha: .45)
              : hover
              ? C.brandDark
              : C.brand,
          borderRadius: BorderRadius.circular(8),
        ),
        child: busy
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: Colors.white,
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                      style: sans(14, w: FontWeight.w500, color: Colors.white),
                    ),
                  ),
                  if (icon != null) ...[
                    const SizedBox(width: 8),
                    AnimatedSlide(
                      offset: hover ? const Offset(.25, 0) : Offset.zero,
                      duration: const Duration(milliseconds: 160),
                      curve: Curves.easeOut,
                      child: Icon(icon, color: Colors.white, size: 17),
                    ),
                  ],
                ],
              ),
      ),
    );
    return expand
        ? SizedBox(width: double.infinity, child: btn)
        : IntrinsicWidth(child: btn);
  }
}

class OutlineBtn extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool pink;
  final double height;
  final bool expand;
  const OutlineBtn(
    this.label, {
    super.key,
    this.icon,
    this.onTap,
    this.pink = false,
    this.height = 38,
    this.expand = false,
  });

  @override
  Widget build(BuildContext context) {
    final fg = pink ? C.brand : C.ink;
    final enabled = onTap != null;
    final child = HoverBuilder(
      onTap: onTap,
      builder: (context, hover) => AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        height: height,
        padding: EdgeInsets.symmetric(horizontal: expand ? 8 : 16),
        decoration: BoxDecoration(
          color: pink
              ? (hover ? const Color(0xFFFBDDE4) : C.brandSoft)
              : (hover ? const Color(0xFFF7F5F4) : Colors.white),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: hover
                ? (pink ? C.brand : C.brandBorder)
                : (pink ? C.brandBorder : C.line),
          ),
        ),
        child: Opacity(
          opacity: enabled ? 1 : .5,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, color: fg, size: 17),
                if (label.isNotEmpty) const SizedBox(width: 8),
              ],
              if (label.isNotEmpty)
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: sans(13, w: FontWeight.w500, color: fg),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    return expand ? SizedBox(width: double.infinity, child: child) : child;
  }
}

class Pill extends StatelessWidget {
  final String label;
  final Color fg, bg;
  final IconData? icon;
  const Pill(
    this.label, {
    super.key,
    required this.fg,
    required this.bg,
    this.icon,
  });
  factory Pill.premium() =>
      const Pill('Premium', fg: C.brand, bg: Color(0xFFFCE3E9));
  factory Pill.essential() =>
      const Pill('Essential', fg: C.muted, bg: Color(0xFFF1EEED));

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: fg.withValues(alpha: .18)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 13, color: fg),
          const SizedBox(width: 4),
        ],
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: sans(11.5, w: FontWeight.w600, color: fg),
          ),
        ),
      ],
    ),
  );
}

Pill statusPill(String status, {bool ended = false}) {
  if (ended) return const Pill('Ended', fg: C.muted, bg: Color(0xFFF1EEED));
  return switch (status) {
    'published' => const Pill(
      'Published',
      fg: C.green,
      bg: C.greenSoft,
      icon: Icons.check_circle_outline_rounded,
    ),
    'draft' => const Pill(
      'Draft',
      fg: Color(0xFFB7791F),
      bg: Color(0xFFFFF3DD),
      icon: Icons.edit_outlined,
    ),
    _ => const Pill('Ended', fg: C.muted, bg: Color(0xFFF1EEED)),
  };
}

Pill rsvpPill(String rsvp) {
  final (label, fg, bg, ic) = switch (rsvp) {
    'yes' => ('Yes', C.green, C.greenSoft, Icons.check_rounded),
    'no' => ('No', C.red, const Color(0xFFFDEAEA), Icons.close_rounded),
    'maybe' => (
      'Maybe',
      C.purple,
      const Color(0xFFEEEBFC),
      Icons.help_outline_rounded,
    ),
    _ => ('Pending', C.amber, const Color(0xFFFFF3DD), Icons.schedule_rounded),
  };
  return Pill(label, fg: fg, bg: bg, icon: ic);
}

class Dot extends StatelessWidget {
  final Color color;
  const Dot(this.color, {super.key});
  @override
  Widget build(BuildContext context) => Container(
    width: 8,
    height: 8,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}

class SplashMark extends StatelessWidget {
  const SplashMark({super.key});
  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: const Size(30, 26), painter: _SplashPainter());
}

class _SplashPainter extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    Paint p(Color col) => Paint()
      ..color = col
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    c.drawLine(const Offset(9, 18), const Offset(5, 4), p(C.brand));
    c.drawLine(const Offset(16, 14), const Offset(27, 7), p(C.brand));
    c.drawLine(const Offset(19, 22), const Offset(29, 20), p(C.amber));
  }

  @override
  bool shouldRepaint(_) => false;
}

class PageTitle extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;
  const PageTitle(this.title, [this.subtitle, this.icon]);
  @override
  Widget build(BuildContext context) {
    final m = isMobile(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: m ? 22 : 26, color: C.ink),
              const SizedBox(width: 10),
            ],
            Flexible(child: Text(title, style: serif(m ? 24 : 30, h: 1.15))),
          ],
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 6),
          Text(subtitle!, style: sans(m ? 14 : 15, color: C.muted)),
        ],
      ],
    );
  }
}

class Logo extends StatelessWidget {
  final double height;

  /// Uses the full logo (envelope + wordmark) instead of the wordmark alone.
  final bool full;
  const Logo({super.key, this.height = 34, this.full = false});
  @override
  Widget build(BuildContext context) => Image.asset(
    full ? 'assets/logo.png' : 'assets/logo_wordmark.png',
    height: height,
    fit: BoxFit.contain,
  );
}

class LogoIcon extends StatelessWidget {
  final double height;
  const LogoIcon({super.key, this.height = 80});
  @override
  Widget build(BuildContext context) =>
      Image.asset('assets/logo_icon.png', height: height, fit: BoxFit.contain);
}

/// Initials avatar (no photos are stored).
class Avatar extends StatelessWidget {
  final String name;
  final double size;
  const Avatar(this.name, {super.key, this.size = 40});
  @override
  Widget build(BuildContext context) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    final initials = parts.isEmpty
        ? '?'
        : (parts.length == 1 ? parts.first[0] : parts.first[0] + parts.last[0])
              .toUpperCase();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFFF1EEED),
        border: Border.all(color: C.line),
      ),
      child: Text(
        initials,
        style: sans(size * .36, w: FontWeight.w600, color: C.ink),
      ),
    );
  }
}

class PhoneFrame extends StatelessWidget {
  final Widget child;
  final double width;
  const PhoneFrame({super.key, required this.child, this.width = 200});
  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: width * 2.05,
    padding: EdgeInsets.all(width * .03),
    decoration: BoxDecoration(
      color: const Color(0xFF1A1A1F),
      borderRadius: BorderRadius.circular(width * .17),
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(width * .14),
      child: Stack(
        fit: StackFit.expand,
        children: [
          child,
          Positioned(
            top: width * .03,
            left: width * .32,
            right: width * .32,
            height: width * .07,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1F),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// A real, scannable QR code.
class QrBox extends StatelessWidget {
  final String data;
  final double size;
  const QrBox({super.key, required this.data, this.size = 100});
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: C.line),
    ),
    child: QrImageView(
      data: data,
      padding: EdgeInsets.zero,
      eyeStyle: const QrEyeStyle(color: C.ink, eyeShape: QrEyeShape.square),
      dataModuleStyle: const QrDataModuleStyle(
        color: C.ink,
        dataModuleShape: QrDataModuleShape.square,
      ),
    ),
  );
}

/// Wizard / event progress. Compact (dots + caption) on phones.
class StepperBar extends StatelessWidget {
  final int
  current; // 1-based; current > labels.length means every step is done
  final List<String> labels;
  final ValueChanged<int>? onTap;
  const StepperBar({
    super.key,
    required this.current,
    this.labels = const ['Event', 'Template', 'Edit', 'Guests', 'Publish'],
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final n = labels.length;
    final mobile = isMobile(context);
    final bar = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < n; i++)
          Expanded(
            child: InkWell(
              onTap: onTap != null && i + 1 <= current
                  ? () => onTap!(i + 1)
                  : null,
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 2,
                          color: i == 0
                              ? Colors.transparent
                              : (i < current ? C.brand : C.line),
                        ),
                      ),
                      _node(i + 1),
                      Expanded(
                        child: Container(
                          height: 2,
                          color: i == n - 1
                              ? Colors.transparent
                              : (i + 1 < current ? C.brand : C.line),
                        ),
                      ),
                    ],
                  ),
                  if (!mobile) ...[
                    const SizedBox(height: 6),
                    Text(
                      labels[i],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: sans(
                        13,
                        color: i + 1 == current ? C.ink : C.muted,
                        w: i + 1 == current ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
    if (!mobile || current > n) return bar;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        bar,
        const SizedBox(height: 8),
        Text(
          'Step $current of $n · ${labels[current - 1]}',
          style: sans(13, w: FontWeight.w600, color: C.ink),
        ),
      ],
    );
  }

  Widget _node(int i) {
    final done = i < current, active = i == current;
    return Container(
      width: 26,
      height: 26,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: done || active ? C.brand : Colors.white,
        border: Border.all(
          color: done || active ? C.brand : C.line,
          width: 1.5,
        ),
      ),
      child: done
          ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
          : Text(
              '$i',
              style: sans(
                12,
                w: FontWeight.w600,
                color: active ? Colors.white : C.muted,
              ),
            ),
    );
  }
}

class HeaderRow extends StatelessWidget {
  final String title;
  final Widget? trailing;
  const HeaderRow(this.title, {super.key, this.trailing});
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(child: Text(title, style: serif(19))),
      if (trailing != null) ...[const SizedBox(width: 8), trailing!],
    ],
  );
}

class LinkText extends StatelessWidget {
  final String label;
  final bool arrow;
  final VoidCallback? onTap;
  const LinkText(this.label, {super.key, this.arrow = false, this.onTap});
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: sans(13, w: FontWeight.w600, color: C.brand),
        ),
        if (arrow) ...[
          const SizedBox(width: 4),
          const Icon(Icons.arrow_forward_rounded, size: 15, color: C.brand),
        ],
      ],
    ),
  );
}

class LoadingView extends StatelessWidget {
  const LoadingView({super.key});
  @override
  Widget build(BuildContext context) => const Center(
    child: Padding(
      padding: EdgeInsets.all(40),
      child: CircularProgressIndicator(color: C.brand),
    ),
  );
}

class ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const ErrorView(this.message, {super.key, required this.onRetry});
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_rounded, size: 40, color: C.muted),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center, style: sans(14)),
          const SizedBox(height: 16),
          OutlineBtn('Try again', icon: Icons.refresh_rounded, onTap: onRetry),
        ],
      ),
    ),
  );
}

void toast(BuildContext context, String msg, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: error ? C.red : C.ink,
        content: Text(msg, style: sans(13, color: Colors.white)),
      ),
    );
}

/// Field used across forms.
class Field extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String? hint;
  final int maxLines;
  final TextInputType? keyboard;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;
  final List<String>? autofill;
  const Field(
    this.label,
    this.controller, {
    super.key,
    this.hint,
    this.maxLines = 1,
    this.keyboard,
    this.onChanged,
    this.onSubmitted,
    this.autofocus = false,
    this.autofill,
  });
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: sans(12.5, w: FontWeight.w500, color: C.ink),
      ),
      const SizedBox(height: 6),
      TextField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboard,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        autofocus: autofocus,
        autofillHints: autofill,
        style: sans(14, color: C.ink),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: sans(14, color: C.muted),
          isDense: true,
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 14,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: C.line),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: C.line),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: C.brand, width: 1.5),
          ),
        ),
      ),
    ],
  );
}

/// Pill-shaped select built on PopupMenuButton (no overflow, works at any width).
class SelectBox<T> extends StatelessWidget {
  final String label;
  final T? value;
  final List<(T, String)> options;
  final ValueChanged<T?> onChanged;
  final String anyLabel;
  const SelectBox({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    this.anyLabel = 'Any',
  });
  @override
  Widget build(BuildContext context) {
    final current = options
        .where((o) => o.$1 == value)
        .map((o) => o.$2)
        .firstOrNull;
    return PopupMenuButton<int>(
      tooltip: '',
      color: Colors.white,
      onSelected: (i) => onChanged(i < 0 ? null : options[i].$1),
      itemBuilder: (_) => [
        PopupMenuItem(value: -1, child: Text(anyLabel, style: sans(14))),
        for (final (i, o) in options.indexed)
          PopupMenuItem(
            value: i,
            child: Text(o.$2, style: sans(14)),
          ),
      ],
      child: Container(
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: C.line),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                current ?? label,
                overflow: TextOverflow.ellipsis,
                style: sans(14, color: current == null ? C.muted : C.ink),
              ),
            ),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 20,
              color: C.ink,
            ),
          ],
        ),
      ),
    );
  }
}

IconData categoryIcon(String key) => switch (key) {
  'cake' => Icons.cake_outlined,
  'child' => Icons.child_care_rounded,
  'ring' => Icons.diamond_outlined,
  'heart' => Icons.favorite_border_rounded,
  'school' => Icons.school_outlined,
  'glass' => Icons.wine_bar_outlined,
  'rainbow' => Icons.looks_rounded,
  'dress' => Icons.checkroom_outlined,
  'church' => Icons.church_outlined,
  'party' => Icons.celebration_outlined,
  'work' => Icons.work_outline_rounded,
  'flight' => Icons.flight_outlined,
  'dinner' => Icons.restaurant_outlined,
  _ => Icons.more_horiz_rounded,
};

/// One-time code input: a row of boxes backed by a single hidden field (supports paste and autofill).
class PinInput extends StatefulWidget {
  final TextEditingController controller;
  final int length;
  final ValueChanged<String>? onCompleted;
  final bool autofocus;
  const PinInput({
    super.key,
    required this.controller,
    this.length = 8,
    this.onCompleted,
    this.autofocus = true,
  });
  @override
  State<PinInput> createState() => _PinInputState();
}

class _PinInputState extends State<PinInput> {
  final focus = FocusNode();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
    focus.addListener(() => setState(() {}));
  }

  void _changed() {
    setState(() {});
    if (widget.controller.text.length == widget.length)
      widget.onCompleted?.call(widget.controller.text);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = widget.controller.text;
    return GestureDetector(
      onTap: focus.requestFocus,
      child: Stack(
        children: [
          Row(
            children: [
              for (int i = 0; i < widget.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    height: 56,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color:
                            focus.hasFocus &&
                                i == text.length.clamp(0, widget.length - 1)
                            ? C.brand
                            : C.line,
                        width:
                            focus.hasFocus &&
                                i == text.length.clamp(0, widget.length - 1)
                            ? 1.8
                            : 1,
                      ),
                    ),
                    child: Text(
                      i < text.length ? text[i] : '',
                      style: sans(20, w: FontWeight.w600, color: C.ink),
                    ),
                  ),
                ),
              ],
            ],
          ),
          Positioned.fill(
            child: Opacity(
              opacity: 0,
              child: TextField(
                controller: widget.controller,
                focusNode: focus,
                autofocus: widget.autofocus,
                keyboardType: TextInputType.number,
                autofillHints: const [AutofillHints.oneTimeCode],
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(widget.length),
                ],
                showCursor: false,
                enableInteractiveSelection: false,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
