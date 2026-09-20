import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myinviteqr/data/backend.dart';
import 'package:myinviteqr/data/models.dart';
import 'package:myinviteqr/screens/wizard/wizard.dart';
import 'package:myinviteqr/theme/app_theme.dart';
import 'package:myinviteqr/widgets/invitation.dart';
import 'package:myinviteqr/widgets/shell.dart';
import 'fake_backend.dart';

void main() {
  setUp(() {
    Backend.i = FakeBackend();
    profileNotifier.value = const Profile(
      id: 'u1',
      email: 'a@b.c',
      fullName: 'Daniela',
      role: 'host',
    );
  });

  testWidgets('editor: select, drag, undo, add, delete', (t) async {
    t.view.physicalSize = const Size(1440, 1000);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final errors = <String>[];
    final original = FlutterError.onError;
    FlutterError.onError = (d) {
      if (!d.exceptionAsString().contains('overflowed'))
        errors.add(d.exceptionAsString());
    };

    try {
      await t.pumpWidget(
        MaterialApp(
          theme: buildTheme(),
          builder: (c, child) => MediaQuery(
            data: MediaQuery.of(
              c,
            ).copyWith(textScaler: const TextScaler.linear(.58)),
            child: child!,
          ),
          home: const WizardScreen(eventId: 'e1', startStep: 3),
        ),
      );
      await t.pump(const Duration(milliseconds: 400));
      await t.pump(const Duration(milliseconds: 400));

      // ignore: avoid_print
      print(
        'TEXTS: ${t.widgetList<Text>(find.byType(Text)).map((x) => x.data).take(12).toList()}',
      );
      final page = find.byType(InvitationPage);
      expect(page, findsOneWidget);
      final origin = t.getTopLeft(page);
      final w = t.getSize(page).width;
      Offset at(double x, double y) => origin + Offset(x * w, y * w);

      // select the title text (x .06..94, y .9..1.1)
      await t.tapAt(at(.5, 1.0));
      await t.pump();
      expect(
        find.text('Duplicate'),
        findsOneWidget,
        reason: 'element panel opens after selecting',
      );
      expect(find.text('Undo'), findsOneWidget);

      // drag it
      await t.dragFrom(at(.5, 1.0), const Offset(40, 30));
      await t.pump(const Duration(milliseconds: 100));

      // add a text layer, then delete it
      await t.tap(find.text('Text').first);
      await t.pump();
      expect(find.text('Delete'), findsOneWidget);
      await t.tap(find.text('Delete'));
      await t.pump();
      expect(find.text('Duplicate'), findsNothing);

      // page tab shows the colour combinations
      await t.tap(find.text('Page'));
      await t.pump();
      expect(find.textContaining('combinations'), findsOneWidget);

      await t.pump(const Duration(seconds: 2)); // let the debounced save run
    } finally {
      FlutterError.onError = original;
    }
    expect(errors, isEmpty, reason: errors.join('\n'));
  });
}
