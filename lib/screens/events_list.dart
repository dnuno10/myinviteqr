import 'package:flutter/material.dart';
import '../data/backend.dart';
import '../data/models.dart';
import '../theme/app_theme.dart';
import '../util/format.dart';
import '../widgets/common.dart';
import '../widgets/home_sections.dart';
import '../widgets/invitation.dart';
import '../widgets/responsive.dart';
import '../widgets/shell.dart';
import 'event_detail.dart';
import 'wizard/wizard.dart';

class EventsListScreen extends StatefulWidget {
  const EventsListScreen({super.key});
  @override
  State<EventsListScreen> createState() => _EventsListScreenState();
}

class _Data {
  final List<EventModel> events;
  final Map<String, Template> templates;
  final Map<int, Category> categories;
  final Map<String, GuestCounts> counts;
  _Data(this.events, this.templates, this.categories, this.counts);
}

class _EventsListScreenState extends State<EventsListScreen> {
  late Future<_Data> future = _load();
  String filter = 'all';

  Future<_Data> _load() async {
    final r = await Future.wait([
      Backend.i.myEvents(),
      Backend.i.templates(),
      Backend.i.categories(),
      Backend.i.guestCounts(),
    ]);
    return _Data(
      r[0] as List<EventModel>,
      {for (final t in r[1] as List<Template>) t.id: t},
      {for (final c in r[2] as List<Category>) c.id: c},
      r[3] as Map<String, GuestCounts>,
    );
  }

  void _reload() => setState(() {
    future = _load();
  });

