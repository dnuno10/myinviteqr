import 'package:flutter/material.dart';
import '../../data/backend.dart';
import '../../data/models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/guests_panel.dart';
import '../../widgets/responsive.dart';
import 'step_details.dart';
import 'step_editor.dart';
import 'step_publish.dart';
import 'step_template.dart';
import 'wizard_ui.dart';

/// State shared by the five creation steps. Every step persists to the database,
/// so an unfinished event stays available as a draft.
class WizardController extends ChangeNotifier {
  EventModel? event;
  List<Category> categories = [];
  List<Template> templates = [];
  List<Plan> plans = [];
  List<ColorCombo> palettes = [];
  List<EventBlock> blocks = [];
  List<Guest> guests = [];
  int step = 1;
  bool loading = true;
  String? loadError;

  Template? get template =>
      templates.where((t) => t.id == event?.templateId).firstOrNull;
  Category? get category =>
      categories.where((c) => c.id == event?.categoryId).firstOrNull;
  bool get published => event != null && !event!.isDraft;
  Plan? get essential => plans.where((p) => p.code == 'essential').firstOrNull;

  Future<void> init(String? eventId, int? startStep) async {
    loading = true;
    loadError = null;
    notifyListeners();
    try {
      final r = await Future.wait([
        Backend.i.categories(),
        Backend.i.templates(),
        Backend.i.plans(),
        Backend.i.palettes(),
      ]);
      categories = r[0] as List<Category>;
      templates = r[1] as List<Template>;
      plans = r[2] as List<Plan>;
      palettes = r[3] as List<ColorCombo>;
      if (eventId != null) {
        event = await Backend.i.event(eventId);
        blocks = await Backend.i.blocks(eventId);
        guests = await Backend.i.guests(eventId);
        step =
            startStep ??
            (event!.templateId == null
                ? (event!.categoryId == null || event!.title.isEmpty ? 1 : 2)
                : 3);
      }
    } catch (e, st) {
      debugPrint('wizard init failed: $e\n$st');
      loadError = errText(e);
    }
    loading = false;
    notifyListeners();
  }

  void goTo(int s) {
    step = s;
    notifyListeners();
  }

  Future<void> saveDetails({
    required int categoryId,
    required String title,
    required DateTime startsAt,
    String? venueName,
    String? venueAddress,
    required String language,
  }) async {
    final data = {
      'category_id': categoryId,
      'title': title.trim(),
      'starts_at': startsAt.toUtc().toIso8601String(),
      'venue_name': (venueName ?? '').trim().isEmpty ? null : venueName!.trim(),
      'venue_address': (venueAddress ?? '').trim().isEmpty
          ? null
          : venueAddress!.trim(),
      'language': language,
    };
    event = event == null
        ? await Backend.i.createEvent(data)
        : await Backend.i.updateEvent(event!.id, data);
    notifyListeners();
  }

  /// Applies a template: its layers and design replace whatever the event had.
  Future<void> setTemplate(String id) async {
    final t = templates.firstWhere((t) => t.id == id);
    final layers = layersFromTemplate(t);
    await Backend.i.saveBlocks(event!.id, layers);
    event = await Backend.i.updateEvent(event!.id, {
      'template_id': id,
      'design': t.layout.design.toJson(),
    });
    blocks = layers;
    notifyListeners();
  }

  Future<void> reloadGuests() async {
    guests = await Backend.i.guests(event!.id);
    notifyListeners();
  }

  void updateLocalEvent(EventModel e) {
    event = e;
    notifyListeners();
  }
}

class WizardScreen extends StatefulWidget {
  final String? eventId;
  final int? startStep;
  const WizardScreen({super.key, this.eventId, this.startStep});
  @override
  State<WizardScreen> createState() => _WizardScreenState();
}

class _WizardScreenState extends State<WizardScreen> {
  final c = WizardController();

