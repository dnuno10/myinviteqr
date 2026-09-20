import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myinviteqr/data/backend.dart';
import 'package:myinviteqr/data/models.dart';
import 'package:myinviteqr/screens/admin.dart';
import 'package:myinviteqr/screens/auth.dart';
import 'package:myinviteqr/screens/event_detail.dart';
import 'package:myinviteqr/screens/events_list.dart';
import 'package:myinviteqr/screens/public_invite.dart';
import 'package:myinviteqr/screens/wizard/wizard.dart';
import 'package:myinviteqr/theme/app_theme.dart';
import 'package:myinviteqr/widgets/shell.dart';
import 'fake_backend.dart';

/// Test fonts are ~1.7x wider than Inter, so text is scaled down to approximate real widths.
Future<List<String>> _render(WidgetTester t, Size size, Widget page) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  final errors = <String>[];
  final original = FlutterError.onError;
  FlutterError.onError = (d) {
    final m = d.exceptionAsString();
    if (m.contains('overflowed')) {
      errors.add(
        (d.exception as FlutterError).diagnostics
            .map((n) => n.toString())
            .where((x) => x.contains('file:') || x.contains('overflowed'))
            .join(' | '),
      );
    } else {
      original?.call(d);
    }
  };
  await t.pumpWidget(
    MaterialApp(
      theme: buildTheme(),
      builder: (c, child) => MediaQuery(
        data: MediaQuery.of(
          c,
        ).copyWith(textScaler: const TextScaler.linear(.58)),
        child: child!,
      ),
      home: page,
    ),
  );
  await t.pump(const Duration(milliseconds: 300));
  await t.pump(const Duration(milliseconds: 300));
  FlutterError.onError = original;
  return errors;
}

void main() {
  setUp(() {
    Backend.i = FakeBackend();
    profileNotifier.value = const Profile(
      id: 'u1',
      email: 'daniela@example.com',
      fullName: 'Daniela Torres',
      role: 'admin',
    );
  });

  final sizes = {
    'mobile': const Size(390, 844),
    'tablet': const Size(820, 1100),
    'desktop': const Size(1440, 900),
  };
  final pages = <String, Widget Function()>{
    'auth': () => const AuthScreen(),
    'events list': () => const EventsListScreen(),
    'event detail': () => const EventDetailScreen(eventId: 'e2'),
    'wizard 1 details': () => const WizardScreen(eventId: 'e1', startStep: 1),
    'wizard 2 template': () => const WizardScreen(eventId: 'e1', startStep: 2),
    'wizard 3 editor': () => const WizardScreen(eventId: 'e1', startStep: 3),
    'wizard 4 guests': () => const WizardScreen(eventId: 'e1', startStep: 4),
    'wizard 5 publish': () => const WizardScreen(eventId: 'e1', startStep: 5),
    'admin': () => const AdminScreen(),
    'public invitation': () => const PublicInviteScreen(token: 'toke2'),
  };

  for (final p in pages.entries) {
    for (final s in sizes.entries) {
      testWidgets('${p.key} @ ${s.key} has no overflow', (t) async {
        addTearDown(t.view.reset);
        final errors = await _render(t, s.value, p.value());
        expect(t.takeException(), isNull);
        expect(
          find.text('Try again'),
          findsNothing,
          reason: '${p.key} rendered an error state',
        );
        expect(errors, isEmpty, reason: errors.join('\n'));
      });
    }
  }
}
