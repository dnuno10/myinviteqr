import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../data/backend.dart';
import '../data/models.dart';
import '../theme/app_theme.dart';
import '../util/browser.dart';
import '../util/download.dart';
import '../util/format.dart';
import '../widgets/common.dart';
import '../widgets/guests_panel.dart';
import '../widgets/invitation.dart';
import '../widgets/responsive.dart';
import '../widgets/shell.dart';
import 'wizard/wizard.dart';

class EventDetailScreen extends StatefulWidget {
  final String eventId;
  const EventDetailScreen({super.key, required this.eventId});
  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _Data {
  final EventModel event;
  final Template? template;
  final Category? category;
  final Plan? plan;
  final List<EventBlock> blocks;
  final List<Guest> guests;
  final List<DateTime> opens;
  _Data(
    this.event,
    this.template,
    this.category,
    this.plan,
    this.blocks,
    this.guests,
    this.opens,
  );
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  late Future<_Data> future = _load();
  int tab = 0;
  bool extending = false;

  Future<_Data> _load() async {
    final e = await Backend.i.event(widget.eventId);
    final r = await Future.wait([
      Backend.i.templates(),
      Backend.i.categories(),
      Backend.i.plans(),
      Backend.i.blocks(e.id),
      Backend.i.guests(e.id),
      Backend.i.opens(e.id, days: 3650),
    ]);
    final t = (r[0] as List<Template>)
        .where((t) => t.id == e.templateId)
        .firstOrNull;
    final c = (r[1] as List<Category>)
        .where((c) => c.id == e.categoryId)
        .firstOrNull;
    final p = (r[2] as List<Plan>).where((p) => p.code == e.plan).firstOrNull;
    return _Data(
      e,
      t,
      c,
      p,
      r[3] as List<EventBlock>,
      r[4] as List<Guest>,
      r[5] as List<DateTime>,
    );
  }

  void _reload() => setState(() {
    future = _load();
  });

  Future<void> _reloadGuests(_Data d) async {
    final g = await Backend.i.guests(d.event.id);
    if (!mounted) return;
    setState(() {
      future = Future.value(
        _Data(d.event, d.template, d.category, d.plan, d.blocks, g, d.opens),
      );
    });
  }

  Future<void> _extend(_Data d) async {
    final price = d.plan?.extensionPriceCents ?? 699;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text(
          'Extend by ${((d.plan?.extensionDays ?? 180) / 30).round()} months?',
          style: serif(20),
        ),
        content: Text(
          'Your invitation will stay active for ${d.plan?.extensionDays ?? 180} more days (${money(price)}). You’ll pay securely on Stripe.',
          style: sans(14, h: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: sans(14, color: C.body)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Extend',
              style: sans(14, w: FontWeight.w600, color: C.brand),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => extending = true);
    try {
      final r = await Backend.i.checkout(
        eventId: d.event.id,
        kind: 'extension',
      );
      if (r.free) {
        if (mounted) toast(context, 'Your invitation was extended.');
        _reload();
      } else {
        await goToUrl(r.url!);
      }
    } catch (e) {
      if (mounted) toast(context, errText(e), error: true);
    } finally {
      if (mounted) setState(() => extending = false);
    }
  }

  Future<void> _downloadQr(EventModel e) async {
    try {
      final painter = QrPainter(
        data: e.url,
        version: QrVersions.auto,
        gapless: true,
        emptyColor: Colors.white,
        eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: C.ink),
        dataModuleStyle: const QrDataModuleStyle(
          dataModuleShape: QrDataModuleShape.square,
          color: C.ink,
        ),
      );
      final bd = await painter.toImageData(
        1024,
        format: ui.ImageByteFormat.png,
      );
      saveFile(
        bd!.buffer.asUint8List(),
        'qr-${e.publicToken}.png',
        'image/png',
      );
    } catch (_) {
      if (mounted)
        toast(context, 'Downloads are available in the web app.', error: true);
    }
  }

  @override
  Widget build(BuildContext context) => AppShell(
    child: FutureBuilder<_Data>(
      future: future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done)
          return const LoadingView();
        if (snap.hasError)
          return ErrorView(errText(snap.error!), onRetry: _reload);
        return _page(snap.data!);
      },
    ),
  );

  Widget _page(_Data d) {
    final e = d.event;
    return PageBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => Navigator.of(context).pop(),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.arrow_back_rounded, size: 16, color: C.ink),
                const SizedBox(width: 8),
                Text('All events', style: sans(13, color: C.ink)),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _header(d),
          const SizedBox(height: 18),
          _tabs(),
          const SizedBox(height: 18),
          if (tab == 0)
            ..._overview(d)
          else
            GuestsPanel(
              event: e,
              guests: d.guests,
              maxGuests: d.plan?.maxGuests,
              onChanged: () => _reloadGuests(d),
            ),
        ],
      ),
    );
  }

  Widget _tabs() => Wrap(
    spacing: 8,
    children: [
      for (final (i, l) in const ['Overview', 'Guests & RSVP'].indexed)
        InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => setState(() => tab = i),
          child: Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 18),

            decoration: BoxDecoration(
              color: tab == i ? C.brandSoft : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: tab == i ? C.brandBorder : C.line),
            ),
            child: Center(
              widthFactor: 1,
              child: Text(
                l,
                style: sans(
                  14,
                  w: tab == i ? FontWeight.w600 : FontWeight.w400,
                  color: tab == i ? C.brand : C.body,
                ),
              ),
            ),
          ),
        ),
    ],
  );

  Widget _header(_Data d) {
    final e = d.event;
    final thumb = SizedBox(
      width: 140,
      height: 160,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: d.template == null
            ? Container(color: const Color(0xFFF6F4F3))
            : TemplateThumb(
                template: d.template!,
                event: e,
                design: e.pageDesign,
                layers: d.blocks,
              ),
      ),
    );
    return AppCard(
      padding: EdgeInsets.all(isMobile(context) ? 16 : 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AdaptiveRow(
            breakpoint: 560,
            gap: 20,
            children: [
              Fixed(140, thumb),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    e.displayTitle,
                    style: serif(isMobile(context) ? 24 : 28),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 18,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (d.category != null)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              categoryIcon(d.category!.icon),
                              size: 18,
                              color: C.brand,
                            ),
                            const SizedBox(width: 6),
                            Text(d.category!.name, style: sans(14)),
                          ],
                        ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.calendar_today_outlined,
                            size: 17,
                            color: C.body,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${fmtDate(e.startsAt)} ${fmtTime(e.startsAt)}',
                            style: sans(14),
                          ),
                        ],
                      ),
                      if ((e.venueName ?? '').isNotEmpty)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.location_on_outlined,
                              size: 18,
                              color: C.body,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                e.venueName!,
                                overflow: TextOverflow.ellipsis,
                                style: sans(14),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      statusPill(e.status, ended: e.isEnded),
                      if (d.plan != null)
                        (d.plan!.isPremium ? Pill.premium() : Pill.essential()),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      OutlineBtn(
                        'Edit invitation',
                        icon: Icons.edit_outlined,
                        pink: true,
                        onTap: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  WizardScreen(eventId: e.id, startStep: 3),
                            ),
                          );
                          if (mounted) _reload();
                        },
                      ),
                      OutlineBtn(
                        'Open invitation',
                        icon: Icons.open_in_new_rounded,
                        onTap: () => launchUrl(
                          Uri.parse(e.url),
                          webOnlyWindowName: '_blank',
                        ),
                      ),
                      OutlineBtn(
                        'Delete event',
                        icon: Icons.delete_outline_rounded,
                        onTap: () async {
                          if (await confirmDeleteEvent(context, e) &&
                              context.mounted) {
                            Navigator.of(context).pop();
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          const StepperBar(current: 6),
        ],
      ),
    );
  }

  List<Widget> _overview(_Data d) {
    final e = d.event;
    final g = d.guests;
    final yes = g.where((x) => x.rsvp == 'yes').length,
        pending = g.where((x) => x.rsvp == 'pending').length,
        no = g.where((x) => x.rsvp == 'no').length;
    final people = g
        .where((x) => x.rsvp == 'yes')
        .fold<int>(0, (a, x) => a + 1 + x.companions);
    String pct(int n) => g.isEmpty ? '' : '${(100 * n / g.length).round()}%';
    return [
      AppCard(
        padding: const EdgeInsets.all(18),
        child: AutoGrid(
          minTile: 150,
          gap: 14,
          children: [
            _stat(Icons.check_rounded, C.green, '$yes', 'Confirmed', pct(yes)),
            _stat(
              Icons.schedule_rounded,
              C.amber,
              '$pending',
              'Pending',
              pct(pending),
            ),
            _stat(Icons.close_rounded, C.red, '$no', 'Declined', pct(no)),
            _stat(
              Icons.visibility_outlined,
              C.purple,
              '${d.opens.length}',
              'Opens',
              '',
            ),
            _stat(
              Icons.people_outline_rounded,
              C.body,
              '${g.length + g.fold<int>(0, (a, x) => a + (x.rsvp == 'yes' ? x.companions : 0))}',
              'Total people',
              people > 0 ? '$people confirmed' : '',
            ),
          ],
        ),
      ),
      const SizedBox(height: 18),
      AdaptiveRow(
        breakpoint: 1000,
        gap: 18,
        flex: const [1, 0],
        children: [
          Column(
            children: [
              AdaptiveRow(
                breakpoint: 640,
                flex: const [1, 1],
                children: [_chartCard(g), _activity(g)],
              ),
              const SizedBox(height: 18),
              _opensCard(d),
            ],
          ),
          Fixed(
            380,
            Column(
              children: [
                _previewCard(d),
                const SizedBox(height: 18),
                _validity(d),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: 18),
      AppCard(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Quick actions', style: serif(19)),
            const SizedBox(height: 14),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                OutlineBtn(
                  'Copy link',
                  icon: Icons.link_rounded,
                  onTap: () async {
                    await Clipboard.setData(ClipboardData(text: e.url));
                    if (mounted) toast(context, 'Link copied');
                  },
                ),
                OutlineBtn(
                  'Download QR',
                  icon: Icons.qr_code_2_rounded,
                  onTap: () => _downloadQr(e),
                ),
                OutlineBtn(
                  'Add guests',
                  icon: Icons.person_add_alt_outlined,
                  onTap: () => setState(() => tab = 1),
                ),
              ],
            ),
          ],
        ),
      ),
    ];
  }

  Widget _stat(IconData i, Color c, String n, String l, String sub) => Row(
    children: [
      Icon(i, color: c, size: 28),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              n,
              style: sans(24, w: FontWeight.w700, color: C.ink, h: 1.1),
            ),
            Text(l, overflow: TextOverflow.ellipsis, style: sans(13)),
            if (sub.isNotEmpty)
              Text(
                sub,
                overflow: TextOverflow.ellipsis,
                style: sans(12.5, w: FontWeight.w700, color: c),
              ),
          ],
        ),
      ),
    ],
  );

  Widget _chartCard(List<Guest> guests) {
    final today = DateTime.now();
    final days = [
      for (int i = 6; i >= 0; i--)
        DateTime(
          today.year,
          today.month,
          today.day,
        ).subtract(Duration(days: i)),
    ];
    int count(DateTime day, String r) => guests
        .where(
          (g) =>
              g.rsvp == r &&
              g.respondedAt != null &&
              DateUtils.isSameDay(g.respondedAt!.toLocal(), day),
        )
        .length;
    final series = [
      for (final r in const ['yes', 'maybe', 'no'])
        [for (final d in days) count(d, r).toDouble()],
    ];
    final empty = series.every((s) => s.every((v) => v == 0));
    return AppCard(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('RSVP responses', style: serif(19)),
          Text('Last 7 days', style: sans(12.5, color: C.muted)),
          const SizedBox(height: 12),
          SizedBox(
            height: 190,
            child: empty
                ? Center(
                    child: Text(
                      'No responses yet',
                      style: sans(14, color: C.muted),
                    ),
                  )
                : CustomPaint(
                    painter: BarsPainter(
                      labels: [for (final d in days) '${d.month}/${d.day}'],
                      series: series,
                      colors: const [
                        Color(0xFF7DC99B),
                        Color(0xFFB7A6F5),
                        Color(0xFFEF7D7D),
                      ],
                    ),
                    size: Size.infinite,
                  ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 16,
            runSpacing: 6,
            children: [
              _legend(const Color(0xFF7DC99B), 'Confirmed'),
              _legend(const Color(0xFFB7A6F5), 'Maybe'),
              _legend(const Color(0xFFEF7D7D), 'Declined'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legend(Color c, String t) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(color: c, shape: BoxShape.circle),
      ),
      const SizedBox(width: 6),
      Text(t, style: sans(12.5)),
    ],
  );

  Widget _opensCard(_Data d) {
    final premium = d.plan?.openAnalytics ?? false;
    final today = DateTime.now();
    final days = [
      for (int i = 6; i >= 0; i--)
        DateTime(
          today.year,
          today.month,
          today.day,
        ).subtract(Duration(days: i)),
    ];
    final vals = [
      for (final day in days)
        d.opens
            .where((o) => DateUtils.isSameDay(o.toLocal(), day))
            .length
            .toDouble(),
    ];
    return AppCard(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('Invitation opens', style: serif(19))),
              if (!premium) Pill.premium(),
            ],
          ),
          const SizedBox(height: 10),
          if (!premium)
            Text(
              'Open analytics — who opened your invitation, when, and who is still missing — is included in the Premium plan.',
              style: sans(13.5, h: 1.45),
            )
          else
            SizedBox(
              height: 160,
              child: vals.every((v) => v == 0)
                  ? Center(
                      child: Text(
                        'No opens yet',
                        style: sans(14, color: C.muted),
                      ),
                    )
                  : CustomPaint(
                      painter: BarsPainter(
                        labels: [for (final d in days) '${d.month}/${d.day}'],
                        series: [vals],
                        colors: const [C.brand],
                      ),
                      size: Size.infinite,
                    ),
            ),
        ],
      ),
    );
  }

  Widget _activity(List<Guest> guests) {
    final items = <(DateTime, String, String)>[];
    for (final g in guests) {
      if (g.respondedAt != null && g.rsvp != 'pending') {
        items.add((
          g.respondedAt!,
          g.fullName,
          switch (g.rsvp) {
            'yes' => 'confirmed their attendance',
            'no' => 'declined',
            _ => 'replied maybe',
          },
        ));
      }
      if (g.lastOpenedAt != null &&
          (g.respondedAt == null || g.lastOpenedAt!.isAfter(g.respondedAt!))) {
        items.add((
          g.lastOpenedAt!,
          g.fullName,
          g.rsvp == 'pending'
              ? 'opened the invitation, no reply yet'
              : 'opened the invitation',
        ));
      }
    }
    items.sort((a, b) => b.$1.compareTo(a.$1));
    return AppCard(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Recent activity', style: serif(19)),
          const SizedBox(height: 8),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 30),
              child: Center(
                child: Text(
                  'Nothing yet — share your link to get started.',
                  textAlign: TextAlign.center,
                  style: sans(14, color: C.muted),
                ),
              ),
            )
          else
            for (final (i, it) in items.take(6).indexed)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 11),
                decoration: BoxDecoration(
                  border: i == 0
                      ? null
                      : const Border(top: BorderSide(color: C.line)),
                ),
                child: Row(
                  children: [
                    Avatar(it.$2, size: 38),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: it.$2,
                                  style: sans(
                                    13.5,
                                    w: FontWeight.w600,
                                    color: C.ink,
                                  ),
                                ),
                                TextSpan(text: ' ${it.$3}', style: sans(13.5)),
                              ],
                            ),
                          ),
                          Text(fmtAgo(it.$1), style: sans(12, color: C.muted)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }

  Widget _previewCard(_Data d) {
    final e = d.event;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Your invitation', style: serif(19)),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (d.template != null)
                PhonePreview(
                  event: e,
                  design: e.pageDesign,
                  layers: d.blocks,
                  width: 160,
                ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  children: [
                    Text('Scan to view', style: script(22)),
                    const SizedBox(height: 8),
                    QrBox(data: e.url, size: 110),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _validity(_Data d) {
    final e = d.event;
    final price = d.plan?.extensionPriceCents ?? 699;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.calendar_today_outlined, size: 22, color: C.ink),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  e.isEnded
                      ? 'Your invitation has ended'
                      : 'Your invitation is active',
                  style: serif(17),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: e.isEnded ? 0 : e.validityProgress,
                    minHeight: 10,
                    backgroundColor: const Color(0xFFEDEBEA),
                    valueColor: const AlwaysStoppedAnimation(C.brand),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Text(
                e.isEnded ? 'Ended' : '${e.daysLeft} days left',
                style: sans(14, w: FontWeight.w500, color: C.ink),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            '${e.isEnded ? 'Ended' : 'Valid until'} ${fmtDate(e.expiresAt)}',
            style: sans(12.5),
          ),
          const SizedBox(height: 8),
          Text(
            e.isEnded
                ? 'Guests see “This event has ended”. Your guest list is kept for 12 months.'
                : 'It then enters a 7-day grace period and is archived automatically.',
            style: sans(12.5, color: C.muted, h: 1.5),
          ),
          const SizedBox(height: 18),
          PrimaryButton(
            e.isEnded
                ? 'Reactivate for ${money(price)}'
                : 'Extend for ${money(price)}',
            busy: extending,
            onTap: () => _extend(d),
          ),
        ],
      ),
    );
  }
}

