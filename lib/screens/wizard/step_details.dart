import 'package:flutter/material.dart';
import '../../data/backend.dart';
import '../../theme/app_theme.dart';
import '../../util/format.dart';
import '../../widgets/common.dart';
import '../../widgets/responsive.dart';
import 'wizard.dart';
import 'wizard_ui.dart';

class DetailsStep extends StatefulWidget {
  final WizardController c;
  const DetailsStep(this.c, {super.key});
  @override
  State<DetailsStep> createState() => _DetailsStepState();
}

class _DetailsStepState extends State<DetailsStep> {
  late int? categoryId = widget.c.event?.categoryId;
  late final title = TextEditingController(text: widget.c.event?.title ?? '');
  late final venue = TextEditingController(
    text: widget.c.event?.venueName ?? '',
  );
  late final address = TextEditingController(
    text: widget.c.event?.venueAddress ?? '',
  );
  late String language = widget.c.event?.language ?? 'en';
  late DateTime? date = widget.c.event?.startsAt?.toLocal();
  late TimeOfDay? time = date == null ? null : TimeOfDay.fromDateTime(date!);
  bool busy = false;
  String? error;

  @override
  void dispose() {
    title.dispose();
    venue.dispose();
    address.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final first = date != null && date!.isBefore(now) ? date! : now;
    final d = await showDatePicker(
      context: context,
      initialDate: date ?? now.add(const Duration(days: 30)),
      firstDate: DateTime(first.year, first.month, first.day),
      lastDate: now.add(const Duration(days: 365 * 5)),
    );
    if (d != null) setState(() => date = d);
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(
      context: context,
      initialTime: time ?? const TimeOfDay(hour: 18, minute: 0),
    );
    if (t != null) setState(() => time = t);
  }

