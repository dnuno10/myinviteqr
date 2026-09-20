import 'package:flutter/material.dart';
import '../data/models.dart';
import '../theme/app_theme.dart';
import 'common.dart';
import 'invitation.dart';
import 'responsive.dart';

const _steps = [
  (
    Icons.add_box_outlined,
    'Create event',
    'Choose the type of event and give it a name.',
  ),
  (
    Icons.dashboard_outlined,
    'Choose template',
    'Pick a design that matches your style.',
  ),
  (
    Icons.edit_outlined,
    'Add details',
    'Include date, location, message and more.',
  ),
  (
    Icons.send_outlined,
    'Share with guests',
    'Send your invitation and start receiving RSVPs.',
  ),
];

/// "Create your first event": steps on the left, the preview artwork on the right.
class HomeHero extends StatelessWidget {
  final VoidCallback onCreate;
  const HomeHero({super.key, required this.onCreate});

  Widget _left() => Padding(
    padding: const EdgeInsets.all(8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'GET STARTED IN MINUTES',
          style: sans(
            12,
            w: FontWeight.w600,
            color: C.brand,
          ).copyWith(letterSpacing: .6),
        ),
        const SizedBox(height: 14),
        Text('Create your first event', style: serif(30, h: 1.15)),
        const SizedBox(height: 10),
        Text(
          'Design a beautiful invitation, manage your guests and make your event unforgettable — all in one place.',
          style: sans(15, h: 1.4, color: C.body),
        ),
        const SizedBox(height: 22),
        for (int i = 0; i < _steps.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(
              children: [
                Icon(_steps[i].$1, size: 26, color: C.ink),
                const SizedBox(width: 16),
                Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: C.brandSoft,
                  ),
                  child: Text(
                    '${i + 1}',
                    style: sans(13, w: FontWeight.w600, color: C.brand),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_steps[i].$2, style: serif(15.5)),
                      const SizedBox(height: 2),
                      Text(_steps[i].$3, style: sans(13, color: C.muted)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 8),
        PrimaryButton(
          'Create your first event',
          icon: Icons.add_rounded,
          height: 46,
          onTap: onCreate,
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => AppCard(
    padding: EdgeInsets.all(isMobile(context) ? 16 : 14),
    child: LayoutBuilder(
      builder: (context, c) {
        final art = ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.asset('assets/home-photo.png', fit: BoxFit.cover),
        );
        if (c.maxWidth < 900) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [_left(), const SizedBox(height: 16), art],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              flex: 5,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 24, 8),
                child: _left(),
              ),
            ),
            Expanded(flex: 7, child: art),
          ],
        );
      },
    ),
  );
}

class QuickAction {
  final IconData icon;
  final String title, subtitle;
  final VoidCallback onTap;
  const QuickAction(this.icon, this.title, this.subtitle, this.onTap);
}

class QuickActions extends StatelessWidget {
  final List<QuickAction> actions;
  const QuickActions(this.actions, {super.key});
  @override
  Widget build(BuildContext context) => AutoGrid(
    minTile: 250,
    gap: 14,
    children: [
      for (final a in actions)
        HoverBuilder(
          hoverScale: 1.0,
          onTap: a.onTap,
          builder: (context, hover) => AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            height: 88,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            decoration: BoxDecoration(
              color: hover ? const Color(0xFFFCFAF9) : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: hover ? C.brandBorder : C.line),
            ),
            child: Row(
              children: [
                Icon(a.icon, size: 28, color: C.brand),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(a.title, style: serif(15.5)),
                      const SizedBox(height: 2),
                      Text(
                        a.subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: sans(12.5, color: C.muted),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, size: 20, color: C.ink),
              ],
            ),
          ),
        ),
    ],
  );
}

/// Templates from the catalogue (real data), shown as compact cards.
class PopularTemplates extends StatelessWidget {
  final List<Template> templates;
  final void Function(Template) onOpen;
  final VoidCallback onViewAll;
  const PopularTemplates({
    super.key,
    required this.templates,
    required this.onOpen,
    required this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    if (templates.isEmpty) return const SizedBox.shrink();
    final ev = previewEvent(title: 'Your event');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text('Popular templates', style: serif(22))),
            HoverBuilder(
              hoverScale: 1.0,
              onTap: onViewAll,
              builder: (context, hover) => Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'View all templates',
                    style: sans(13.5, w: FontWeight.w500, color: C.brand),
                  ),
                  const SizedBox(width: 6),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    size: 16,
                    color: C.brand,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        AutoGrid(
          minTile: 280,
          gap: 14,
          children: [
            for (final t in templates.take(4))
              HoverBuilder(
                hoverScale: 1.0,
                onTap: () => onOpen(t),
                builder: (context, hover) => AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  height: 108,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: hover ? C.brandBorder : C.line),
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(
                          width: 86,
                          height: 86,
                          child: TemplateThumb(template: t, event: ev),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              t.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: serif(16),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              t.style.isEmpty
                                  ? ''
                                  : t.style[0].toUpperCase() +
                                        t.style.substring(1),
                              style: sans(12.5, color: C.muted),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right_rounded,
                        size: 20,
                        color: C.ink,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class HelpBanner extends StatelessWidget {
  final VoidCallback onContact;
  const HelpBanner({super.key, required this.onContact});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    decoration: BoxDecoration(
      color: C.brandSoft,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Wrap(
      spacing: 16,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      alignment: WrapAlignment.spaceBetween,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.headset_mic_outlined, size: 30, color: C.brand),
              const SizedBox(width: 16),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Need help getting started?', style: serif(16)),
                    const SizedBox(height: 2),
                    Text(
                      'Our team is here to help you create amazing events.',
                      style: sans(13, color: C.body),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        OutlineBtn('Contact support', onTap: onContact),
      ],
    ),
  );
}
