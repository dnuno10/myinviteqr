import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/backend.dart';
import '../../data/models.dart';
import '../../theme/app_theme.dart';
import '../../util/browser.dart';
import '../../util/format.dart';
import '../../widgets/celebration.dart';
import '../../widgets/common.dart';
import '../../widgets/responsive.dart';
import '../event_detail.dart';
import 'wizard.dart';
import 'wizard_ui.dart';

class PublishStep extends StatefulWidget {
  final WizardController c;
  const PublishStep(this.c, {super.key});
  @override
  State<PublishStep> createState() => _PublishStepState();
}

class _PublishStepState extends State<PublishStep> {
  String plan = 'premium';
  bool extension = false, busy = false, quoting = false;
  final code = TextEditingController();
  String? appliedCode, codeError, error;
  Quote? quote;

  @override
  void initState() {
    super.initState();
    _quote();
  }

  @override
  void dispose() {
    code.dispose();
    super.dispose();
  }

  Plan get _plan => widget.c.plans.firstWhere((p) => p.code == plan);

  Future<void> _quote({bool fromApply = false}) async {
    setState(() {
      quoting = true;
      codeError = null;
    });
    try {
      final q = await Backend.i.quote(plan, extension, appliedCode);
      if (mounted) setState(() => quote = q);
    } catch (e) {
      if (mounted) {
        setState(() {
          codeError = errText(e);
          appliedCode = null;
        });
        // fall back to the price without a code
        try {
          final q = await Backend.i.quote(plan, extension, null);
          if (mounted) setState(() => quote = q);
        } catch (_) {}
      }
    } finally {
      if (mounted) setState(() => quoting = false);
    }
  }