  Future<void> _push(Widget page) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
    if (mounted) _reload();
  }

  Future<void> _delete(EventModel e) async {
    if (await confirmDeleteEvent(context, e)) _reload();
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
        return _body(snap.data!);
      },
    ),
  );

  final search = TextEditingController();

  bool _match(EventModel e) =>
      (switch (filter) {
        'draft' => e.isDraft,
        'published' => !e.isDraft && !e.isEnded,
        'ended' => e.isEnded,
        _ => true,
      }) &&
      e.displayTitle.toLowerCase().contains(search.text.trim().toLowerCase());

  Widget _body(_Data d) {
    final name = profileNotifier.value?.firstName ?? '';
    final shown = d.events.where(_match).toList();
    final counts = {
      'all': d.events.length,
      'draft': d.events.where((e) => e.isDraft).length,
      'published': d.events.where((e) => !e.isDraft && !e.isEnded).length,
      'ended': d.events.where((e) => e.isEnded).length,
    };
    return PageBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AdaptiveRow(
            breakpoint: 640,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              PageTitle(
                name.isEmpty ? 'Events' : 'Hi, $name',
                'Your events, all in one place.',
                Icons.calendar_today_outlined,
              ),
              Fixed(
                340,
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  alignment: WrapAlignment.end,
                  children: [
                    OutlineBtn(
                      'Browse templates',
                      icon: Icons.grid_view_rounded,
                      height: 40,
                      onTap: () => _push(const WizardScreen()),
                    ),
                    PrimaryButton(
                      'Create event',
                      icon: Icons.add_rounded,
                      expand: false,
                      onTap: () => _push(const WizardScreen()),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          if (d.events.isEmpty)
            HomeHero(onCreate: () => _push(const WizardScreen()))
          else ...[
            _searchBar(counts),
            const SizedBox(height: 16),
            if (shown.isEmpty)
              AppCard(
                padding: const EdgeInsets.all(28),
                child: Center(
                  child: Text('No events match your search.', style: sans(14)),
                ),
              )
            else
              LayoutBuilder(
                builder: (context, c) => c.maxWidth < 760
                    ? Column(
                        children: [
                          for (final e in shown)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _card(e, d),
                            ),
                        ],
                      )
                    : _table(shown, d),
              ),
            const SizedBox(height: 10),
            Text(
              'Showing ${shown.length} of ${d.events.length}',
              style: sans(13, color: C.muted),
            ),
          ],
          const SizedBox(height: 22),
          QuickActions([
            QuickAction(
              Icons.grid_view_rounded,
              'Start from template',
              'Explore our beautiful designs',
              () => _push(const WizardScreen()),
            ),
            QuickAction(
              Icons.people_outline_rounded,
              'Import guests',
              'Add your guest list easily',
              () => _push(const WizardScreen()),
            ),
            QuickAction(
              Icons.visibility_outlined,
              'View sample invitation',
              'See a live example',
              () => _sample(d),
            ),
            QuickAction(
              Icons.help_outline_rounded,
              'How it works',
              'Learn in 2 minutes',
              _howItWorks,
            ),
          ]),
          const SizedBox(height: 32),
          PopularTemplates(
            templates: d.templates.values
                .where((t) => t.status == 'published')
                .toList(),
            onOpen: (_) => _push(const WizardScreen()),
            onViewAll: () => _push(const WizardScreen()),
          ),
          const SizedBox(height: 24),
          HelpBanner(onContact: () => showSupportDialog(context)),
        ],
      ),
    );
  }

  Widget _searchBar(Map<String, int> counts) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: C.line),
        ),
        child: Row(
          children: [
            const Icon(Icons.search_rounded, size: 19, color: C.muted),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: search,
                onChanged: (_) => setState(() {}),
                style: sans(14, color: C.ink),
                decoration: InputDecoration(
                  isCollapsed: true,
                  border: InputBorder.none,
                  hintText: 'Search by event name...',
                  hintStyle: sans(14, color: C.muted),
                ),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final (k, l) in const [
            ('all', 'All'),
            ('draft', 'Drafts'),
            ('published', 'Published'),
            ('ended', 'Ended'),
          ])
            HoverBuilder(
              hoverScale: 1.0,
              onTap: () => setState(() => filter = k),
              builder: (context, hover) => Container(
                height: 34,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: filter == k
                      ? C.brandSoft
                      : hover
                      ? const Color(0xFFF7F5F4)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: filter == k ? C.brandBorder : C.line,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l,
                      style: sans(
                        13,
                        w: FontWeight.w500,
                        color: filter == k ? C.brand : C.ink,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${counts[k]}',
                      style: sans(12, color: filter == k ? C.brand : C.muted),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    ],
  );

  Widget _table(List<EventModel> shown, _Data d) {
    Widget head(String t, {int flex = 1}) => Expanded(
      flex: flex,
      child: Text(
        t,
        style: sans(13, w: FontWeight.w500, color: C.muted),
      ),
    );
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(
              children: [
                head('Event', flex: 5),
                head('Status', flex: 2),
                head('Plan', flex: 2),
                head('Guests', flex: 2),
                head('Time left', flex: 2),
                const SizedBox(width: 40),
              ],
            ),
          ),
          for (final e in shown) ...[
            const Divider(height: 1, color: C.line),
            _row(e, d),
          ],
        ],
      ),
    );
  }

  Widget _row(EventModel e, _Data d) {
    final t = e.templateId == null ? null : d.templates[e.templateId];
    final cat = e.categoryId == null ? null : d.categories[e.categoryId];
    final g = d.counts[e.id];
    return HoverBuilder(
      hoverScale: 1.0,
      onTap: () => _push(
        e.isDraft
            ? WizardScreen(eventId: e.id)
            : EventDetailScreen(eventId: e.id),
      ),
      builder: (context, hover) => Container(
        color: hover ? const Color(0xFFFCFAF9) : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            Expanded(
              flex: 5,
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: t == null
                          ? Container(
                              color: const Color(0xFFF6F4F3),
                              child: Icon(
                                categoryIcon(cat?.icon ?? 'more'),
                                size: 20,
                                color: C.muted,
                              ),
                            )
                          : TemplateThumb(
                              template: t,
                              event: e,
                              design: e.design['palette'] == null
                                  ? null
                                  : e.pageDesign,
                            ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          e.displayTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: sans(14.5, w: FontWeight.w600, color: C.ink),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          [
                            if (cat != null) cat.name,
                            if (e.startsAt != null) fmtDate(e.startsAt),
                          ].join(' · ').ifEmpty('No date yet'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: sans(12.5, color: C.muted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Align(
                alignment: Alignment.centerLeft,
                child: statusPill(e.status, ended: e.isEnded),
              ),
            ),
            Expanded(
              flex: 2,
              child: Align(
                alignment: Alignment.centerLeft,
                child: e.plan == null
                    ? Text('—', style: sans(14, color: C.muted))
                    : (e.plan == 'premium' ? Pill.premium() : Pill.essential()),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                e.isDraft
                    ? '—'
                    : '${g?.confirmed ?? 0} / ${g?.total ?? 0} confirmed',
                style: sans(13.5, color: C.ink),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                e.isDraft
                    ? 'Edited ${fmtAgo(e.updatedAt)}'
                    : e.isEnded
                    ? 'Ended'
                    : '${e.daysLeft} days left',
                style: sans(13.5, color: C.ink),
              ),
            ),
            SizedBox(width: 40, child: _menu(e)),
          ],
        ),
      ),
    );
  }

  Widget _menu(EventModel e) => PopupMenuButton<String>(
    tooltip: '',
    color: Colors.white,
    padding: EdgeInsets.zero,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(10),
      side: const BorderSide(color: C.line),
    ),
    icon: const Icon(Icons.more_horiz_rounded, size: 20, color: C.ink),
    onSelected: (_) => _delete(e),
    itemBuilder: (_) => [
      PopupMenuItem(
        value: 'delete',
        child: Row(
          children: [
            const Icon(Icons.delete_outline_rounded, size: 18, color: C.red),
            const SizedBox(width: 10),
            Text('Delete event', style: sans(14, color: C.red)),
          ],
        ),
      ),
    ],
  );

  void _sample(_Data d) {
    final t = d.templates.values
        .where((t) => t.status == 'published')
        .firstOrNull;
    if (t == null) return;
    showFullPreview(
      context,
      event: previewEvent(title: 'Sample invitation'),
      design: t.layout.design,
      layers: layersFromTemplate(t),
    );
  }

  void _howItWorks() => showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: Colors.white,
      title: Text('How it works', style: serif(20)),
      content: Text(
        '1. Create an event and give it a name.\n2. Choose a template and edit it.\n3. Add your guests.\n4. Publish and share your invitation link or QR code.',
        style: sans(14, h: 1.6),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text('Got it', style: sans(14, color: C.brand)),
        ),
      ],
    ),
  );

  // ignore: unused_element
  Widget _empty() => AppCard(
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
    child: Column(
      children: [
        const Icon(Icons.mail_outline_rounded, size: 48, color: C.brand),
        const SizedBox(height: 16),
        Text(
          'You have no events yet',
          textAlign: TextAlign.center,
          style: serif(24),
        ),
        const SizedBox(height: 8),
        Text(
          'Your invitation, ready in 5 minutes.',
          textAlign: TextAlign.center,
          style: sans(14),
        ),
        const SizedBox(height: 22),
        PrimaryButton(
          'Create your first event',
          icon: Icons.add_rounded,
          expand: false,
          onTap: () => _push(const WizardScreen()),
        ),
      ],
    ),
  );

  Widget _card(EventModel e, _Data d) {
    final t = e.templateId == null ? null : d.templates[e.templateId];
    final cat = e.categoryId == null ? null : d.categories[e.categoryId];
    final g = d.counts[e.id];
    return HoverLift(
      child: AppCard(
        padding: EdgeInsets.zero,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _push(
            e.isDraft
                ? WizardScreen(eventId: e.id)
                : EventDetailScreen(eventId: e.id),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(15),
                ),
                child: SizedBox(
                  height: 150,
                  width: double.infinity,
                  child: t == null
                      ? Container(
                          color: const Color(0xFFF6F4F3),
                          child: Icon(
                            categoryIcon(cat?.icon ?? 'more'),
                            size: 44,
                            color: C.muted,
                          ),
                        )
                      : TemplateThumb(
                          template: t,
                          event: e,
                          design: e.design['palette'] == null
                              ? null
                              : e.pageDesign,
                        ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            e.displayTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: serif(19),
                          ),
                        ),
                        PopupMenuButton<String>(
                          tooltip: '',
                          color: Colors.white,
                          padding: EdgeInsets.zero,
                          icon: const Icon(
                            Icons.more_vert_rounded,
                            size: 20,
                            color: C.ink,
                          ),
                          onSelected: (_) => _delete(e),
                          itemBuilder: (_) => [
                            PopupMenuItem(
                              value: 'delete',
                              child: Text(
                                'Delete event',
                                style: sans(14, color: C.red),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [
                        if (cat != null) cat.name,
                        if (e.startsAt != null) fmtDate(e.startsAt),
                      ].join(' · ').ifEmpty('No date yet'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: sans(13),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        statusPill(e.status, ended: e.isEnded),
                        if (e.plan != null)
                          (e.plan == 'premium'
                              ? Pill.premium()
                              : Pill.essential()),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (e.isDraft)
                      Text(
                        'Last edited ${fmtAgo(e.updatedAt)}',
                        style: sans(12.5, color: C.muted),
                      )
                    else
                      Row(
                        children: [
                          const Icon(
                            Icons.people_outline_rounded,
                            size: 17,
                            color: C.body,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '${g?.confirmed ?? 0} confirmed · ${g?.total ?? 0} guests',
                              overflow: TextOverflow.ellipsis,
                              style: sans(12.5),
                            ),
                          ),
                          if (!e.isEnded)
                            Text(
                              '${e.daysLeft} days left',
                              style: sans(
                                12.5,
                                w: FontWeight.w600,
                                color: C.ink,
                              ),
                            ),
                        ],
                      ),
                    if (e.isDraft) ...[
                      const SizedBox(height: 12),
                      const OutlineBtn(
                        'Continue editing',
                        icon: Icons.edit_outlined,
                        pink: true,
                        expand: true,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

extension on String {
  String ifEmpty(String other) => isEmpty ? other : this;
}
