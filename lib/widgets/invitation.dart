import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../data/models.dart';
import '../theme/app_theme.dart';
import '../util/format.dart';

/// Fonts offered in the editor (all served by Google Fonts).
const editorFonts = <String>[
  'Playfair Display',
  'Cormorant Garamond',
  'DM Serif Display',
  'Lora',
  'Bodoni Moda',
  'Abril Fatface',
  'Fraunces',
  'Great Vibes',
  'Dancing Script',
  'Sacramento',
  'Allura',
  'Parisienne',
  'Satisfy',
  'Pacifico',
  'Lobster',
  'Caveat',
  'Inter',
  'Poppins',
  'Montserrat',
  'DM Sans',
  'Josefin Sans',
  'Nunito',
  'Quicksand',
  'Lato',
  'Fredoka',
  'Bebas Neue',
  'Oswald',
  'Space Grotesk',
];

TextStyle layerFont(
  String? family,
  double size,
  Color color, {
  int weight = 500,
  bool italic = false,
  double ls = 0,
  double lh = 1.15,
}) {
  final w = FontWeight.values[((weight / 100).round() - 1).clamp(0, 8)];
  try {
    return GoogleFonts.getFont(
      family ?? 'Playfair Display',
      fontSize: size,
      color: color,
      fontWeight: w,
      fontStyle: italic ? FontStyle.italic : FontStyle.normal,
      letterSpacing: ls,
      height: lh,
    );
  } catch (_) {
    return serif(size, w: w, color: color, h: lh);
  }
}

// ---------------------------------------------------------------------------
// Shapes
// ---------------------------------------------------------------------------
Path shapePath(String? kind, Rect r, {double radius = .14}) {
  final m = math.min(r.width, r.height);
  switch (kind) {
    case 'circle':
    case 'oval':
      return Path()..addOval(r);
    case 'round':
      return Path()
        ..addRRect(RRect.fromRectAndRadius(r, Radius.circular(m * radius)));
    case 'pill':
      return Path()
        ..addRRect(RRect.fromRectAndRadius(r, Radius.circular(m / 2)));
    case 'arch':
      return Path()..addRRect(
        RRect.fromRectAndCorners(
          r,
          topLeft: Radius.circular(r.width / 2),
          topRight: Radius.circular(r.width / 2),
        ),
      );
    case 'arch_bottom':
      return Path()..addRRect(
        RRect.fromRectAndCorners(
          r,
          bottomLeft: Radius.circular(r.width / 2),
          bottomRight: Radius.circular(r.width / 2),
        ),
      );
    case 'diamond':
      return Path()
        ..moveTo(r.center.dx, r.top)
        ..lineTo(r.right, r.center.dy)
        ..lineTo(r.center.dx, r.bottom)
        ..lineTo(r.left, r.center.dy)
        ..close();
    case 'triangle':
      return Path()
        ..moveTo(r.center.dx, r.top)
        ..lineTo(r.right, r.bottom)
        ..lineTo(r.left, r.bottom)
        ..close();
    case 'heart':
      final w = r.width, h = r.height;
      Offset p(double x, double y) => Offset(r.left + w * x, r.top + h * y);
      return Path()
        ..moveTo(p(.5, .96).dx, p(.5, .96).dy)
        ..cubicTo(
          p(.02, .62).dx,
          p(.02, .62).dy,
          p(-.02, .08).dx,
          p(-.02, .08).dy,
          p(.26, .04).dx,
          p(.26, .04).dy,
        )
        ..cubicTo(
          p(.4, .02).dx,
          p(.4, .02).dy,
          p(.5, .14).dx,
          p(.5, .14).dy,
          p(.5, .26).dx,
          p(.5, .26).dy,
        )
        ..cubicTo(
          p(.5, .14).dx,
          p(.5, .14).dy,
          p(.6, .02).dx,
          p(.6, .02).dy,
          p(.74, .04).dx,
          p(.74, .04).dy,
        )
        ..cubicTo(
          p(1.02, .08).dx,
          p(1.02, .08).dy,
          p(.98, .62).dx,
          p(.98, .62).dy,
          p(.5, .96).dx,
          p(.5, .96).dy,
        )
        ..close();
    default:
      return Path()..addRect(r);
  }
}

class _ShapeClipper extends CustomClipper<Path> {
  final String? kind;
  final double radius;
  _ShapeClipper(this.kind, this.radius);
  @override
  Path getClip(Size s) => shapePath(kind, Offset.zero & s, radius: radius);
  @override
  bool shouldReclip(_ShapeClipper o) => o.kind != kind || o.radius != radius;
}