  Future<void> _next() async {
    if (categoryId == null)
      return setState(() => error = 'Choose the type of event.');
    if (title.text.trim().isEmpty)
      return setState(() => error = 'Give your event a title.');
    if (date == null)
      return setState(() => error = 'Choose the date of your event.');
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final t = time ?? const TimeOfDay(hour: 18, minute: 0);
      await widget.c.saveDetails(
        categoryId: categoryId!,
        title: title.text,
        language: language,
        startsAt: DateTime(
          date!.year,
          date!.month,
          date!.day,
          t.hour,
          t.minute,
        ),
        venueName: venue.text,
        venueAddress: address.text,
      );
      widget.c.goTo(
        widget.c.event!.templateId == null ? 2 : (widget.c.published ? 3 : 2),
      );
    } catch (e) {
      if (mounted)
        setState(() {
          error = errText(e);
          busy = false;
        });
    }
  }

  @override
  void initState() {
    super.initState();
    for (final t in [title, venue, address]) {
      t.addListener(() => setState(() {}));
    }
  }

  @override
  Widget build(BuildContext context) {
    final left = PanelCard(
      title: 'Event details',
      subtitle:
          'Tell us about your event so we can personalize your experience.',
      child: _form(),
    );
    final right = Column(
      children: [_summary(), const SizedBox(height: 18), _next3()],
    );
    return WizardPage(
      c: widget.c,
      content: AdaptiveRow(
        breakpoint: 980,
        gap: 22,
        flex: const [7, 4],
        children: [left, right],
      ),
      footer: WizardFooter(
        onBack: null,
        nextLabel: 'Continue to template',
        busy: busy,
        onNext: _next,
      ),
    );
  }

  Widget _form() {
    final cats = widget.c.categories;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Event type',
          style: sans(15, w: FontWeight.w600, color: C.ink),
        ),
        const SizedBox(height: 2),
        Text(
          'Choose the option that best describes your event.',
          style: sans(12.5, color: C.muted),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, box) {
            const gap = 10.0;
            final cols = ((box.maxWidth + gap) / (118 + gap)).floor().clamp(
              2,
              6,
            );
            final w = (box.maxWidth - gap * (cols - 1)) / cols;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final cat in cats)
                  HoverBuilder(
                    hoverScale: 1.0,
                    onTap: () => setState(() => categoryId = cat.id),
                    builder: (context, hover) => AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: w,
                      height: 78,
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      decoration: BoxDecoration(
                        color: categoryId == cat.id
                            ? C.brandSoft
                            : hover
                            ? const Color(0xFFFCFAF9)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: categoryId == cat.id
                              ? C.brand
                              : hover
                              ? C.brandBorder
                              : C.line,
                          width: categoryId == cat.id ? 1.5 : 1,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(categoryIcon(cat.icon), size: 24, color: C.ink),
                          const SizedBox(height: 6),
                          Text(
                            cat.name,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: sans(12, color: C.ink, h: 1.2),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 22),
        const Divider(height: 1, color: C.line),
        const SizedBox(height: 22),
        Field('Event title', title, hint: "e.g. Sofia's Birthday"),
        const SizedBox(height: 4),
        Text(
          'This will be shown on your invitation.',
          style: sans(12, color: C.muted),
        ),
        const SizedBox(height: 16),
        AdaptiveRow(
          breakpoint: 560,
          gap: 16,
          children: [
            _pickerField(
              'Date',
              date == null ? 'Choose a date' : fmtDate(date),
              Icons.calendar_today_outlined,
              _pickDate,
            ),
            _pickerField(
              'Time',
              time == null ? '6:00 PM' : time!.format(context),
              Icons.schedule_rounded,
              _pickTime,
            ),
          ],
        ),
        const SizedBox(height: 16),
        AdaptiveRow(
          breakpoint: 560,
          gap: 16,
          children: [
            Field('Venue name (optional)', venue, hint: 'Garden Las Flores'),
            Field('Address (optional)', address, hint: 'Street, city'),
          ],
        ),
        const SizedBox(height: 18),
        Text(
          'Language of the invitation',
          style: sans(12.5, w: FontWeight.w500, color: C.ink),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (k, l) in const [
              ('en', 'English (EN)'),
              ('es', 'Spanish (ES)'),
            ])
              HoverBuilder(
                hoverScale: 1.0,
                onTap: () => setState(() => language = k),
                builder: (context, hover) => Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  decoration: BoxDecoration(
                    color: language == k ? C.brandSoft : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: language == k
                          ? C.brand
                          : hover
                          ? C.brandBorder
                          : C.line,
                    ),
                  ),
                  child: Center(
                    widthFactor: 1,
                    child: Text(
                      l,
                      style: sans(
                        13.5,
                        w: FontWeight.w500,
                        color: language == k ? C.brand : C.ink,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        if (error != null) ...[
          const SizedBox(height: 14),
          Text(error!, style: sans(13.5, color: C.red)),
        ],
      ],
    );
  }

  Widget _summary() {
    final cat = widget.c.categories
        .where((x) => x.id == categoryId)
        .firstOrNull;
    final t = time ?? const TimeOfDay(hour: 18, minute: 0);
    return PanelCard(
      title: 'Live summary',
      subtitle: 'Here’s what you’ve set so far.',
      child: SummaryList([
        (
          cat == null ? Icons.category_outlined : categoryIcon(cat.icon),
          'Event type',
          cat?.name ?? '',
          null,
        ),
        (Icons.description_outlined, 'Event title', title.text.trim(), null),
        (
          Icons.calendar_today_outlined,
          'Date & time',
          date == null ? '' : '${fmtDate(date)} · ${t.format(context)}',
          null,
        ),
        (
          Icons.place_outlined,
          'Location',
          venue.text.trim(),
          address.text.trim().isEmpty ? 'Street, city' : address.text.trim(),
        ),
        (
          Icons.language_rounded,
          'Language',
          language == 'es' ? 'Spanish (ES)' : 'English (EN)',
          null,
        ),
      ]),
    );
  }

  Widget _next3() => PanelCard(
    title: 'What happens next?',
    subtitle: 'You’re just getting started! Here’s what’s next.',
    child: Row(
      children: [
        Expanded(
          flex: 3,
          child: Column(
            children: [
              for (final (n, t, d) in const [
                (2, 'Choose a template', 'Pick a design that fits your event.'),
                (
                  3,
                  'Customize your invitation',
                  'Add photos, edit text, and make it yours.',
                ),
                (
                  4,
                  'Invite guests and publish',
                  'Add your guest list and choose a plan to go live.',
                ),
              ])
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: C.brandSoft,
                        ),
                        child: Text(
                          '$n',
                          style: sans(13, w: FontWeight.w600, color: C.brand),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              t,
                              style: sans(
                                13.5,
                                w: FontWeight.w600,
                                color: C.ink,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(d, style: sans(12.5, color: C.muted)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        if (!isMobile(context)) ...[
          const SizedBox(width: 10),
          SizedBox(
            width: 112,
            child: Transform.rotate(
              angle: .08,
              child: AspectRatio(
                aspectRatio: .78,
                child: Container(
                  decoration: BoxDecoration(
                    color: C.brandSoft,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: C.brandBorder),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.asset('assets/samples/p1_0.jpg', fit: BoxFit.cover),
                      Center(
                        child: Text(
                          'Let’s\nCelebrate',
                          textAlign: TextAlign.center,
                          style: script(24, color: C.ink),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    ),
  );

  Widget _pickerField(
    String label,
    String value,
    IconData icon,
    VoidCallback onTap,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: sans(12.5, w: FontWeight.w500, color: C.ink),
      ),
      const SizedBox(height: 6),
      InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
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
              Icon(icon, size: 18, color: C.body),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  value,
                  overflow: TextOverflow.ellipsis,
                  style: sans(14, color: C.ink),
                ),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}
