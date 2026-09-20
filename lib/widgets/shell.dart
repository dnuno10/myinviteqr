import 'package:flutter/material.dart';
import '../data/backend.dart';
import '../data/models.dart';
import '../screens/admin.dart';
import '../theme/app_theme.dart';
import 'common.dart';

/// Signed-in user, set by the root gate.
final profileNotifier = ValueNotifier<Profile?>(null);

Future<void> signOut(BuildContext context) async {
  Navigator.of(context).popUntil((r) => r.isFirst);
  await Backend.i.signOut();
}

Future<void> showSupportDialog(BuildContext context) async {
  final subject = TextEditingController();
  final body = TextEditingController();
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: Colors.white,
      title: Text('Contact support', style: serif(20)),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Field('Subject', subject),
            const SizedBox(height: 12),
            Field('How can we help?', body, maxLines: 4),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text('Cancel', style: sans(14, color: C.body)),
        ),
        TextButton(
          onPressed: () async {
            if (subject.text.trim().isEmpty) return;
            try {
              await Backend.i.sendSupport(
                subject.text.trim(),
                body.text.trim(),
              );
              if (ctx.mounted) Navigator.pop(ctx, true);
            } catch (e) {
              if (ctx.mounted) toast(ctx, errText(e), error: true);
            }
          },
          child: Text(
            'Send',
            style: sans(14, w: FontWeight.w600, color: C.brand),
          ),
        ),
      ],
    ),
  );
  if (ok == true && context.mounted)
    toast(context, 'Thanks! Our team will get back to you by email.');
}

Future<void> showProfileDialog(BuildContext context) async {
  final name = TextEditingController(
    text: profileNotifier.value?.fullName ?? '',
  );
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: Colors.white,
      title: Text('Settings', style: serif(20)),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              profileNotifier.value?.email ?? '',
              style: sans(13, color: C.muted),
            ),
            const SizedBox(height: 14),
            Field(
              'Your name (shown to guests as the host)',
              name,
              autofocus: true,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text('Cancel', style: sans(14, color: C.body)),
        ),
        TextButton(
          onPressed: () async {
            try {
              await Backend.i.saveProfile(name.text);
              if (ctx.mounted) Navigator.pop(ctx, true);
            } catch (e) {
              if (ctx.mounted) toast(ctx, errText(e), error: true);
            }
          },
          child: Text(
            'Save',
            style: sans(14, w: FontWeight.w600, color: C.brand),
          ),
        ),
      ],
    ),
  );
  if (ok == true) profileNotifier.value = await Backend.i.myProfile();
}

class AppShell extends StatelessWidget {
  final Widget child;
  final bool admin;
  const AppShell({super.key, required this.child, this.admin = false});

  @override
  Widget build(BuildContext context) {
    final mobile = MediaQuery.sizeOf(context).width < 900;
    return Scaffold(
      backgroundColor: C.bg,
      body: SafeArea(
        child: mobile
            ? Column(
                children: [
                  _TopBar(mobile: true),
                  const Divider(height: 1, color: C.line),
                  Expanded(child: child),
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Sidebar(admin: admin),
                  const VerticalDivider(width: 1, color: C.line),
                  Expanded(
                    child: Column(
                      children: [
                        _TopBar(mobile: false),
                        const Divider(height: 1, color: C.line),
                        Expanded(child: child),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final bool mobile;
  const _TopBar({required this.mobile});

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<Profile?>(
    valueListenable: profileNotifier,
    builder: (context, p, _) {
      final name = p?.displayName ?? '';
      return Container(
        height: mobile ? 64 : 56,
        color: Colors.white,
        padding: EdgeInsets.symmetric(horizontal: mobile ? 16 : 24),
        child: Row(
          children: [
            if (mobile) Logo(height: 44, full: true),
            const Spacer(),
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => showSupportDialog(context),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  children: [
                    const Icon(
                      Icons.help_outline_rounded,
                      color: C.ink,
                      size: 18,
                    ),
                    if (!mobile) ...[
                      const SizedBox(width: 6),
                      Text(
                        'Support',
                        style: sans(14, w: FontWeight.w500, color: C.ink),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            PopupMenuButton<String>(
              tooltip: '',
              offset: const Offset(0, 44),
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: const BorderSide(color: C.line),
              ),
              onSelected: (v) {
                if (v == 'events') {
                  Navigator.of(context).popUntil((r) => r.isFirst);
                }
                if (v == 'admin') {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AdminScreen()),
                  );
                }
                if (v == 'settings') showProfileDialog(context);
                if (v == 'out') signOut(context);
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  enabled: false,
                  child: Text(p?.email ?? '', style: sans(13, color: C.muted)),
                ),
                PopupMenuItem(
                  value: 'settings',
                  child: Text('Settings', style: sans(14)),
                ),
                PopupMenuItem(
                  value: 'events',
                  child: Text('My events', style: sans(14)),
                ),
                if (p?.isAdmin ?? false)
                  PopupMenuItem(
                    value: 'admin',
                    child: Text('Admin', style: sans(14)),
                  ),
                PopupMenuItem(
                  value: 'out',
                  child: Text('Sign out', style: sans(14, color: C.red)),
                ),
              ],
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Avatar(name.isEmpty ? (p?.email ?? '?') : name, size: 32),
                    if (!mobile) ...[
                      const SizedBox(width: 10),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 160),
                        child: Text(
                          name.isEmpty ? (p?.email ?? '') : name,
                          overflow: TextOverflow.ellipsis,
                          style: sans(14, w: FontWeight.w500, color: C.ink),
                        ),
                      ),
                    ],
                    const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: C.muted,
                      size: 18,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

class _Sidebar extends StatelessWidget {
  final bool admin;
  const _Sidebar({required this.admin});

  @override
  Widget build(BuildContext context) => Container(
    width: 244,
    color: Colors.white,
    padding: const EdgeInsets.fromLTRB(12, 14, 12, 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 18),
          child: Center(child: Logo(height: 120, full: true)),
        ),
        _item(
          context,
          'Events',
          Icons.calendar_today_outlined,
          !admin,
          () => Navigator.of(context).popUntil((r) => r.isFirst),
        ),
        ValueListenableBuilder<Profile?>(
          valueListenable: profileNotifier,
          builder: (_, p, __) => (p?.isAdmin ?? false)
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10, 18, 10, 8),
                      child: Text('Manage', style: sans(13, color: C.muted)),
                    ),
                    _item(context, 'Admin', Icons.shield_outlined, admin, () {
                      if (!admin) {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const AdminScreen(),
                          ),
                        );
                      }
                    }),
                  ],
                )
              : const SizedBox.shrink(),
        ),
      ],
    ),
  );

  Widget _item(
    BuildContext context,
    String label,
    IconData icon,
    bool selected,
    VoidCallback onTap,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 2),
    child: HoverBuilder(
      onTap: onTap,
      hoverScale: 1.0,
      builder: (context, hover) => AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFFF3F1F0)
              : hover
              ? const Color(0xFFF9F7F6)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: selected ? C.brand : C.body),
            const SizedBox(width: 12),
            Text(
              label,
              style: sans(
                14,
                w: selected ? FontWeight.w600 : FontWeight.w500,
                color: C.ink,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