class _ShapePainter extends CustomPainter {
  final String? kind;
  final Color? fill, stroke;
  final double strokeWidth, radius;
  _ShapePainter({
    this.kind,
    this.fill,
    this.stroke,
    this.strokeWidth = 0,
    this.radius = .14,
  });
  @override
  void paint(Canvas c, Size s) {
    final path = shapePath(kind, Offset.zero & s, radius: radius);
    if (fill != null)
      c.drawPath(
        path,
        Paint()
          ..color = fill!
          ..isAntiAlias = true,
      );
    if (stroke != null && strokeWidth > 0)
      c.drawPath(
        path,
        Paint()
          ..color = stroke!
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..isAntiAlias = true,
      );
  }

  @override
  bool shouldRepaint(_ShapePainter o) => true;
}

// ---------------------------------------------------------------------------
// Decorations
// ---------------------------------------------------------------------------
const decoKinds = <String, String>{
  'flowers': 'Flowers',
  'leaves': 'Leaf branch',
  'palm': 'Palm leaves',
  'confetti': 'Confetti',
  'sprinkles': 'Sprinkles',
  'balloons': 'Balloons',
  'stars': 'Sparkles',
  'hearts': 'Hearts',
  'dots': 'Polka dots',
  'waves': 'Waves',
  'rays': 'Sunburst',
  'stripes': 'Stripes',
  'clouds': 'Clouds',
  'moon': 'Moon',
  'sun': 'Sun',
  'rainbow': 'Rainbow',
  'frame': 'Frame',
  'divider': 'Divider',
  'bunting': 'Bunting',
  'arches': 'Arches',
  'tape': 'Tape',
};

class DecoPainter extends CustomPainter {
  final String kind;
  final Color c1, c2, c3;
  final int seed;
  DecoPainter(this.kind, this.c1, this.c2, this.c3, this.seed);

