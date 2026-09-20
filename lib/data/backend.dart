import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'models.dart';

/// Human readable message for any backend error.
String errText(Object e) {
  if (e is PostgrestException) return e.message;
  if (e is AuthException) return e.message;
  if (e is StateError) return e.message;
  if (e is FunctionException) {
    final d = e.details;
    if (d is Map && d['error'] is String) return d['error'] as String;
    if (d is String && d.isNotEmpty) return d;
  }
  return 'Something went wrong. Please try again.';
}

abstract class Backend {
  static late Backend i;

  // auth
  Future<void> sendCode(String email);
  Future<void> verifyCode(String email, String code);
  Future<void> signOut();
  Future<Profile?> myProfile();
  Future<void> saveProfile(String fullName);

  // catalog
  Future<List<Category>> categories();
  Future<List<Template>> templates();
  Future<List<Plan>> plans();
  Future<List<ColorCombo>> palettes();
  Future<String> uploadImage(String eventId, Uint8List bytes, String filename);

  // events
  Future<List<EventModel>> myEvents();
  Future<EventModel> event(String id);
  Future<EventModel> createEvent(Map<String, dynamic> data);
  Future<EventModel> updateEvent(String id, Map<String, dynamic> patch);
  Future<void> deleteEvent(String id);
  Future<List<EventBlock>> blocks(String eventId);
  Future<void> saveBlocks(String eventId, List<EventBlock> blocks);

  // guests
  Future<List<Guest>> guests(String eventId);
  Future<Map<String, GuestCounts>> guestCounts();
  Future<ImportResult> importGuests(
    String eventId,
    List<GuestInput> rows,
    String source,
  );
  Future<void> deleteGuest(String id);
  Future<List<DateTime>> opens(String eventId, {int days = 7});

  // checkout
  Future<Quote> quote(String plan, bool extension, String? code);

  /// Starts a Stripe Checkout (kind: 'publish' or 'extension'). The amount is computed on the server.
  Future<CheckoutResult> checkout({
    required String eventId,
    required String kind,
    String? plan,
    bool extension = false,
    String? code,
  });
  Future<OrderInfo?> orderStatus(String orderId);

  // support
  Future<void> sendSupport(String title, String body);

  // public invitation
  Future<PublicInvite?> publicInvitation(String token, String? guestToken);
  Future<String> submitRsvp({
    required String token,
    String? guestToken,
    String? name,
    String? email,
    required String rsvp,
    required int companions,
    String? message,
  });

  // admin
  Future<AdminKpis> adminKpis();
  Future<Map<String, int>> adminSales();
  Future<List<Map<String, dynamic>>> adminTemplates();
  Future<void> adminSetTemplateStatus(String id, String status);
  Future<List<AdminTicket>> adminTickets();
  Future<void> adminResolveTicket(String id);
}

class SupabaseBackend implements Backend {
  SupabaseClient get c => Supabase.instance.client;
  String get uid => c.auth.currentUser!.id;

  List<Category>? _cats;
  List<Template>? _tpls;
  List<Plan>? _plans;
  List<ColorCombo>? _pals;

  @override
  Future<void> sendCode(String email) =>
      c.auth.signInWithOtp(email: email, shouldCreateUser: true);

  @override
  Future<void> verifyCode(String email, String code) async {
    await c.auth.verifyOTP(email: email, token: code, type: OtpType.email);
  }

  @override
  Future<void> signOut() async {
    _cats = _tpls = _plans = null;
    await c.auth.signOut();
  }

  @override
  Future<Profile?> myProfile() async {
    var r = await c.from('profiles').select().eq('id', uid).maybeSingle();
    if (r == null) {
      // The signup trigger normally creates it; this covers accounts created before it existed.
      await c.from('profiles').insert({
        'id': uid,
        'email': c.auth.currentUser!.email ?? '',
      });
      r = await c.from('profiles').select().eq('id', uid).maybeSingle();
    }
    return r == null ? null : Profile.fromJson(r);
  }

  @override
  Future<void> saveProfile(String fullName) =>
      c.from('profiles').update({'full_name': fullName.trim()}).eq('id', uid);

  @override
  Future<List<Category>> categories() async => _cats ??= [
    for (final r
        in await c
            .from('event_categories')
            .select()
            .eq('is_active', true)
            .order('sort_order'))
      Category.fromJson(r),
  ];