  @override
  void initState() {
    super.initState();
    c.init(widget.eventId, widget.startStep);
  }

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  Widget _step() {
    switch (c.step) {
      case 1:
        return DetailsStep(c);
      case 2:
        return TemplateStep(c);
      case 3:
        return EditorStep(c);
      case 4:
        return _GuestsStep(c);
      default:
        return PublishStep(c);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: c,
    builder: (context, _) {
      final mobile = isMobile(context);
      return Scaffold(
        backgroundColor: C.bg,
        body: SafeArea(
          child: Column(
            children: [
              Container(
                height: 56,
                color: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: pagePad(context)),
                child: Row(
                  children: [
                    Logo(height: mobile ? 28 : 32),
                    const Spacer(),
                    OutlineBtn(
                      c.published ? 'Close' : 'Save & exit',
                      icon: c.published
                          ? Icons.close_rounded
                          : Icons.bookmark_border_rounded,
                      onTap: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: C.line),
              Expanded(
                child: c.loading
                    ? const LoadingView()
                    : c.loadError != null
                    ? ErrorView(
                        c.loadError!,
                        onRetry: () => c.init(widget.eventId, widget.startStep),
                      )
                    : _step(),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _GuestsStep extends StatelessWidget {
  final WizardController c;
  const _GuestsStep(this.c);

  Widget _way(
    BuildContext context,
    IconData icon,
    Color tint,
    Color fg,
    String title,
    String desc,
  ) {
    return HoverBuilder(
      hoverScale: 1.0,
      onTap: () =>
          toast(context, 'This works as soon as you publish your event.'),
      builder: (context, hover) => AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(14),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: hover ? C.brandBorder : C.line),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: tint,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 24, color: fg),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: sans(14, w: FontWeight.w600, color: C.ink),
                  ),
                  const SizedBox(height: 2),
                  Text(desc, style: sans(12.5, color: C.muted, h: 1.35)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, size: 20, color: C.ink),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final main = AppCard(
      padding: EdgeInsets.all(isMobile(context) ? 14 : 22),
      child: GuestsPanel(
        event: c.event!,
        guests: c.guests,
        maxGuests: c.essential?.maxGuests,
        onChanged: c.reloadGuests,
      ),
    );
    final side = Column(
      children: [
        PanelCard(
          title: 'Ways to invite',
          subtitle: 'Choose the best way to get your guests on the list.',
          child: Column(
            children: [
              _way(
                context,
                Icons.link_rounded,
                C.brandSoft,
                C.brand,
                'Share invitation link',
                'Send a single link for guests to RSVP themselves.',
              ),
              _way(
                context,
                Icons.qr_code_2_rounded,
                C.blueSoft,
                const Color(0xFF3B6FE0),
                'Share QR code',
                'Display at your venue or share online for easy access.',
              ),
              _way(
                context,
                Icons.person_outline_rounded,
                C.greenSoft,
                C.green,
                'Send individual links',
                'Create personalized invitation links for each guest.',
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        PanelCard(
          title: 'How guest tracking works',
          subtitle: 'We’ll automatically track your invitations and RSVPs.',
          child: Column(
            children: [
              for (final (n, t, d) in const [
                (1, 'Track opens', 'See when guests open your invitation.'),
                (
                  2,
                  'Collect RSVPs',
                  'View who’s coming, maybe, or can’t attend.',
                ),
                (
                  3,
                  'Send reminders',
                  'Follow up with guests who haven’t responded yet.',
                ),
              ])
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: C.brandSoft,
                        ),
                        child: Text(
                          '$n',
                          style: sans(14, w: FontWeight.w600, color: C.brand),
                        ),
                      ),
                      const SizedBox(width: 14),
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
      ],
    );
    return WizardPage(
      c: c,
      content: AdaptiveRow(
        breakpoint: 1000,
        gap: 22,
        flex: const [1, 0],
        children: [main, Fixed(420, side)],
      ),
      footer: WizardFooter(
        onBack: () => c.goTo(3),
        nextLabel: 'Continue to publish',
        onNext: () => c.goTo(5),
        secondary: c.guests.isEmpty
            ? TextButton(
                onPressed: () => c.goTo(5),
                child: Text('Skip for now', style: sans(14, color: C.muted)),
              )
            : null,
      ),
    );
  }
}