/// Grouped bar chart drawn from real series. Adapts to any width.
class BarsPainter extends CustomPainter {
  final List<String> labels;
  final List<List<double>> series;
  final List<Color> colors;
  BarsPainter({
    required this.labels,
    required this.series,
    required this.colors,
  });

  @override
  void paint(Canvas c, Size s) {
    const left = 28.0, bottom = 22.0;
    final maxV = series
        .expand((x) => x)
        .fold<double>(0, (a, b) => b > a ? b : a);
    final top = maxV <= 4 ? 4.0 : (maxV / 4).ceilToDouble() * 4;
    final h = s.height - bottom, w = s.width - left;
    for (int i = 0; i <= 4; i++) {
      final y = h - h * i / 4;
      c.drawLine(Offset(left, y), Offset(s.width, y), Paint()..color = C.line);
      _text(c, '${(top * i / 4).round()}', Offset(0, y - 7), 11);
    }
    final slot = w / labels.length;
    final skip = slot < 34 ? 2 : 1;
    for (int i = 0; i < labels.length; i++) {
      final bw = (slot * .7 / series.length).clamp(2.0, 16.0);
      final x0 = left + slot * i + (slot - bw * series.length) / 2;
      for (int k = 0; k < series.length; k++) {
        final bh = h * series[k][i] / top;
        if (bh > 0)
          c.drawRRect(
            RRect.fromRectAndCorners(
              Rect.fromLTWH(x0 + k * bw, h - bh, bw - 1, bh),
              topLeft: const Radius.circular(3),
              topRight: const Radius.circular(3),
            ),
            Paint()..color = colors[k],
          );
      }
      if (i % skip == 0)
        _text(
          c,
          labels[i],
          Offset(left + slot * i + slot / 2 - 12, h + 6),
          10.5,
        );
    }
  }

  void _text(Canvas c, String t, Offset o, double size) {
    final tp = TextPainter(
      text: TextSpan(
        text: t,
        style: sans(size, color: C.muted),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, o);
  }

  @override
  bool shouldRepaint(BarsPainter o) => o.series != series;
}

/// Asks for confirmation and deletes the event. Returns true when it was deleted.
Future<bool> confirmDeleteEvent(BuildContext context, EventModel e) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: Colors.white,
      title: Text('Delete this event?', style: serif(20)),
      content: Text(
        e.isDraft
            ? '“${e.displayTitle}” and its guests will be permanently deleted.'
            : '“${e.displayTitle}”, its guests and RSVPs will be permanently deleted, and the invitation link will stop working.',
        style: sans(14),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text('Cancel', style: sans(14, color: C.body)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(
            'Delete event',
            style: sans(14, w: FontWeight.w600, color: C.red),
          ),
        ),
      ],
    ),
  );
  if (ok != true) return false;
  try {
    await Backend.i.deleteEvent(e.id);
    return true;
  } catch (err) {
    if (context.mounted) toast(context, errText(err), error: true);
    return false;
  }
}
