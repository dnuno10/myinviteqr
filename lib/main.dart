import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config.dart';
import 'data/backend.dart';
import 'data/models.dart';
import 'screens/auth.dart';
import 'screens/checkout_return.dart';
import 'screens/event_detail.dart';
import 'screens/wizard/wizard.dart';
import 'util/browser.dart';
import 'screens/events_list.dart';
import 'screens/public_invite.dart';
import 'theme/app_theme.dart';
import 'widgets/common.dart';
import 'widgets/shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
  Backend.i = SupabaseBackend();
  runApp(const MyInviteQrApp());
}

class MyInviteQrApp extends StatelessWidget {
  const MyInviteQrApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'myinviteqr',
    debugShowCheckedModeBanner: false,
    theme: buildTheme(),
    home: const Root(),
  );
}

/// Chooses between the public invitation, sign in, profile setup and the host app.
class Root extends StatelessWidget {
  const Root({super.key});

  @override
  Widget build(BuildContext context) {
    final invite = Uri.base.queryParameters['i'];
    if (invite != null && invite.isNotEmpty) {
      return PublicInviteScreen(
        token: invite,
        guestToken: Uri.base.queryParameters['g'],
      );
    }
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snap) {
        final session = Supabase.instance.client.auth.currentSession;
        if (session == null) {
          profileNotifier.value = null;
          return const AuthScreen();
        }
        return ProfileGate(key: ValueKey(session.user.id));
      },
    );
  }
}

class ProfileGate extends StatefulWidget {
  const ProfileGate({super.key});
  @override
  State<ProfileGate> createState() => _ProfileGateState();
}

class _ProfileGateState extends State<ProfileGate> {
  late Future<Profile?> future = _load();

  Future<Profile?> _load() async {
    final p = await Backend.i.myProfile();
    profileNotifier.value = p;
    return p;
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Profile?>(
    future: future,
    builder: (context, snap) {
      if (snap.connectionState != ConnectionState.done)
        return const Scaffold(backgroundColor: C.bg, body: LoadingView());
      if (snap.hasError || snap.data == null) {
        return Scaffold(
          backgroundColor: C.bg,
          body: ErrorView(
            snap.hasError
                ? errText(snap.error!)
                : 'We could not load your profile.',
            onRetry: () => setState(() {
              future = _load();
            }),
          ),
        );
      }
      return const _Landing();
    },
  );
}

/// The events list, or the screen Stripe sent the customer back to (?checkout=success|cancel).
class _Landing extends StatefulWidget {
  const _Landing();
  @override
  State<_Landing> createState() => _LandingState();
}

class _LandingState extends State<_Landing> {
  final q = Uri.base.queryParameters;

  @override
  Widget build(BuildContext context) => const EventsListScreen();

  @override
  void initState() {
    super.initState();
    final status = q['checkout'];
    if (status != 'success' && status != 'cancel') return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final nav = Navigator.of(context);
      final id = q['event'] ?? '';
      if (status == 'success' && (q['order'] ?? '').isNotEmpty) {
        nav.push(
          MaterialPageRoute(
            builder: (_) => CheckoutReturnScreen(
              orderId: q['order']!,
              eventId: id.isEmpty ? null : id,
              kind: q['kind'] ?? 'publish',
            ),
          ),
        );
      } else if (status == 'cancel') {
        clearQuery();
        if (id.isEmpty) return;
        toast(
          context,
          'Payment canceled. You can try again whenever you’re ready.',
        );
        nav.push(
          MaterialPageRoute(
            builder: (_) => q['kind'] == 'extension'
                ? EventDetailScreen(eventId: id)
                : WizardScreen(eventId: id, startStep: 5),
          ),
        );
      }
    });
  }
}
