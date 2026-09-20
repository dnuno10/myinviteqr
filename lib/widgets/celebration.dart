import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data/models.dart';
import '../theme/app_theme.dart';
import '../util/format.dart';
import 'common.dart';

class _Piece {
  final double angle, speed, size, spin, phase;
  final Color color;
  final int shape;
  final bool left;
  final double delay;
  _Piece(
    this.angle,
    this.speed,
    this.size,
    this.spin,
    this.phase,
    this.color,
    this.shape,
    this.left,
    this.delay,
  );
}

/// Two party-popper bursts from the bottom corners plus a light rain of confetti.
class ConfettiBurst extends StatefulWidget {
  const ConfettiBurst({super.key});
  @override
  State<ConfettiBurst> createState() => _ConfettiBurstState();
}

class _ConfettiBurstState extends State<ConfettiBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController ctl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 4200),
  )..forward();
  late final List<_Piece> pieces;

  @override
  void initState() {
    super.initState();
    final r = math.Random(7);
    const colors = [
      C.brand,
      C.amber,
      C.purple,
      Color(0xFF3AA0FF),
      C.green,
      Color(0xFFFFC94D),
      Color(0xFFFF8FA3),
    ];
    pieces = [
      for (int i = 0; i < 150; i++)
        _Piece(
          // left popper shoots up-right, right popper up-left
          (i.isEven
              ? -math.pi / 2 + .15 + r.nextDouble() * .9
              : -math.pi / 2 - .15 - r.nextDouble() * .9),
          .75 + r.nextDouble() * .85,
          6 + r.nextDouble() * 8,
          (r.nextDouble() - .5) * 14,
          r.nextDouble() * math.pi * 2,
          colors[r.nextInt(colors.length)],
          r.nextInt(3),
          i.isEven,
          i < 90 ? 0 : .25 + r.nextDouble() * .2,
        ),
      for (int i = 0; i < 40; i++)
        _Piece(
          math.pi / 2,
          .18 + r.nextDouble() * .2,
          5 + r.nextDouble() * 6,
          (r.nextDouble() - .5) * 10,
          r.nextDouble() * math.pi * 2,
          colors[r.nextInt(colors.length)],
          r.nextInt(3),
          false,
          .35 + r.nextDouble() * .5,
        ),
    ];
  }

  @override
  void dispose() {
    ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: AnimatedBuilder(
      animation: ctl,
      builder: (context, _) => CustomPaint(
        painter: _ConfettiPainter(pieces, ctl.value),
        size: Size.infinite,
      ),
    ),
  );
}

