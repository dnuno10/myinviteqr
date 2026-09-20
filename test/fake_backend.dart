// Test-only fixtures. This file is never imported by the app.
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:myinviteqr/data/backend.dart';
import 'package:myinviteqr/data/models.dart';

Map<String, dynamic> _layout() => {
  'height': 2.2,
  'grad': false,
  'palette': {
    'bg': '#FCEFEC',
    'ink': '#5B3A3A',
    'accent': '#E94B6F',
    'accent2': '#F2A93B',
    'soft': '#F6E3E3',
  },
  'layers': [
    {
      't': 'deco',
      'k': 'flowers',
      'x': -.05,
      'y': -.05,
      'w': .5,
      'h': .4,
      'lk': true,
    },
    {'t': 'photo', 'x': .2, 'y': .15, 'w': .6, 'h': .7, 'sh': 'arch'},
    {
      't': 'text',
      'x': .06,
      'y': .9,
      'w': .88,
      'h': .2,
      'b': 'title',
      'f': 'Great Vibes',
      's': .13,
    },
    {
      't': 'text',
      'x': .08,
      'y': 1.2,
      'w': .84,
      'h': .06,
      'b': 'datetime',
      's': .036,
    },
    {
      't': 'text',
      'x': .14,
      'y': 1.3,
      'w': .72,
      'h': .1,
      'b': 'place',
      's': .032,
    },
    {'t': 'rsvp', 'x': .2, 'y': 1.5, 'w': .6, 'h': .085},
    {'t': 'qr', 'x': .4, 'y': 1.7, 'w': .2, 'h': .2},
  ],
};

Map<String, dynamic> _plan(String c, int price, int guests, bool prem) => {
  'code': c,
  'name': c == 'premium' ? 'Premium' : 'Essential',
  'price_cents': price,
  'validity_days': 90,
  'extension_price_cents': 699,
  'extension_days': 180,
  'max_guests': guests,
  'max_co_hosts': prem ? 3 : 0,
  'max_reminders': prem ? null : 1,
  'custom_slug': prem,
  'individual_links': prem,
  'custom_questions': prem,
  'open_analytics': prem,
  'shared_album': prem,
  'gift_list': prem,
  'multiple_sub_events': prem,
  'remove_branding': prem,
  'premium_editor': prem,
};

Map<String, dynamic> _event(
  String id,
  String status, {
  String? plan,
  bool tpl = true,
}) => {
  'id': id,
  'owner_id': 'u1',
  'title': 'A very long birthday party title for Sofia and friends',
  'language': 'en',
  'status': status,
  'public_token': 'tok$id',
  'category_id': 1,
  'template_id': tpl ? 't0' : null,
  'plan': plan,
  'venue_name': 'Garden Las Flores with a long name',
  'venue_address': '123 Long Street Name, Mexico City',
  'starts_at': DateTime.now().add(const Duration(days: 30)).toIso8601String(),
  'design': _layout()..remove('layers'),
  'updated_at': DateTime.now().toIso8601String(),
  'created_at': DateTime.now().toIso8601String(),
  'published_at': status == 'draft'
      ? null
      : DateTime.now().subtract(const Duration(days: 10)).toIso8601String(),
  'expires_at': status == 'draft'
      ? null
      : DateTime.now().add(const Duration(days: 80)).toIso8601String(),
};

class FakeBackend extends Fake implements Backend {
  final categoriesList = [
    for (int i = 1; i <= 14; i++)
      Category(
        id: i,
        slug: 'c$i',
        name: i == 9 ? 'Baptism & communion' : 'Category $i',
        icon: 'cake',
      ),
  ];
  final templatesList = [
    for (int i = 0; i < 6; i++)
      Template.fromJson({
        'id': 't$i',
        'category_id': null,
        'name': 'Template $i',
        'style': 'style$i',
        'min_plan': 'essential',
        'status': 'published',
        'languages': ['en', 'es'],
        'themes': ['c1'],
        'layout': _layout(),
      }),
  ];
  final guestsList = [
    for (int i = 0; i < 6; i++)
      Guest.fromJson({
        'id': 'g$i',
        'event_id': 'e2',
        'full_name': 'Guest Number $i With Long Name',
        'rsvp': ['yes', 'no', 'pending', 'maybe', 'yes', 'pending'][i],
        'personal_token': 'p$i',
        'email': 'guest$i.with.long.email@example.com',
        'companions': i % 3,
        'open_count': i,
        'responded_at': DateTime.now()
            .subtract(Duration(hours: i))
            .toIso8601String(),
        'last_opened_at': DateTime.now()
            .subtract(Duration(hours: i))
            .toIso8601String(),
        'group_name': 'Family',
      }),
  ];