  @override
  Future<List<Template>> templates() async => _tpls ??= [
    for (final r
        in await c
            .from('templates')
            .select()
            .eq('status', 'published')
            .order('name'))
      Template.fromJson(r),
  ];

  @override
  Future<List<Plan>> plans() async => _plans ??= [
    for (final r in await c.from('plans').select().order('price_cents'))
      Plan.fromJson(r),
  ];

  @override
  Future<List<EventModel>> myEvents() async => [
    for (final r
        in await c
            .from('events')
            .select()
            .eq('owner_id', uid)
            .order('updated_at', ascending: false))
      EventModel.fromJson(r),
  ];

  @override
  Future<EventModel> event(String id) async => EventModel.fromJson(
    await c.from('events').select().eq('id', id).single(),
  );

  @override
  Future<EventModel> createEvent(Map<String, dynamic> data) async =>
      EventModel.fromJson(
        await c
            .from('events')
            .insert({...data, 'owner_id': uid})
            .select()
            .single(),
      );

  @override
  Future<EventModel> updateEvent(String id, Map<String, dynamic> patch) async =>
      EventModel.fromJson(
        await c.from('events').update(patch).eq('id', id).select().single(),
      );

  @override
  Future<void> deleteEvent(String id) => c.from('events').delete().eq('id', id);

  @override
  Future<List<EventBlock>> blocks(String eventId) async => [
    for (final r
        in await c
            .from('event_blocks')
            .select()
            .eq('event_id', eventId)
            .order('position'))
      EventBlock.fromJson(r),
  ];

  @override
  Future<void> saveBlocks(String eventId, List<EventBlock> blocks) async {
    for (final (i, b) in blocks.indexed) {
      b.id ??= newLayerId();
      b.position = i;
    }
    if (blocks.isNotEmpty)
      await c.from('event_blocks').upsert([
        for (final b in blocks) b.toRow(eventId),
      ], onConflict: 'id');
    final keep = blocks.map((b) => b.id).join(',');
    final q = c.from('event_blocks').delete().eq('event_id', eventId);
    if (blocks.isEmpty) {
      await q;
    } else {
      await q.not('id', 'in', '($keep)');
    }
  }

  @override
  Future<List<ColorCombo>> palettes() async => _pals ??= [
    for (final r in await c.from('color_palettes').select().order('id'))
      ColorCombo.fromJson(r),
  ];