  @override
  void paint(Canvas c, Size s) {
    final rnd = math.Random(seed);
    Paint fill(Color col, [double o = 1]) => Paint()
      ..color = col.withValues(alpha: o)
      ..isAntiAlias = true;
    Paint line(Color col, double w) => Paint()
      ..color = col
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;
    final w = s.width, h = s.height, u = math.min(w, h);
    final cols = [c1, c2, c3];

    void blossom(Offset o, double r, Color col, Color center) {
      for (int i = 0; i < 5; i++) {
        final a = i * 2 * math.pi / 5 - math.pi / 2;
        c.drawOval(
          Rect.fromCenter(
            center: o + Offset(math.cos(a), math.sin(a)) * r * .55,
            width: r * .95,
            height: r * .95,
          ),
          fill(col, .92),
        );
      }
      c.drawCircle(o, r * .28, fill(center));
    }

    void leaf(Offset o, double len, double ang, Color col, [double o2 = .95]) {
      c.save();
      c.translate(o.dx, o.dy);
      c.rotate(ang);
      final p = Path()
        ..moveTo(0, 0)
        ..quadraticBezierTo(len * .5, -len * .28, len, 0)
        ..quadraticBezierTo(len * .5, len * .28, 0, 0);
      c.drawPath(p, fill(col, o2));
      c.drawLine(
        Offset.zero,
        Offset(len * .9, 0),
        line(Colors.white.withValues(alpha: .35), len * .02),
      );
      c.restore();
    }

    void star4(Offset o, double r, Color col) {
      final p = Path()
        ..moveTo(o.dx, o.dy - r)
        ..quadraticBezierTo(o.dx, o.dy, o.dx + r, o.dy)
        ..quadraticBezierTo(o.dx, o.dy, o.dx, o.dy + r)
        ..quadraticBezierTo(o.dx, o.dy, o.dx - r, o.dy)
        ..quadraticBezierTo(o.dx, o.dy, o.dx, o.dy - r);
      c.drawPath(p, fill(col));
    }

    switch (kind) {
      case 'flowers':
        final n = math.max(3, (w * h / (u * u) * 4).round());
        for (int i = 0; i < 9; i++) {
          leaf(
            Offset(
              w * (.1 + rnd.nextDouble() * .8),
              h * (.1 + rnd.nextDouble() * .8),
            ),
            u * (.2 + rnd.nextDouble() * .18),
            rnd.nextDouble() * math.pi * 2,
            c3,
          );
        }
        for (int i = 0; i < n + 3; i++) {
          final o = Offset(
            w * (.12 + rnd.nextDouble() * .76),
            h * (.12 + rnd.nextDouble() * .76),
          );
          blossom(
            o,
            u * (.16 + rnd.nextDouble() * .16),
            i.isEven ? c1 : c2,
            const Color(0xFFF9D9A0),
          );
        }
      case 'leaves':
        final stem = Path()
          ..moveTo(0, h * .5)
          ..quadraticBezierTo(w * .5, h * .25, w, h * .55);
        c.drawPath(stem, line(c3, u * .012));
        for (int i = 0; i < 14; i++) {
          final t = (i + .5) / 14;
          final x = w * t,
              y = h * (.5 - .27 * math.sin(math.pi * t * .9) + .08 * t);
          final up = i.isEven;
          leaf(
            Offset(x, y),
            u * .26,
            (up ? -1 : 1) * (.9 + rnd.nextDouble() * .3),
            i % 3 == 0 ? c1 : c2,
          );
        }
      case 'palm':
        for (int i = 0; i < 7; i++) {
          final a = -math.pi * (.08 + i * .14);
          c.save();
          c.translate(w * .5, h);
          c.rotate(a - math.pi / 2 + math.pi / 2);
          final len = h * (.95 - (i - 3).abs() * .08);
          final p = Path()
            ..moveTo(0, 0)
            ..quadraticBezierTo(len * .4, -len * .18, len, 0)
            ..quadraticBezierTo(len * .4, len * .18, 0, 0);
          c.drawPath(p, fill(i.isEven ? c1 : c2, .95));
          c.restore();
        }
      case 'confetti':
      case 'sprinkles':
        final n = (w * h / (u * u) * 26).round().clamp(14, 90);
        for (int i = 0; i < n; i++) {
          final o = Offset(w * rnd.nextDouble(), h * rnd.nextDouble());
          final col = cols[rnd.nextInt(3)];
          final sz = u * (.02 + rnd.nextDouble() * .03);
          c.save();
          c.translate(o.dx, o.dy);
          c.rotate(rnd.nextDouble() * math.pi);
          if (kind == 'sprinkles') {
            c.drawLine(Offset(-sz, 0), Offset(sz, 0), line(col, sz * .7));
          } else {
            switch (rnd.nextInt(3)) {
              case 0:
                c.drawRect(
                  Rect.fromCenter(
                    center: Offset.zero,
                    width: sz * 1.6,
                    height: sz * .8,
                  ),
                  fill(col),
                );
              case 1:
                c.drawCircle(Offset.zero, sz * .7, fill(col));
              default:
                c.drawPath(
                  Path()
                    ..moveTo(0, -sz)
                    ..lineTo(sz, sz)
                    ..lineTo(-sz, sz)
                    ..close(),
                  fill(col),
                );
            }
          }
          c.restore();
        }
      case 'balloons':
        final n = math.max(3, (w / (u * .5)).round().clamp(3, 7));
        for (int i = 0; i < n; i++) {
          final cx = w * (i + .5) / n + (rnd.nextDouble() - .5) * w * .05;
          final r = math.min(w / n * .55, h * .28);
          final cy = h * (.3 + rnd.nextDouble() * .12);
          final col = cols[i % 3];
          c.drawPath(
            Path()
              ..moveTo(cx, cy + r * 1.25)
              ..cubicTo(cx - r * .3, h * .7, cx + r * .3, h * .8, cx, h),
            line(c1.withValues(alpha: .5), u * .006),
          );
          c.drawOval(
            Rect.fromCenter(
              center: Offset(cx, cy),
              width: r * 1.7,
              height: r * 2.1,
            ),
            fill(col),
          );
          c.drawOval(
            Rect.fromCenter(
              center: Offset(cx - r * .35, cy - r * .5),
              width: r * .35,
              height: r * .55,
            ),
            fill(Colors.white, .35),
          );
          c.drawPath(
            Path()
              ..moveTo(cx, cy + r * 1.05)
              ..lineTo(cx - r * .14, cy + r * 1.3)
              ..lineTo(cx + r * .14, cy + r * 1.3)
              ..close(),
            fill(col),
          );
        }
      case 'stars':
        final n = (w * h / (u * u) * 9).round().clamp(6, 40);
        for (int i = 0; i < n; i++) {
          final o = Offset(w * rnd.nextDouble(), h * rnd.nextDouble());
          final col = cols[rnd.nextInt(3)];
          if (i % 3 == 0) {
            c.drawCircle(
              o,
              u * .008 + rnd.nextDouble() * u * .006,
              fill(col, .9),
            );
          } else {
            star4(o, u * (.02 + rnd.nextDouble() * .045), col);
          }
        }
      case 'hearts':
        final n = (w * h / (u * u) * 8).round().clamp(5, 30);
        for (int i = 0; i < n; i++) {
          final r = u * (.03 + rnd.nextDouble() * .05);
          final o = Offset(w * rnd.nextDouble(), h * rnd.nextDouble());
          c.drawPath(
            shapePath(
              'heart',
              Rect.fromCenter(center: o, width: r * 2, height: r * 1.9),
            ),
            fill(cols[rnd.nextInt(3)], .85),
          );
        }
      case 'dots':
        final step = u * .12;
        for (double y = step / 2; y < h; y += step) {
          for (
            double x = step / 2 + ((y / step).floor().isOdd ? step / 2 : 0);
            x < w;
            x += step
          ) {
            c.drawCircle(Offset(x, y), step * .16, fill(c1, .9));
          }
        }
      case 'waves':
        for (int b = 0; b < 3; b++) {
          final col = cols[b];
          final base = h * (.35 + b * .22);
          final amp = h * .07;
          final p = Path()..moveTo(0, h);
          for (double x = 0; x <= w; x += w / 40) {
            p.lineTo(x, base + math.sin(x / w * math.pi * 3 + b * 1.4) * amp);
          }
          p
            ..lineTo(w, h)
            ..close();
          c.drawPath(p, fill(col, b == 0 ? .55 : .9));
        }
      case 'rays':
        final o = Offset(w / 2, h);
        const n = 18;
        for (int i = 0; i < n; i++) {
          if (i.isOdd) continue;
          final a0 = math.pi + math.pi * i / n,
              a1 = math.pi + math.pi * (i + 1) / n;
          final R = math.max(w, h) * 1.4;
          c.drawPath(
            Path()
              ..moveTo(o.dx, o.dy)
              ..lineTo(o.dx + math.cos(a0) * R, o.dy + math.sin(a0) * R)
              ..lineTo(o.dx + math.cos(a1) * R, o.dy + math.sin(a1) * R)
              ..close(),
            fill(c1, .5),
          );
        }
      case 'stripes':
        final n = 9;
        for (int i = 0; i < n; i++) {
          if (i.isOdd) continue;
          c.drawRect(Rect.fromLTWH(w * i / n, 0, w / n, h), fill(c1, .9));
        }
      case 'clouds':
        for (int i = 0; i < 3; i++) {
          final cx = w * (.2 + i * .3), cy = h * (.35 + (i.isOdd ? .25 : 0));
          final r = u * .22;
          for (final d in [
            const Offset(-.9, .2),
            const Offset(-.35, -.25),
            const Offset(.35, -.2),
            const Offset(.9, .2),
            const Offset(0, .25),
          ]) {
            c.drawCircle(
              Offset(cx + d.dx * r, cy + d.dy * r),
              r * .7,
              fill(cols[i % 2], .95),
            );
          }
        }
      case 'moon':
        final r = u * .42;
        final o = Offset(w / 2, h / 2);
        c.drawPath(
          Path.combine(
            PathOperation.difference,
            Path()..addOval(Rect.fromCircle(center: o, radius: r)),
            Path()..addOval(
              Rect.fromCircle(
                center: o + Offset(r * .42, -r * .12),
                radius: r * .86,
              ),
            ),
          ),
          fill(c1),
        );
      case 'sun':
        final o = Offset(w / 2, h / 2);
        final r = u * .24;
        for (int i = 0; i < 16; i++) {
          final a = i * math.pi / 8;
          c.drawLine(
            o + Offset(math.cos(a), math.sin(a)) * r * 1.3,
            o + Offset(math.cos(a), math.sin(a)) * r * (i.isEven ? 1.9 : 1.6),
            line(c2, u * .022),
          );
        }
        c.drawCircle(o, r, fill(c1));
      case 'rainbow':
        final o = Offset(w / 2, h);
        final R = math.min(w / 2, h) * .98;
        for (int i = 0; i < 5; i++) {
          c.drawArc(
            Rect.fromCircle(center: o, radius: R * (1 - i * .15)),
            math.pi,
            math.pi,
            false,
            line(
              [
                c1,
                c2,
                c3,
                c2.withValues(alpha: .6),
                c1.withValues(alpha: .6),
              ][i],
              R * .1,
            ),
          );
        }
      case 'frame':
        final m1 = u * .03, m2 = u * .06;
        c.drawRect(
          Rect.fromLTWH(m1, m1, w - m1 * 2, h - m1 * 2),
          line(c1, u * .006),
        );
        c.drawRect(
          Rect.fromLTWH(m2, m2, w - m2 * 2, h - m2 * 2),
          line(c1, u * .0025),
        );
        for (final o in [
          Offset(m1, m1),
          Offset(w - m1, m1),
          Offset(m1, h - m1),
          Offset(w - m1, h - m1),
        ]) {
          c.drawPath(
            shapePath(
              'diamond',
              Rect.fromCenter(center: o, width: u * .05, height: u * .05),
            ),
            fill(c1),
          );
        }
      case 'divider':
        final y = h / 2;
        c.drawLine(
          Offset(0, y),
          Offset(w * .43, y),
          line(c1, math.max(1, h * .06)),
        );
        c.drawLine(
          Offset(w * .57, y),
          Offset(w, y),
          line(c1, math.max(1, h * .06)),
        );
        c.drawPath(
          shapePath(
            'diamond',
            Rect.fromCenter(
              center: Offset(w / 2, y),
              width: h * .5,
              height: h * .5,
            ),
          ),
          fill(c2),
        );
      case 'bunting':
        final n = 9;
        final p = Path()
          ..moveTo(0, h * .1)
          ..quadraticBezierTo(w / 2, h * .55, w, h * .1);
        c.drawPath(p, line(c1.withValues(alpha: .7), u * .006));
        for (int i = 0; i < n; i++) {
          final t = (i + .5) / n;
          final x = w * t;
          final y = h * (.1 + .225 * 4 * t * (1 - t)) * 1.0;
          final fw = w / n * .78;
          c.drawPath(
            Path()
              ..moveTo(x - fw / 2, y)
              ..lineTo(x + fw / 2, y)
              ..lineTo(x, y + fw * 1.05)
              ..close(),
            fill(cols[i % 3]),
          );
        }
      case 'arches':
        for (int i = 0; i < 4; i++) {
          final f = 1 - i * .2;
          c.drawPath(
            shapePath(
              'arch',
              Rect.fromLTWH(w * (1 - f) / 2, h * (1 - f), w * f, h * f),
            ),
            line(cols[i % 3], u * .012),
          );
        }
      case 'tape':
        c.drawRect(Offset.zero & s, fill(c1, .55));
        for (double x = 0; x < w; x += w / 8) {
          c.drawLine(
            Offset(x, 0),
            Offset(x + h, h),
            line(Colors.white.withValues(alpha: .35), h * .12),
          );
        }
    }
  }

