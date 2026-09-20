import 'package:flutter/material.dart';
import '../../data/backend.dart';
import '../../data/models.dart';
import '../../theme/app_theme.dart';
import '../../util/format.dart';
import '../../widgets/common.dart';
import '../../widgets/invitation.dart';
import '../../widgets/responsive.dart';
import 'wizard.dart';
import 'wizard_ui.dart';

class TemplateStep extends StatefulWidget {
  final WizardController c;
  const TemplateStep(this.c, {super.key});
  @override
  State<TemplateStep> createState() => _TemplateStepState();
}

class _TemplateStepState extends State<TemplateStep> {
  String? style, tone;
  bool showAll = false;
  bool busy = false;

  Future<void> _pick(Template t) async {
    setState(() => busy = true);
    try {
      await widget.c.setTemplate(t.id);
    } catch (e) {
      if (mounted) toast(context, errText(e), error: true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  String _tone(Template t) {
    final bg = t.layout.pal;
    if (bg.isDark) return 'dark';
    final hsl = HSLColor.fromColor(bg.bg);
    return hsl.saturation > .6 && hsl.lightness < .8 ? 'vivid' : 'light';
  }

  final search = TextEditingController();
  String sort = 'recommended';

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    final e = c.event!;
    final slug = c.category?.slug;
    final recommended = c.templates
        .where((t) => slug != null && t.themes.contains(slug))
        .toList();
    final base = showAll || recommended.isEmpty ? c.templates : recommended;
    final styles = {for (final t in c.templates) t.style}.toList()..sort();
    final q = search.text.trim().toLowerCase();
    final shown = base
        .where(
          (t) =>
              (style == null || t.style == style) &&
              (tone == null || _tone(t) == tone) &&
              (q.isEmpty || t.name.toLowerCase().contains(q)),
        )
        .toList();
    if (sort == 'name') shown.sort((a, b) => a.name.compareTo(b.name));
    final selected = c.template;
    final ev = previewEvent(
      title: e.title,
      date: e.startsAt,
      venue: e.venueName,
      address: e.venueAddress,
    );

    final main = AppCard(
      padding: EdgeInsets.all(isMobile(context) ? 14 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              if (recommended.isNotEmpty)
                _seg(
                  'Recommended for ${c.category?.name ?? 'your event'}',
                  !showAll,
                  () => setState(() => showAll = false),
                  icon: Icons.auto_awesome_rounded,
                ),
              _seg(
                '${c.templates.length} templates',
                showAll || recommended.isEmpty,
                () => setState(() => showAll = true),
              ),
            ],
          ),
          const SizedBox(height: 16),
          AutoGrid(
            minTile: 180,
            gap: 12,
            children: [
              Container(
                height: 46,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: C.line),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.search_rounded, size: 19, color: C.body),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: search,
                        onChanged: (_) => setState(() {}),
                        style: sans(14, color: C.ink),
                        decoration: InputDecoration(
                          isCollapsed: true,
                          border: InputBorder.none,
                          hintText: 'Search templates...',
                          hintStyle: sans(14, color: C.muted),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SelectBox<String>(
                label: 'Style',
                value: style,
                options: [
                  for (final s in styles)
                    (s, s[0].toUpperCase() + s.substring(1)),
                ],
                onChanged: (v) => setState(() => style = v),
                anyLabel: 'Any style',
              ),
              SelectBox<String>(
                label: 'Colors',
                value: tone,
                options: const [
                  ('light', 'Light'),
                  ('dark', 'Dark'),
                  ('vivid', 'Vivid'),
                ],
                onChanged: (v) => setState(() => tone = v),
                anyLabel: 'Any colors',
              ),
              SelectBox<String>(
                label: 'Sort by',
                value: sort,
                options: const [
                  ('recommended', 'Sort by: Recommended'),
                  ('name', 'Sort by: Name (A–Z)'),
                ],
                onChanged: (v) => setState(() => sort = v ?? 'recommended'),
                anyLabel: 'Sort by: Recommended',
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (shown.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Text(
                  'No templates match these filters yet.',
                  style: sans(14),
                ),
              ),
            )
          else
            AutoGrid(
              minTile: 190,
              gap: 14,
              children: [
                for (final t in shown) _card(t, selected?.id == t.id, ev),
              ],
            ),
        ],
      ),
    );

    final side = Column(
      children: [
        PanelCard(
          title: 'Your event',
          trailing: LinkText('Edit', onTap: () => c.goTo(1)),
          child: SummaryList([
            (
              c.category == null
                  ? Icons.category_outlined
                  : categoryIcon(c.category!.icon),
              'Event type',
              c.category?.name ?? '',
              null,
            ),
            (Icons.description_outlined, 'Event title', e.displayTitle, null),
            (
              Icons.calendar_today_outlined,
              'Date & time',
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
              Icons.language_rounded,
              'Language',
              e.language == 'es' ? 'Spanish (ES)' : 'English (EN)',
              null,
            ),
          ]),
        ),
        const SizedBox(height: 18),
        PanelCard(
          title: 'Mobile preview',
          child: Column(
            children: [
              Center(
                child: selected == null
                    ? SizedBox(
                        height: 160,
                        child: Center(
                          child: Text(
                            'Select a template to preview it here.',
                            textAlign: TextAlign.center,
                            style: sans(13.5, color: C.muted),
                          ),
                        ),
                      )
                    : PhonePreview(
                        event: e,
                        design: e.pageDesign,
                        layers: c.blocks,
                        width: 220,
                      ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: [
                  OutlineBtn(
                    'Preview full screen',
                    icon: Icons.visibility_outlined,
                    onTap: selected == null
                        ? null
                        : () => showFullPreview(
                            context,
                            event: e,
                            design: e.pageDesign,
                            layers: c.blocks,
                          ),
                  ),
                  OutlineBtn(
                    'Change event details',
                    icon: Icons.edit_outlined,
                    onTap: () => c.goTo(1),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );

    return WizardPage(
      c: c,
      content: AdaptiveRow(
        breakpoint: 1000,
        gap: 22,
        flex: const [1, 0],
        children: [main, Fixed(400, side)],
      ),
      footer: WizardFooter(
        onBack: () => c.goTo(1),
        nextLabel: 'Continue to edit',
        busy: busy,
        onNext: selected == null ? null : () => c.goTo(3),
      ),
    );
  }

  Widget _seg(String label, bool on, VoidCallback f, {IconData? icon}) =>
      HoverBuilder(
        hoverScale: 1.0,
        onTap: f,
        builder: (context, hover) => Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: on
                ? C.brandSoft
                : (hover ? const Color(0xFFF7F5F4) : Colors.white),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: on ? C.brandBorder : C.line),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: on ? C.brand : C.body),
                const SizedBox(width: 8),
              ],
              Text(
                label,
                style: sans(
                  13,
                  w: FontWeight.w500,
                  color: on ? C.brand : C.ink,
                ),
              ),
            ],
          ),
        ),
      );

  Widget _card(Template t, bool sel, EventModel ev) => HoverBuilder(
    hoverScale: 1.015,
    onTap: busy ? null : () => _pick(t),
    builder: (context, hover) => Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: sel ? C.brand : (hover ? C.brandBorder : C.line),
          width: sel ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              AspectRatio(
                aspectRatio: 1,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: TemplateThumb(template: t, event: ev),
                ),
              ),
              if (sel)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: C.brand,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'Selected',
                      style: sans(
                        11.5,
                        w: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  t.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: sans(13, w: FontWeight.w600, color: C.ink),
                ),
              ),
              for (final s in t.swatches.skip(1).take(3))
                Container(
                  width: 15,
                  height: 15,
                  margin: const EdgeInsets.only(left: 5),
                  decoration: BoxDecoration(
                    color: s,
                    shape: BoxShape.circle,
                    border: Border.all(color: C.line),
                  ),
                ),
            ],
          ),
        ],
      ),
    ),
  );
}