  @override
  Future<List<Category>> categories() async => categoriesList;
  @override
  Future<List<Template>> templates() async => templatesList;
  @override
  Future<List<Plan>> plans() async => [
    Plan.fromJson(_plan('essential', 999, 50, false)),
    Plan.fromJson(_plan('premium', 1999, 1000, true)),
  ];
  @override
  Future<List<ColorCombo>> palettes() async => [
    for (int i = 0; i < 12; i++)
      ColorCombo(
        id: i,
        name: 'Combo $i',
        tone: i.isEven ? 'light' : 'dark',
        pal: Pal.fromJson({
          'bg': '#FFFFFF',
          'ink': '#222222',
          'accent': '#E94B6F',
          'accent2': '#F2A93B',
          'soft': '#EEEEEE',
        }),
      ),
  ];
  @override
  Future<String> uploadImage(
    String eventId,
    Uint8List bytes,
    String filename,
  ) async => 'https://example.com/x.jpg';
  @override
  Future<List<EventModel>> myEvents() async => [
    EventModel.fromJson(_event('e1', 'draft')),
    EventModel.fromJson(_event('e2', 'published', plan: 'premium')),
  ];
  @override
  Future<EventModel> event(String id) async => EventModel.fromJson(
    id == 'e1'
        ? _event('e1', 'draft')
        : _event('e2', 'published', plan: 'premium'),
  );
  @override
  Future<List<EventBlock>> blocks(String eventId) async =>
      layersFromTemplate(templatesList.first);
  @override
  Future<List<Guest>> guests(String eventId) async => guestsList;
  @override
  Future<Map<String, GuestCounts>> guestCounts() async => {
    'e2': GuestCounts()
      ..total = 6
      ..confirmed = 2
      ..people = 4,
  };
  @override
  Future<List<DateTime>> opens(String eventId, {int days = 7}) async => [
    DateTime.now(),
    DateTime.now().subtract(const Duration(days: 2)),
  ];
  @override
  Future<Quote> quote(String plan, bool extension, String? code) async => Quote(
    plan == 'premium' ? 1999 : 999,
    0,
    plan == 'premium' ? 1999 : 999,
    null,
  );
  @override
  Future<AdminKpis> adminKpis() async => const AdminKpis({
    'sales_cents': 0,
    'sales_prev_cents': 0,
    'orders_month': 0,
    'published_month': 1,
    'published_total': 3,
    'extensions_month': 0,
    'refunds_month': 0,
    'open_tickets': 1,
    'exp_60': 0,
    'exp_30': 1,
    'exp_7': 0,
    'expired': 0,
  });
  @override
  Future<Map<String, int>> adminSales() async => {
    'Premium': 1999,
    'Essential': 999,
  };
  @override
  Future<List<Map<String, dynamic>>> adminTemplates() async => [
    {
      'id': 't0',
      'name': 'Romantic Floral',
      'style': 'romantic',
      'languages': ['en', 'es'],
      'min_plan': 'essential',
      'status': 'published',
      'event_categories': null,
    },
  ];
  @override
  Future<List<AdminTicket>> adminTickets() async => [
    AdminTicket(
      id: 'k1',
      kind: 'support',
      status: 'open',
      title: 'A ticket with a very long title that should wrap nicely',
      body: 'Body text',
      createdAt: DateTime.now(),
    ),
  ];
  @override
  Future<PublicInvite?> publicInvitation(
    String token,
    String? guestToken,
  ) async => PublicInvite(
    event: EventModel.fromJson({
      ..._event('e2', 'published', plan: 'premium'),
      'owner_id': '',
    }),
    layers: layersFromTemplate(templatesList.first),
    hasEnded: false,
    showBranding: true,
    rsvpOpen: true,
  );
}
