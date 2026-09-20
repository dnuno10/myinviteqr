import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/responsive.dart';
import 'wizard.dart';

const _titles = {
  1: (
    'Create your event',
    'Start with the basics so we can recommend the best invitation design.',
  ),
  2: (
    'Choose a template',
    'Pick a design that fits your event and personalize it in the next step.',
  ),
  3: (
    'Edit your invitation',
    'Customize the template while keeping the design elegant and balanced.',
  ),
  4: (
    'Add your guests',
    'Import your list, add guests manually, or skip this step and do it later.',
  ),
  5: (
    'Publish your event',
    'Choose your plan, review your order, and activate your invitation.',
  ),
};

/// Common frame of the five steps: title, stepper, scrollable content and a pinned action bar.
class WizardPage extends StatelessWidget {
  final WizardController c;
  final Widget content;
  final Widget footer;
  const WizardPage({
    super.key,
    required this.c,
    required this.content,
    required this.footer,
  });

  @override
  Widget build(BuildContext context) {
    final t = _titles[c.step]!;
    final pad = pagePad(context);
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(pad, 28, pad, 28),
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1480),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    PageTitle(t.$1, t.$2),
                    if (!c.published) ...[
                      const SizedBox(height: 22),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 760),
                        child: StepperBar(
                          current: c.step,
                          onTap: (s) => c.goTo(s),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    content,
                  ],
                ),
              ),
            ),
          ),
        ),
        const Divider(height: 1, color: C.line),
        Container(
          color: Colors.white,
          padding: EdgeInsets.symmetric(horizontal: pad, vertical: 14),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1480),
              child: footer,
            ),
          ),
        ),
      ],
    );
  }
}

/// Back on the left, optional secondary action and the main action on the right.
class WizardFooter extends StatelessWidget {
  final VoidCallback? onBack;
  final String nextLabel;
  final VoidCallback? onNext;
  final bool busy;
  final Widget? secondary;
  const WizardFooter({
    super.key,
    this.onBack,
    required this.nextLabel,
    this.onNext,
    this.busy = false,
    this.secondary,
  });

  @override
  Widget build(BuildContext context) {
    final mobile = isMobile(context);
    return Row(
      children: [
        OutlineBtn(
          mobile ? '' : 'Back',
          icon: Icons.arrow_back_rounded,
          height: 44,
          onTap: onBack,
        ),
        Expanded(
          child: Align(
            alignment: Alignment.centerRight,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (secondary != null && !mobile) ...[
                  secondary!,
                  const SizedBox(width: 16),
                ],
                Flexible(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: mobile ? 260 : 300),
                    child: SizedBox(
                      width: mobile ? null : 300,
                      child: PrimaryButton(
                        nextLabel,
                        icon: Icons.arrow_forward_rounded,
                        height: 44,
                        busy: busy,
                        onTap: onNext,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Card with a serif heading and a one-line subtitle, used for every side panel.
class PanelCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget child;
  final EdgeInsets? padding;
  const PanelCard({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    required this.child,
    this.padding,
  });
  @override
  Widget build(BuildContext context) => AppCard(
    padding: padding ?? EdgeInsets.all(isMobile(context) ? 16 : 22),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(title, style: serif(20))),
            if (trailing != null) trailing!,
          ],
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(subtitle!, style: sans(13.5, color: C.muted)),
        ],
        const SizedBox(height: 16),
        child,
      ],
    ),
  );
}

/// Label / value rows separated by thin lines (Live summary, Your event, Order summary).
class SummaryList extends StatelessWidget {
  final List<(IconData, String, String, String?)> rows;
  const SummaryList(this.rows, {super.key});
  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (final (i, r) in rows.indexed) ...[
        if (i > 0) const Divider(height: 1, color: C.line),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 11),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(r.$1, size: 18, color: C.body),
              const SizedBox(width: 12),
              SizedBox(
                width: 92,
                child: Text(r.$2, style: sans(13.5, color: C.muted)),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.$3.isEmpty ? '—' : r.$3,
                      style: sans(13.5, w: FontWeight.w600, color: C.ink),
                    ),
                    if (r.$4 != null)
                      Text(r.$4!, style: sans(12.5, color: C.muted)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    ],
  );
}
