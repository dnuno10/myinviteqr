import 'package:flutter/material.dart';
import '../data/backend.dart';
import '../data/models.dart';
import '../theme/app_theme.dart';
import '../util/format.dart';
import '../widgets/common.dart';
import '../widgets/invitation.dart';

/// What guests see when they open the link or scan the QR. No account needed.
class PublicInviteScreen extends StatefulWidget {
  final String token;
  final String? guestToken;
  const PublicInviteScreen({super.key, required this.token, this.guestToken});
  @override
  State<PublicInviteScreen> createState() => _PublicInviteScreenState();
}

class _PublicInviteScreenState extends State<PublicInviteScreen> {
  late Future<PublicInvite?> future = Backend.i.publicInvitation(
    widget.token,
    widget.guestToken,
  );
  late String? guestToken = widget.guestToken;

  Future<void> _rsvp(PublicInvite inv) async {
    final token = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) =>
          _RsvpSheet(token: widget.token, guestToken: guestToken, invite: inv),
    );
    if (token != null && mounted) {
      setState(() => guestToken = token);
      toast(context, 'Thank you! Your response was saved.');
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<PublicInvite?>(
    future: future,
    builder: (context, snap) {
      if (snap.connectionState != ConnectionState.done)
        return const Scaffold(backgroundColor: C.bg, body: LoadingView());
      if (snap.hasError)
        return Scaffold(
          backgroundColor: C.bg,
          body: ErrorView(
            errText(snap.error!),
            onRetry: () => setState(() {
              future = Backend.i.publicInvitation(
                widget.token,
                widget.guestToken,
              );
            }),
          ),
        );
      final inv = snap.data;
      if (inv == null) {
        return Scaffold(
          backgroundColor: C.bg,
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Logo(height: 40),
                  const SizedBox(height: 20),
                  Text(
                    'This invitation does not exist',
                    textAlign: TextAlign.center,
                    style: serif(24),
                  ),
                  const SizedBox(height: 8),
                  Text('Check the link and try again.', style: sans(14)),
                ],
              ),
            ),
          ),
        );
      }
      final layers = [
        for (final b in inv.layers)
          if (b.kind != 'rsvp' || inv.rsvpOpen) b,
      ];
      final design = inv.event.pageDesign;
      return Scaffold(
        backgroundColor: design.pal.bg,
        body: SingleChildScrollView(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                children: [
                  if (inv.hasEnded)
                    Container(
                      width: double.infinity,
                      color: C.ink,
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 16,
                      ),
                      child: Text(
                        'This event has ended.',
                        textAlign: TextAlign.center,
                        style: sans(
                          14,
                          w: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  InvitationPage(
                    event: inv.event,
                    design: design,
                    layers: layers,
                    url: publicUrl(widget.token),
                    minHeight:
                        MediaQuery.sizeOf(context).height -
                        (inv.showBranding ? 60 : 0),
                    onRsvp: () => _rsvp(inv),
                    animate: true,
                  ),
                  if (inv.showBranding)
                    Container(
                      width: double.infinity,
                      color: design.pal.bg,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Made with ',
                            style: sans(
                              12,
                              color: design.pal.ink.withValues(alpha: .6),
                            ),
                          ),
                          const Logo(height: 18),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _RsvpSheet extends StatefulWidget {
  final String token;
  final String? guestToken;
  final PublicInvite invite;
  const _RsvpSheet({
    required this.token,
    this.guestToken,
    required this.invite,
  });
  @override
  State<_RsvpSheet> createState() => _RsvpSheetState();
}

class _RsvpSheetState extends State<_RsvpSheet> {
  late final name = TextEditingController(
    text: (widget.invite.guest?['name'] as String?) ?? '',
  );
  final email = TextEditingController();
  late final message = TextEditingController(
    text: (widget.invite.guest?['message'] as String?) ?? '',
  );
  late String? rsvp = (widget.invite.guest?['rsvp'] == 'pending')
      ? null
      : widget.invite.guest?['rsvp'] as String?;
  late int companions = (widget.invite.guest?['companions'] as int?) ?? 0;
  bool busy = false;
  String? error;

  bool get known => widget.invite.guest != null;

  Future<void> _send() async {
    if (rsvp == null) return setState(() => error = 'Please choose an answer.');
    if (!known && name.text.trim().isEmpty)
      return setState(() => error = 'Please enter your name.');
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final t = await Backend.i.submitRsvp(
        token: widget.token,
        guestToken: widget.guestToken,
        name: name.text,
        email: email.text,
        rsvp: rsvp!,
        companions: companions,
        message: message.text.trim().isEmpty ? null : message.text.trim(),
      );
      if (mounted) Navigator.pop(context, t);
    } catch (e) {
      if (mounted)
        setState(() {
          error = errText(e);
          busy = false;
        });
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      20,
      20,
      20,
      20 + MediaQuery.viewInsetsOf(context).bottom,
    ),
    child: SingleChildScrollView(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                known
                    ? 'Hi ${widget.invite.guest!['name']}!'
                    : 'Will you join us?',
                style: serif(22),
              ),
              const SizedBox(height: 14),
              if (!known) ...[
                Field('Your name', name),
                const SizedBox(height: 12),
                Field(
                  'Email (optional)',
                  email,
                  keyboard: TextInputType.emailAddress,
                ),
                const SizedBox(height: 14),
              ],
              Row(
                children: [
                  for (final (k, l, ic) in const [
                    ('yes', 'Yes', Icons.check_rounded),
                    ('maybe', 'Maybe', Icons.help_outline_rounded),
                    ('no', 'No', Icons.close_rounded),
                  ])
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(right: k == 'no' ? 0 : 8),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () => setState(() => rsvp = k),
                          child: Container(
                            height: 52,
                            decoration: BoxDecoration(
                              color: rsvp == k ? C.brandSoft : Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: rsvp == k ? C.brand : C.line,
                                width: rsvp == k ? 1.5 : 1,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  ic,
                                  size: 18,
                                  color: rsvp == k ? C.brand : C.ink,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  l,
                                  style: sans(
                                    14,
                                    w: rsvp == k
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                    color: rsvp == k ? C.brand : C.ink,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              if (rsvp == 'yes' || rsvp == 'maybe') ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Additional guests with you',
                        style: sans(14, color: C.ink),
                      ),
                    ),
                    IconButton(
                      onPressed: companions > 0
                          ? () => setState(() => companions--)
                          : null,
                      icon: const Icon(Icons.remove_circle_outline_rounded),
                    ),
                    SizedBox(
                      width: 24,
                      child: Text(
                        '$companions',
                        textAlign: TextAlign.center,
                        style: sans(16, w: FontWeight.w600, color: C.ink),
                      ),
                    ),
                    IconButton(
                      onPressed: companions < 10
                          ? () => setState(() => companions++)
                          : null,
                      icon: const Icon(Icons.add_circle_outline_rounded),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 10),
              Field('Message (optional)', message, maxLines: 2),
              if (error != null) ...[
                const SizedBox(height: 10),
                Text(error!, style: sans(13, color: C.red)),
              ],
              const SizedBox(height: 16),
              PrimaryButton(
                'Send response',
                busy: busy,
                height: 50,
                onTap: _send,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