  @override
  bool shouldRepaint(DecoPainter o) =>
      o.kind != kind ||
      o.c1 != c1 ||
      o.c2 != c2 ||
      o.c3 != c3 ||
      o.seed != seed;
}

// ---------------------------------------------------------------------------
// Text binding
// ---------------------------------------------------------------------------
String resolveText(EventBlock l, EventModel e) {
  final s = e.startsAt?.toLocal();
  const wd = [
    'MONDAY',
    'TUESDAY',
    'WEDNESDAY',
    'THURSDAY',
    'FRIDAY',
    'SATURDAY',
    'SUNDAY',
  ];
  const mo = [
    'JAN',
    'FEB',
    'MAR',
    'APR',
    'MAY',
    'JUN',
    'JUL',
    'AUG',
    'SEP',
    'OCT',
    'NOV',
    'DEC',
  ];
  switch (l.str('b')) {
    case 'title':
      return e.title.trim().isEmpty ? 'Your event title' : e.title.trim();
    case 'date':
      return s == null ? 'Date to be announced' : fmtDateLong(s);
    case 'datesh':
      return s == null ? '' : fmtDate(s);
    case 'time':
      return s == null ? '' : fmtTime(s);
    case 'datetime':
      return s == null
          ? 'Date to be announced'
          : '${fmtDateLong(s)} · ${fmtTime(s)}';
    case 'day':
      return s == null ? '' : '${s.day}';
    case 'month':
      return s == null ? '' : mo[s.month - 1];
    case 'year':
      return s == null ? '' : '${s.year}';
    case 'weekday':
      return s == null ? '' : wd[s.weekday - 1];
    case 'venue':
      return e.venueName ?? '';
    case 'address':
      return e.venueAddress ?? '';
    case 'place':
      return [
        if ((e.venueName ?? '').isNotEmpty) e.venueName!,
        if ((e.venueAddress ?? '').isNotEmpty) e.venueAddress!,
      ].join('\n');
    case 'countdown':
      if (s == null) return '';
      final d = DateTime(s.year, s.month, s.day)
          .difference(
            DateTime(
              DateTime.now().year,
              DateTime.now().month,
              DateTime.now().day,
            ),
          )
          .inDays;
      return d > 1
          ? '$d days to go'
          : d == 1
          ? 'Tomorrow!'
          : d == 0
          ? 'Today!'
          : 'Thank you for celebrating with us';
    default:
      return l.str('tx') ?? '';
  }
}