  Future<void> _publish() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final r = await Backend.i.checkout(
        eventId: widget.c.event!.id,
        kind: 'publish',
        plan: plan,
        extension: extension,
        code: appliedCode,
      );
      if (r.free) {
        // 100% discount: nothing to pay, the event is already published
        final ev = await Backend.i.event(widget.c.event!.id);
        if (!mounted) return;
        await showPublishedDialog(context, ev, planName: _plan.name);
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => EventDetailScreen(eventId: ev.id)),
        );
        return;
      }
      // Stripe takes over; it brings the customer back to the app when done
      await goToUrl(r.url!);
    } catch (e) {
      if (mounted) {
        setState(() {
          error = errText(e);
          busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    final plans = c.plans;
    final cards = AdaptiveRow(
      breakpoint: 640,
      gap: 20,
      children: [for (final p in plans) _planCard(p)],
    );
    return WizardPage(
      c: c,
      content: AdaptiveRow(
        breakpoint: 1080,
        gap: 22,
        flex: const [1, 0],
        children: [cards, Fixed(400, _summary())],
      ),
      footer: Row(
        children: [
          OutlineBtn(
            'Back',
            icon: Icons.arrow_back_rounded,
            height: 44,
            onTap: () => c.goTo(4),
          ),
        ],
      ),
    );
  }

  List<(IconData, String, String)> _features(Plan p) {
    if (!p.isPremium) {
      return [
        (
          Icons.qr_code_2_rounded,
          'Downloadable QR code',
          'Share instantly, anywhere',
        ),
        (
          Icons.people_outline_rounded,
          'RSVP management',
          'See who’s coming in real time',
        ),
        (
          Icons.groups_outlined,
          'Up to ${p.maxGuests} guests',
          'Perfect for small gatherings',
        ),
        (
          Icons.notifications_none_rounded,
          p.maxReminders == null
              ? 'Unlimited reminders'
              : '${p.maxReminders} reminder',
          'Keep guests informed',
        ),
        (
          Icons.calendar_today_outlined,
          'Valid for ${p.validityDays} days',
          'From the date of publication',
        ),
      ];
    }
    return [
      (
        Icons.workspace_premium_outlined,
        'Everything in Essential',
        'All the essential features included',
      ),
      (
        Icons.people_outline_rounded,
        'Up to ${p.maxGuests} guests',
        'For bigger celebrations',
      ),
      (
        Icons.all_inclusive_rounded,
        p.maxReminders == null
            ? 'Unlimited reminders'
            : '${p.maxReminders} reminders',
        'Keep your guests in the loop',
      ),
      if (p.openAnalytics)
        (Icons.bar_chart_rounded, 'Open analytics', 'See what’s working'),
      if (p.customSlug)
        (Icons.link_rounded, 'Custom link', 'Your own short, branded link'),
      if (p.sharedAlbum)
        (
          Icons.photo_outlined,
          'Shared photo album',
          'Collect and share memories',
        ),
      if (p.removeBranding)
        (
          Icons.block_rounded,
          'No myinviteqr branding',
          'A fully white-label experience',
        ),
    ];
  }

  Widget _planCard(Plan p) {
    final sel = plan == p.code;
    final pop = p.isPremium;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: pop
                ? const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.white, Color(0xFFFFF3F5)],
                  )
                : null,
            color: pop ? null : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: sel || pop ? C.brand : C.line,
              width: sel ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(p.name, style: serif(28)),
                        const SizedBox(height: 4),
                        Text(
                          pop
                              ? 'More features for memorable events.'
                              : 'A simple event, done right.',
                          style: sans(13.5, color: C.body),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const SizedBox(height: 18),
                      Text(money(p.priceCents), style: serif(26)),
                      Text('one-time payment', style: sans(12, color: C.muted)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 18),
              for (final f in _features(p))
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: C.brandSoft,
                        ),
                        child: Icon(
                          f.$1,
                          size: 20,
                          color: pop ? C.brand : C.ink,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              f.$2,
                              style: sans(14, w: FontWeight.w600, color: C.ink),
                            ),
                            const SizedBox(height: 1),
                            Text(f.$3, style: sans(12.5, color: C.muted)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 10),
              HoverBuilder(
                hoverScale: 1.0,
                onTap: () {
                  setState(() => plan = p.code);
                  _quote();
                },
                builder: (context, hover) => AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  height: 50,
                  decoration: BoxDecoration(
                    color: sel
                        ? C.brandSoft
                        : hover
                        ? const Color(0xFFF7F5F4)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: sel ? C.brand : C.line,
                      width: sel ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        sel
                            ? Icons.radio_button_checked_rounded
                            : Icons.radio_button_off_rounded,
                        size: 22,
                        color: sel ? C.brand : C.ink,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Choose ${p.name}',
                        style: sans(
                          14.5,
                          w: FontWeight.w500,
                          color: sel ? C.brand : C.ink,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        if (pop)
          Positioned(
            right: 16,
            top: -13,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: C.brand,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.star_rounded, size: 14, color: Colors.white),
                  const SizedBox(width: 5),
                  Text(
                    'Most popular',
                    style: sans(12, w: FontWeight.w600, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _summary() {
    final e = widget.c.event!;
    final p = _plan;
    final q = quote;
    return PanelCard(
      title: 'Order summary',
      subtitle: 'Review your details and complete your purchase.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SummaryList([
            (Icons.description_outlined, 'Event title', e.displayTitle, null),
            (
              Icons.calendar_today_outlined,
              'Date',
              '${fmtDate(e.startsAt)} · ${fmtTime(e.startsAt)}',
              null,
            ),
            (
              Icons.place_outlined,
              'Location',
              e.venueName ?? '',
              (e.venueAddress ?? '').isEmpty ? 'Street, city' : e.venueAddress,
            ),
            (
              Icons.assignment_outlined,
              'Selected plan',
              '${p.name} · ${money(p.priceCents)}',
              null,
            ),
          ]),
          const Divider(height: 1, color: C.line),
          const SizedBox(height: 14),
          if (extension) ...[
            _line(
              '${(p.extensionDays / 30).round()}-month extension',
              money(p.extensionPriceCents),
            ),
            const SizedBox(height: 8),
          ],
          if ((q?.discount ?? 0) > 0) ...[
            _line('Discount (${q!.code})', '-${money(q.discount)}'),
            const SizedBox(height: 8),
          ],
          Row(
            children: [
              Text('Total', style: serif(20)),
              const Spacer(),
              Text(q == null ? '—' : money(q.total), style: serif(22)),
              const SizedBox(width: 6),
              Text('USD', style: sans(12, color: C.muted)),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3EC),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.schedule_rounded,
                      color: C.amber,
                      size: 26,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Is your event more than ${p.validityDays} days away?',
                            style: sans(13, w: FontWeight.w600, color: C.ink),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Add an extension now to keep your invitation active for longer.',
                            style: sans(12.5, h: 1.4),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Switch(
                      value: extension,
                      onChanged: (v) {
                        setState(() => extension = v);
                        _quote();
                      },
                    ),
                    Expanded(
                      child: Text(
                        '${(p.extensionDays / 30).round()}-month extension · ${money(p.extensionPriceCents)}',
                        style: sans(13, color: C.ink),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: C.line),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.sell_outlined, size: 18, color: C.body),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: code,
                          textCapitalization: TextCapitalization.characters,
                          style: sans(14, color: C.ink),
                          decoration: InputDecoration(
                            isCollapsed: true,
                            border: InputBorder.none,
                            hintText: 'Discount code',
                            hintStyle: sans(14, color: C.muted),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              OutlineBtn(
                'Apply',
                height: 44,
                onTap: quoting
                    ? null
                    : () {
                        appliedCode = code.text.trim().isEmpty
                            ? null
                            : code.text.trim();
                        _quote(fromApply: true);
                      },
              ),
            ],
          ),
          if (codeError != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(codeError!, style: sans(12.5, color: C.red)),
            ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: C.blueSoft,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  size: 18,
                  color: C.purple,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'You’ll pay securely on Stripe. Your event is published as soon as the payment is confirmed.',
                    style: sans(12, h: 1.4),
                  ),
                ),
              ],
            ),
          ),
          if (error != null) ...[
            const SizedBox(height: 12),
            Text(error!, style: sans(13, color: C.red)),
          ],
          const SizedBox(height: 16),
          PrimaryButton(
            (quote?.total ?? 1) <= 0 ? 'Publish event' : 'Continue to payment',
            icon: Icons.arrow_forward_rounded,
            height: 48,
            busy: busy,
            onTap: quote == null ? null : _publish,
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              'One-time payment. No subscriptions, no ads.',
              style: sans(12, color: C.muted),
            ),
          ),
        ],
      ),
    );
  }

  Widget _line(String a, String b) => Row(
    children: [
      Expanded(
        child: Text(a, style: sans(13.5, color: C.ink)),
      ),
      Text(b, style: sans(13.5, color: C.ink)),
    ],
  );
}