  @override
  Future<String> uploadImage(
    String eventId,
    Uint8List bytes,
    String filename,
  ) async {
    final ext = filename.contains('.')
        ? filename.split('.').last.toLowerCase()
        : 'jpg';
    const types = {
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'png': 'image/png',
      'webp': 'image/webp',
      'gif': 'image/gif',
    };
    final type = types[ext];
    if (type == null)
      throw StateError('Please choose a JPG, PNG, WebP or GIF image.');
    if (bytes.length > 5 * 1024 * 1024)
      throw StateError('That image is larger than 5 MB.');
    final path = '$uid/$eventId/${DateTime.now().millisecondsSinceEpoch}.$ext';
    await c.storage
        .from('invitation-media')
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: type, upsert: false),
        );
    return c.storage.from('invitation-media').getPublicUrl(path);
  }

  @override
  Future<List<Guest>> guests(String eventId) async => [
    for (final r
        in await c
            .from('guests')
            .select()
            .eq('event_id', eventId)
            .order('created_at'))
      Guest.fromJson(r),
  ];

  @override
  Future<Map<String, GuestCounts>> guestCounts() async {
    final out = <String, GuestCounts>{};
    for (final r
        in await c.from('guests').select('event_id, rsvp, companions')) {
      final g = out.putIfAbsent(r['event_id'], GuestCounts.new);
      g.total++;
      if (r['rsvp'] == 'yes') {
        g.confirmed++;
        g.people += 1 + ((r['companions'] as num?)?.toInt() ?? 0);
      }
    }
    return out;
  }

  @override
  Future<ImportResult> importGuests(
    String eventId,
    List<GuestInput> rows,
    String source,
  ) async {
    final r =
        await c.rpc(
              'import_guests',
              params: {
                'p_event': eventId,
                'p_rows': [for (final g in rows) g.toJson(source)],
              },
            )
            as Map;
    return ImportResult(r['inserted'], r['duplicates'], r['over_limit']);
  }

  @override
  Future<void> deleteGuest(String id) => c.from('guests').delete().eq('id', id);

  @override
  Future<List<DateTime>> opens(String eventId, {int days = 7}) async {
    final since = DateTime.now()
        .subtract(Duration(days: days))
        .toUtc()
        .toIso8601String();
    final rows = await c
        .from('invitation_opens')
        .select('opened_at')
        .eq('event_id', eventId)
        .gte('opened_at', since);
    return [for (final r in rows) DateTime.parse(r['opened_at'])];
  }

  @override
  Future<Quote> quote(String plan, bool extension, String? code) async =>
      Quote.fromJson(
        Map<String, dynamic>.from(
          await c.rpc(
            'quote_order',
            params: {'p_plan': plan, 'p_extension': extension, 'p_code': code},
          ),
        ),
      );

  @override
  Future<CheckoutResult> checkout({
    required String eventId,
    required String kind,
    String? plan,
    bool extension = false,
    String? code,
  }) async {
    String? origin;
    try {
      origin = Uri.base.origin;
    } catch (_) {}
    final r = await c.functions.invoke(
      'create-checkout',
      body: {
        'event_id': eventId,
        'kind': kind,
        'plan': plan,
        'extension': extension,
        'code': code,
        'origin': origin,
      },
    );
    final d = Map<String, dynamic>.from(r.data as Map);
    if (d['error'] != null) throw StateError(d['error'].toString());
    return CheckoutResult(
      url: d['url'] as String?,
      free: d['free'] == true,
      orderId: d['order_id'] as String,
    );
  }

  @override
  Future<OrderInfo?> orderStatus(String orderId) async {
    final r = await c
        .from('orders')
        .select('status, kind, event_id, stripe_error')
        .eq('id', orderId)
        .maybeSingle();
    return r == null
        ? null
        : OrderInfo(
            status: r['status'],
            kind: r['kind'],
            eventId: r['event_id'],
            error: r['stripe_error'],
          );
  }

  @override
  Future<void> sendSupport(String title, String body) =>
      c.from('support_tickets').insert({
        'title': title,
        'body': body,
        'kind': 'support',
        'user_id': uid,
      });

  @override
  Future<PublicInvite?> publicInvitation(
    String token,
    String? guestToken,
  ) async {
    final r = await c.rpc(
      'get_public_invitation',
      params: {'p_token': token, 'p_guest': guestToken},
    );
    return r == null
        ? null
        : PublicInvite.fromJson(Map<String, dynamic>.from(r));
  }

  @override
  Future<String> submitRsvp({
    required String token,
    String? guestToken,
    String? name,
    String? email,
    required String rsvp,
    required int companions,
    String? message,
  }) async {
    final r =
        await c.rpc(
              'submit_rsvp',
              params: {
                'p_token': token,
                'p_guest': guestToken,
                'p_name': name,
                'p_email': email,
                'p_rsvp': rsvp,
                'p_companions': companions,
                'p_message': message,
              },
            )
            as Map;
    return r['guest_token'] as String;
  }

  @override
  Future<AdminKpis> adminKpis() async =>
      AdminKpis(Map<String, dynamic>.from(await c.rpc('admin_kpis')));

  @override
  Future<Map<String, int>> adminSales() async {
    final rows = await c.rpc('admin_sales_by_bucket') as List;
    return {
      for (final r in rows)
        r['bucket'] as String: (r['revenue_cents'] as num).toInt(),
    };
  }

  @override
  Future<List<Map<String, dynamic>>> adminTemplates() async =>
      List<Map<String, dynamic>>.from(
        await c
            .from('templates')
            .select('*, event_categories(name)')
            .order('updated_at', ascending: false)
            .limit(100),
      );

  @override
  Future<void> adminSetTemplateStatus(String id, String status) =>
      c.from('templates').update({'status': status}).eq('id', id);

  @override
  Future<List<AdminTicket>> adminTickets() async => [
    for (final r
        in await c
            .from('support_tickets')
            .select()
            .inFilter('status', ['open', 'in_progress'])
            .order('created_at', ascending: false)
            .limit(50))
      AdminTicket.fromJson(r),
  ];

  @override
  Future<void> adminResolveTicket(String id) => c
      .from('support_tickets')
      .update({
        'status': 'resolved',
        'resolved_at': DateTime.now().toUtc().toIso8601String(),
      })
      .eq('id', id);
}