// ---------------------------------------------------------------------------
// The page
// ---------------------------------------------------------------------------
typedef LayerWrap =
    Widget Function(
      BuildContext context,
      EventBlock layer,
      Widget child,
      double pageWidth,
    );

/// Renders an invitation: a page of free layers. Sizes are fractions of the page width.
class InvitationPage extends StatelessWidget {
  final EventModel event;
  final PageDesign design;
  final List<EventBlock> layers;
  final String url;
  final VoidCallback? onRsvp;
  final bool editing;
  final LayerWrap? wrap;
  final List<Widget> Function(double pageWidth)? overlays;
  final double minHeight;

  /// Soft entrance + ambient motion (public page and previews only).
  final bool animate;
  const InvitationPage({
    super.key,
    required this.event,
    required this.design,
    required this.layers,
    required this.url,
    this.onRsvp,
    this.editing = false,
    this.wrap,
    this.overlays,
    this.minHeight = 0,
    this.animate = false,
  });

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final w = c.hasBoundedWidth ? c.maxWidth : 360.0;
      final h = math.max(w * design.height, minHeight);
      final pal = design.pal;
      return SizedBox(
        width: w,
        height: h,
        child: ClipRect(
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: pal.bg,
                    gradient: design.gradient
                        ? LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [pal.bg, pal.soft],
                          )
                        : null,
                  ),
                ),
              ),
              for (final (i, l) in layers.indexed)
                if (l.enabled) _positioned(context, l, w, i),
              if (overlays != null) ...overlays!(w),
            ],
          ),
        ),
      );
    },
  );

  Widget _positioned(BuildContext context, EventBlock l, double w, int index) {
    Widget child = _content(context, l, w);
    if (wrap != null) child = wrap!(context, l, child, w);
    Widget body = Transform.rotate(
      angle: l.rot * math.pi / 180,
      child: Opacity(opacity: l.n('o', 1).clamp(0, 1), child: child),
    );
    if (animate && !editing && wrap == null) {
      body = _Anim(
        index: index,
        kind: l.kind,
        motion: design.motion,
        width: w,
        child: body,
      );
    }
    return Positioned(
      left: l.x * w,
      top: l.y * w,
      width: l.w * w,
      height: l.h * w,
      child: body,
    );
  }

  Widget _content(BuildContext context, EventBlock l, double W) {
    final pal = design.pal;
    switch (l.kind) {
      case 'text':
        final text = resolveText(l, event);
        final size = l.n('s', .05) * W;
        final color = pal.role(l.str('c'));
        final align = l.str('a') ?? 'center';
        final ta = align == 'left'
            ? TextAlign.left
            : align == 'right'
            ? TextAlign.right
            : TextAlign.center;
        final ax = align == 'left'
            ? -1.0
            : align == 'right'
            ? 1.0
            : 0.0;
        final va = l.str('va') == 'top'
            ? -1.0
            : l.str('va') == 'bottom'
            ? 1.0
            : 0.0;
        final shown = l.flag('u') ? text.toUpperCase() : text;
        if (shown.isEmpty) return const SizedBox.shrink();
        return FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment(ax, va),
          child: SizedBox(
            width: l.w * W,
            child: Text(
              shown,
              textAlign: ta,
              style: layerFont(
                l.str('f'),
                size,
                color,
                weight: l.n('wt', 500).round(),
                italic: l.flag('i'),
                ls: l.n('ls') * size,
                lh: l.n('lh', 1.15),
              ),
            ),
          ),
        );
      case 'photo':
        return _photo(l, W);
      case 'shape':
        final fillRole = l.str('fl');
        final strokeRole = l.str('sc');
        return CustomPaint(
          painter: _ShapePainter(
            kind: l.str('sh') ?? 'rect',
            fill: fillRole == null || fillRole == 'none'
                ? null
                : pal.role(fillRole).withValues(alpha: 1),
            stroke: strokeRole == null ? null : pal.role(strokeRole),
            strokeWidth: l.n('sw') * W,
            radius: l.n('rd', .14),
          ),
        );
      case 'deco':
        return CustomPaint(
          painter: DecoPainter(
            // A page-wide flower layer would paint giant blooms over the photos.
            (l.str('k') == 'flowers' && l.w > .9)
                ? 'confetti'
                : (l.str('k') ?? 'flowers'),
            pal.role(l.str('c1'), pal.accent),
            pal.role(l.str('c2'), pal.accent2),
            pal.role(l.str('c3'), pal.soft),
            l.n('sd', 1).round(),
          ),
        );
      case 'rsvp':
        final solid = (l.str('st') ?? 'solid') == 'solid';
        final col = pal.role(l.str('c'), pal.accent);
        final onCol = solid
            ? (col.computeLuminance() > .6 ? Colors.black87 : Colors.white)
            : col;
        final btn = Container(
          alignment: Alignment.center,
          padding: EdgeInsets.symmetric(horizontal: W * .02),
          decoration: ShapeDecoration(
            color: solid ? col : Colors.transparent,
            shape: (l.str('sh') ?? 'pill') == 'rect'
                ? RoundedRectangleBorder(
                    side: BorderSide(
                      color: col,
                      width: math.max(1.2, W * .004),
                    ),
                  )
                : StadiumBorder(
                    side: BorderSide(
                      color: col,
                      width: math.max(1.2, W * .004),
                    ),
                  ),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              ((l.str('lb') ?? '').isEmpty
                  ? 'Confirm attendance'
                  : l.str('lb')!),
              style: layerFont(
                l.str('f') ?? 'Inter',
                l.n('s', .04) * W,
                onCol,
                weight: l.n('wt', 600).round(),
                ls: l.n('ls') * W * .04,
              ),
            ),
          ),
        );
        if (onRsvp == null || editing) return btn;
        return GestureDetector(
          onTap: onRsvp,
          child: MouseRegion(cursor: SystemMouseCursors.click, child: btn),
        );
      case 'qr':
        final qrInk = pal.ink.computeLuminance() < .35
            ? pal.ink
            : Colors.black87;
        return Container(
          padding: EdgeInsets.all(W * .015),
          color: Colors.white,
          child: QrImageView(
            data: url,
            padding: EdgeInsets.zero,
            eyeStyle: QrEyeStyle(color: qrInk, eyeShape: QrEyeShape.square),
            dataModuleStyle: QrDataModuleStyle(
              color: qrInk,
              dataModuleShape: QrDataModuleShape.square,
            ),
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _photo(EventBlock l, double W) {
    final pal = design.pal;
    final url = l.str('url');
    final fx = l.n('fx').clamp(-1, 1).toDouble(),
        fy = l.n('fy').clamp(-1, 1).toDouble();
    final z = l.n('z', 1).clamp(1, 4).toDouble();
    final placeholder = _PhotoPlaceholder(
      pal: pal,
      editing: editing,
      seed: l.position,
    );
    Widget image = url == null || url.isEmpty
        ? placeholder
        : Transform.scale(
            scale: z,
            alignment: Alignment(fx, fy),
            child: Image.network(
              url,
              fit: BoxFit.cover,
              alignment: Alignment(fx, fy),
              width: double.infinity,
              height: double.infinity,
              loadingBuilder: (c, child, p) => p == null ? child : placeholder,
              errorBuilder: (c, e, s) => placeholder,
            ),
          );
    if (l.flag('pol')) {
      final m = (l.n('bw', .03)) * W;
      return Container(
        padding: EdgeInsets.fromLTRB(m, m, m, m * 3.4),
        decoration: BoxDecoration(
          color: pal.role(l.str('bc'), Colors.white),
          border: Border.all(color: pal.ink.withValues(alpha: .1), width: 1),
        ),
        child: ClipRect(child: SizedBox.expand(child: image)),
      );
    }
    final kind = l.str('sh') ?? 'rect';
    final rd = l.n('rd', .14);
    final bw = l.n('bw') * W;
    return CustomPaint(
      foregroundPainter: bw > 0
          ? _ShapePainter(
              kind: kind,
              stroke: pal.role(l.str('bc'), Colors.white),
              strokeWidth: bw * 2,
              radius: rd,
            )
          : null,
      child: ClipPath(
        clipper: _ShapeClipper(kind, rd),
        child: SizedBox.expand(child: image),
      ),
    );
  }
}

/// Sample photography (recoloured to the palette) shown until the host uploads a photo.
class _PhotoPlaceholder extends StatelessWidget {
  final Pal pal;
  final bool editing;
  final int seed;
  const _PhotoPlaceholder({
    required this.pal,
    required this.editing,
    required this.seed,
  });

  static const _variantHues = [
    345.0,
    10.0,
    35.0,
    105.0,
    150.0,
    190.0,
    250.0,
    285.0,
  ];

  int get _variant {
    final hsl = HSLColor.fromColor(pal.accent);
    if (hsl.saturation < .12) return 0;
    var best = 0;
    var bestD = 999.0;
    for (final (i, h) in _variantHues.indexed) {
      var d = (hsl.hue - h).abs();
      if (d > 180) d = 360 - d;
      if (d < bestD) {
        bestD = d;
        best = i;
      }
    }
    return best;
  }

  @override
  Widget build(BuildContext context) {
    final dark = pal.bg.computeLuminance() < .25;
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          'assets/samples/p${seed.abs() % 4}_$_variant.jpg',
          fit: BoxFit.cover,
          errorBuilder: (c, e, s) => ColoredBox(color: pal.soft),
        ),
        if (dark) ColoredBox(color: Colors.black.withValues(alpha: .22)),
        if (editing)
          Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Container(
                margin: const EdgeInsets.all(6),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .88),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.add_photo_alternate_outlined,
                      size: 16,
                      color: C.ink,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Add photo',
                      style: sans(11.5, color: C.ink, w: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Entrance + ambient motion for one layer. The family depends on the template style.
class _Anim extends StatefulWidget {
  final int index;
  final String kind, motion;
  final double width;
  final Widget child;
  const _Anim({
    required this.index,
    required this.kind,
    required this.motion,
    required this.width,
    required this.child,
  });
  @override
  State<_Anim> createState() => _AnimState();
}

class _AnimState extends State<_Anim> with SingleTickerProviderStateMixin {
  late final AnimationController c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 14),
  )..repeat();
  final start = DateTime.now();

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final W = widget.width;
    final m = widget.motion;
    final amp = switch (m) {
      'bounce' => 1.4,
      'float' => 1.2,
      'slide' => .45,
      _ => .8,
    };
    return AnimatedBuilder(
      animation: c,
      child: widget.child,
      builder: (context, child) {
        final ms = DateTime.now().difference(start).inMilliseconds.toDouble();
        // Same stagger for every layer, so nothing behind appears long before what sits on top.
        final delay = (widget.index * 45.0).clamp(0, 700).toDouble();
        final p = ((ms - delay) / 700).clamp(0.0, 1.0);
        final curve = switch (m) {
          'bounce' => Curves.easeOutBack,
          'slide' => Curves.easeOutQuart,
          _ => Curves.easeOutCubic,
        };
        final e = curve.transform(p);
        final t = c.value * 2 * math.pi;
        final ph = widget.index * 1.7;
        double dx = 0, dy = 0, rot = 0, scale = 1;
        // entrance
        switch (m) {
          case 'slide':
            dx = (1 - e) * W * .07 * (widget.index.isEven ? -1 : 1);
          case 'bounce':
            dy = (1 - e) * W * .05;
            scale = .88 + .12 * e;
          case 'float':
            dy = (1 - e) * W * .035;
            scale = .96 + .04 * e;
          default:
            dy = (1 - e) * W * .04;
        }
        // ambient
        if (widget.kind == 'deco') {
          dx += math.sin(t + ph) * W * .006 * amp;
          dy += math.cos(t * .8 + ph) * W * .008 * amp;
          rot = math.sin(t * .7 + ph) * .02 * amp;
        } else if (widget.kind == 'photo') {
          scale *= 1 + .018 * amp * (math.sin(t * .5 + ph) + 1) / 2;
        } else if (widget.kind == 'rsvp') {
          scale *= 1 + .03 * (math.sin(t * 2.2) + 1) / 2;
        }
        return Opacity(
          opacity: e.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(dx, dy),
            child: Transform.rotate(
              angle: rot,
              child: Transform.scale(scale: scale, child: child),
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Previews
// ---------------------------------------------------------------------------
final _tplLayers = <String, List<EventBlock>>{};
List<EventBlock> templateLayers(Template t) => _tplLayers.putIfAbsent(
  t.id,
  () => [
    for (final (i, l) in t.layout.layers.indexed)
      EventBlock(
        kind: l['t'] as String,
        position: i,
        content: deepCopy(Map<String, dynamic>.from(l)..remove('t')),
      ),
  ],
);

EventModel previewEvent({
  String title = '',
  DateTime? date,
  String? venue,
  String? address,
}) => EventModel(
  id: '',
  ownerId: '',
  title: title,
  language: 'en',
  status: 'draft',
  publicToken: '',
  startsAt: date,
  venueName: venue,
  venueAddress: address,
);

/// Top of a template, scaled to fit the width it is given. Fill it with a fixed-size parent.
class TemplateThumb extends StatelessWidget {
  final Template template;
  final EventModel event;
  final PageDesign? design;
  final List<EventBlock>? layers;
  const TemplateThumb({
    super.key,
    required this.template,
    required this.event,
    this.design,
    this.layers,
  });
  @override
  Widget build(BuildContext context) => ClipRect(
    child: OverflowBox(
      alignment: Alignment.topCenter,
      minHeight: 0,
      maxHeight: double.infinity,
      child: InvitationPage(
        event: event,
        design: design ?? template.layout.design,
        layers: layers ?? templateLayers(template),
        url: 'https://myinviteqr.com',
      ),
    ),
  );
}

/// The invitation inside a phone frame (scroll disabled and clipped, so it never overflows).
class PhonePreview extends StatelessWidget {
  final EventModel event;
  final PageDesign design;
  final List<EventBlock> layers;
  final double width;
  const PhonePreview({
    super.key,
    required this.event,
    required this.design,
    required this.layers,
    this.width = 200,
  });
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
          SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            child: InvitationPage(
              event: event,
              design: design,
              layers: layers,
              url: event.url,
              animate: true,
            ),
          ),
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

/// Full scrollable preview in a dialog.
Future<void> showFullPreview(
  BuildContext context, {
  required EventModel event,
  required PageDesign design,
  required List<EventBlock> layers,
}) => showDialog<void>(
  context: context,
  builder: (ctx) => Dialog(
    backgroundColor: design.pal.bg,
    insetPadding: const EdgeInsets.all(16),
    clipBehavior: Clip.antiAlias,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 480),
      child: Stack(
        children: [
          SingleChildScrollView(
            child: InvitationPage(
              event: event,
              design: design,
              layers: layers,
              url: event.url,
              animate: true,
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: IconButton.filled(
              style: IconButton.styleFrom(backgroundColor: Colors.white),
              onPressed: () => Navigator.pop(ctx),
              icon: const Icon(Icons.close_rounded, color: C.ink),
            ),
          ),
        ],
      ),
    ),
  ),
);
