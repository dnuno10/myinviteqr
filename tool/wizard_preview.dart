// Dev tool: runs the real wizard against local generated data (no network, no Supabase).
// flutter build web -t tool/wizard_preview.dart   (then open ?step=3)
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:myinviteqr/data/backend.dart';
import 'package:myinviteqr/data/models.dart';
import 'package:myinviteqr/screens/wizard/wizard.dart';
import 'package:myinviteqr/theme/app_theme.dart';
import 'package:myinviteqr/widgets/shell.dart';
import 'templates_data.dart';

class _Local implements Backend {
  EventModel ev = EventModel.fromJson({
    'id': 'e1',
    'owner_id': 'u',
    'title': 'Sofia & Daniel',
    'language': 'en',
    'status': 'draft',
    'public_token': 'abc123',
    'category_id': 3,
    'template_id': Uri.base.queryParameters['tpl'] == null
        ? null
        : 'p${Uri.base.queryParameters['tpl']}',
    'venue_name': 'Garden Estate',
    'venue_address': '123 Rose Avenue',
    'starts_at': DateTime(2026, 6, 14, 18).toIso8601String(),
    'design': {},
  });
  List<EventBlock> layers = [];
  late final tpls = [
    for (final (i, d)
        in (jsonDecode(kTemplatesJson) as List)
            .cast<Map<String, dynamic>>()
            .indexed)
      Template.fromJson({
        'id': 'p$i',
        'name': d['name'],
        'style': d['style'],
        'min_plan': 'essential',
        'status': 'published',
        'category_id': null,
        'languages': d['languages'],
        'themes': d['themes'],
        'layout': d['layout'],
      }),
  ];
  @override
  Future<List<Category>> categories() async => [
    for (final (i, n) in [
      'Birthday',
      'Baby shower',
      'Wedding',
      'Anniversary',
    ].indexed)
      Category(
        id: i + 1,
        slug: ['birthday', 'baby_shower', 'wedding', 'anniversary'][i],
        name: n,
        icon: 'cake',
      ),
  ];
  @override
  Future<List<Template>> templates() async => tpls;
  @override
  Future<List<Plan>> plans() async => [
    for (final (c, p, g, pr) in [
      ('essential', 999, 50, false),
      ('premium', 1999, 1000, true),
    ])
      Plan.fromJson({
        'code': c,
        'name': pr ? 'Premium' : 'Essential',
        'price_cents': p,
        'validity_days': 90,
        'extension_price_cents': 499,
        'extension_days': 90,
        'max_guests': g,
        'max_co_hosts': pr ? 3 : 0,
        'max_reminders': pr ? null : 1,
        'custom_slug': pr,
        'individual_links': pr,
        'custom_questions': pr,
        'open_analytics': pr,
        'shared_album': pr,
        'gift_list': pr,
        'multiple_sub_events': pr,
        'remove_branding': pr,
        'premium_editor': pr,
      }),
  ];
  @override
  Future<List<ColorCombo>> palettes() async => [
    for (final (i, p) in (jsonDecode(kPalettesJson) as List).indexed)
      ColorCombo.fromJson({
        'id': i,
        'name': p['name'],
        'tone': p['tone'],
        'colors': p['colors'],
      }),
  ];
  @override
  Future<EventModel> event(String id) async => ev;
  @override
  Future<EventModel> updateEvent(String id, Map<String, dynamic> patch) async {
    final j = {
      'id': ev.id,
      'owner_id': 'u',
      'title': ev.title,
      'language': 'en',
      'status': 'draft',
      'public_token': 'abc123',
      'category_id': ev.categoryId,
      'template_id': ev.templateId,
      'venue_name': ev.venueName,
      'venue_address': ev.venueAddress,
      'starts_at': ev.startsAt?.toIso8601String(),
      'design': ev.design,
      ...patch,
    };
    return ev = EventModel.fromJson(j);
  }

  @override
  Future<List<EventBlock>> blocks(String eventId) async => layers;
  @override
  Future<void> saveBlocks(String eventId, List<EventBlock> blocks) async =>
      layers = [for (final b in blocks) b.copy()];
  @override
  Future<List<Guest>> guests(String eventId) async => [];
  @override
  Future<Quote> quote(String plan, bool extension, String? code) async => Quote(
    plan == 'premium' ? 1999 : 999,
    0,
    plan == 'premium' ? 1999 : 999,
    null,
  );
  @override
  Future<String> uploadImage(
    String eventId,
    Uint8List bytes,
    String filename,
  ) async => '';
  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('${i.memberName}');
}

void main() {
  final b = _Local();
  Backend.i = b;
  profileNotifier.value = const Profile(
    id: 'u',
    email: 'daniela@example.com',
    fullName: 'Daniela',
    role: 'host',
  );
  final q = Uri.base.queryParameters;
  final tplIdx = int.tryParse(q['tpl'] ?? '');
  if (tplIdx != null) {
    final t = b.tpls[tplIdx];
    b.layers = layersFromTemplate(t);
    b.ev = EventModel.fromJson({
      'id': 'e1',
      'owner_id': 'u',
      'title': 'Sofia & Daniel',
      'language': 'en',
      'status': 'draft',
      'public_token': 'abc123',
      'category_id': 3,
      'template_id': t.id,
      'venue_name': 'Garden Estate',
      'venue_address': '123 Rose Avenue',
      'starts_at': DateTime(2026, 6, 14, 18).toIso8601String(),
      'design': t.layout.design.toJson(),
    });
  }
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: WizardScreen(
        eventId: 'e1',
        startStep: int.tryParse(q['step'] ?? '') ?? 3,
      ),
    ),
  );
}