class _ConfettiPainter extends CustomPainter {
  final List<_Piece> pieces;
  final double t;
  _ConfettiPainter(this.pieces, this.t);
  @override
  void paint(Canvas c, Size s) {
    final total = 4.2;
    for (final p in pieces) {
      final tt =
          (t - p.delay / total * 1.0) *
          total; // seconds since this piece was launched
      if (tt < 0) continue;
      final rain = p.angle == math.pi / 2;
      double x, y;
      if (rain) {
        x =
            s.width * (p.phase / (math.pi * 2)) +
            math.sin(tt * 2 + p.phase) * 20;
        y = -20 + tt * s.height * p.speed * 1.2;
      } else {
        final origin = Offset(p.left ? 0 : s.width, s.height);
        final v = p.speed * s.height * 1.35;
        final g = s.height * 1.5;
        x =
            origin.dx +
            math.cos(p.angle) * v * tt * (p.left ? 1 : 1) * .78 +
            math.sin(tt * 3 + p.phase) * 6;
        y = origin.dy + math.sin(p.angle) * v * tt + .5 * g * tt * tt;
      }
      if (y > s.height + 30 || y < -60) continue;
      final fade = (1 - ((tt - 2.2) / 1.6).clamp(0, 1)).toDouble();
      final paint = Paint()..color = p.color.withValues(alpha: fade);
      c.save();
      c.translate(x, y);
      c.rotate(p.phase + tt * p.spin);
      // tumbling effect: squash one axis
      c.scale(1, (math.cos(tt * 6 + p.phase)).abs() * .8 + .2);
      switch (p.shape) {
        case 0:
          c.drawRect(
            Rect.fromCenter(
              center: Offset.zero,
              width: p.size,
              height: p.size * .55,
            ),
            paint,
          );
        case 1:
          c.drawCircle(Offset.zero, p.size * .4, paint);
        default:
          c.drawPath(
            Path()
              ..moveTo(0, -p.size * .5)
              ..lineTo(p.size * .5, p.size * .5)
              ..lineTo(-p.size * .5, p.size * .5)
              ..close(),
            paint,
          );
      }
      c.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter o) => o.t != t;
}

/// "Your invitation is live" dialog with confetti. Returns when the user continues.
Future<void> showPublishedDialog(
  BuildContext context,
  EventModel ev, {
  String? planName,
}) => showGeneralDialog<void>(
  context: context,
  barrierDismissible: false,
  barrierColor: const Color(0x99201820),
  transitionDuration: const Duration(milliseconds: 380),
  pageBuilder: (ctx, a, b) => Stack(
    children: [
      Center(
        child: _PublishedCard(event: ev, planName: planName),
      ),
      const Positioned.fill(child: ConfettiBurst()),
    ],
  ),
  transitionBuilder: (ctx, a, b, child) => FadeTransition(
    opacity: CurvedAnimation(parent: a, curve: Curves.easeOut),
    child: ScaleTransition(
      scale: Tween(
        begin: .88,
        end: 1.0,
      ).animate(CurvedAnimation(parent: a, curve: Curves.easeOutBack)),
      child: child,
    ),
  ),
);

class _PublishedCard extends StatefulWidget {
  final EventModel event;
  final String? planName;
  const _PublishedCard({required this.event, this.planName});
  @override
  State<_PublishedCard> createState() => _PublishedCardState();
}

class _PublishedCardState extends State<_PublishedCard> {
  bool copied = false;

  @override
  Widget build(BuildContext context) {
    final ev = widget.event;
    return Material(
      color: Colors.transparent,
      child: Container(
        margin: const EdgeInsets.all(20),
        constraints: const BoxConstraints(maxWidth: 460),
        padding: const EdgeInsets.fromLTRB(28, 30, 28, 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.celebration_rounded, size: 52, color: C.brand),
              const SizedBox(height: 14),
              Text(
                'Your invitation is live!',
                textAlign: TextAlign.center,
                style: serif(30, h: 1.15),
              ),
              const SizedBox(height: 8),
              Text(
                '“${ev.displayTitle}” is ready to share. Send the link or let guests scan the code.',
                textAlign: TextAlign.center,
                style: sans(14.5, h: 1.45),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [QrBox(data: ev.url, size: 116)],
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F6F5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: C.line),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.link_rounded, size: 18, color: C.body),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        ev.url,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: sans(13, w: FontWeight.w600, color: C.ink),
                      ),
                    ),
                    const SizedBox(width: 6),
                    OutlineBtn(
                      copied ? 'Copied' : 'Copy',
                      icon: copied ? Icons.check_rounded : Icons.copy_rounded,
                      height: 36,
                      onTap: () async {
                        await Clipboard.setData(ClipboardData(text: ev.url));
                        if (mounted) setState(() => copied = true);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 14,
                runSpacing: 6,
                alignment: WrapAlignment.center,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.event_available_outlined,
                        size: 17,
                        color: C.body,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Active until ${fmtDate(ev.expiresAt)}',
                        style: sans(13),
                      ),
                    ],
                  ),
                  if (widget.planName != null)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.workspace_premium_outlined,
                          size: 17,
                          color: C.body,
                        ),
                        const SizedBox(width: 6),
                        Text('${widget.planName} plan', style: sans(13)),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 22),
              PrimaryButton(
                'Go to my event',
                icon: Icons.arrow_forward_rounded,
                height: 52,
                onTap: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
