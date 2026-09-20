import 'dart:math';
import 'package:flutter/material.dart';
import '../util/format.dart';

DateTime? _dt(dynamic v) => v == null ? null : DateTime.parse(v as String);

class Profile {
  final String id, email;
  final String? fullName;
  final String role;
  const Profile({
    required this.id,
    required this.email,
    this.fullName,
    required this.role,
  });
  factory Profile.fromJson(Map<String, dynamic> j) => Profile(
    id: j['id'],
    email: j['email'] ?? '',
    fullName: j['full_name'],
    role: j['role'] ?? 'host',
  );
  bool get isAdmin => role == 'admin';
  bool get isComplete => (fullName ?? '').trim().isNotEmpty;
  String get displayName =>
      isComplete ? fullName!.trim() : email.split('@').first;
  String get firstName => displayName.split(' ').first;
}

class Category {
  final int id;
  final String slug, name, icon;
  const Category({
    required this.id,
    required this.slug,
    required this.name,
    required this.icon,
  });
  factory Category.fromJson(Map<String, dynamic> j) => Category(
    id: j['id'],
    slug: j['slug'],
    name: j['name'],
    icon: j['icon'] ?? 'more',
  );
}

class Plan {
  final String code, name;
  final int priceCents,
      validityDays,
      extensionPriceCents,
      extensionDays,
      maxGuests,
      maxCoHosts;
  final int? maxReminders;
  final bool customSlug,
      individualLinks,
      customQuestions,
      openAnalytics,
      sharedAlbum,
      giftList,
      multipleSubEvents,
      removeBranding,
      premiumEditor;
  const Plan({
    required this.code,
    required this.name,
    required this.priceCents,
    required this.validityDays,
    required this.extensionPriceCents,
    required this.extensionDays,
    required this.maxGuests,
    required this.maxCoHosts,
    this.maxReminders,
    required this.customSlug,
    required this.individualLinks,
    required this.customQuestions,
    required this.openAnalytics,
    required this.sharedAlbum,
    required this.giftList,
    required this.multipleSubEvents,
    required this.removeBranding,
    required this.premiumEditor,
  });
  factory Plan.fromJson(Map<String, dynamic> j) => Plan(
    code: j['code'],
    name: j['name'],
    priceCents: j['price_cents'],
    validityDays: j['validity_days'],
    extensionPriceCents: j['extension_price_cents'],
    extensionDays: j['extension_days'],
    maxGuests: j['max_guests'],
    maxCoHosts: j['max_co_hosts'],
    maxReminders: j['max_reminders'],
    customSlug: j['custom_slug'],
    individualLinks: j['individual_links'],
    customQuestions: j['custom_questions'],
    openAnalytics: j['open_analytics'],
    sharedAlbum: j['shared_album'],
    giftList: j['gift_list'],
    multipleSubEvents: j['multiple_sub_events'],
    removeBranding: j['remove_branding'],
    premiumEditor: j['premium_editor'],
  );
  bool get isPremium => code == 'premium';
}

/// Colour roles used by every layer. A palette maps each role to a colour.
class Pal {
  final Color bg, ink, accent, accent2, soft;
  const Pal({
    required this.bg,
    required this.ink,
    required this.accent,
    required this.accent2,
    required this.soft,
  });
  static const fallback = Pal(
    bg: Color(0xFFFAF6F0),
    ink: Color(0xFF2B2D42),
    accent: Color(0xFFE94B6F),
    accent2: Color(0xFFF2A93B),
    soft: Color(0xFFF6E3E3),
  );
  factory Pal.fromJson(Map? j, [Pal base = fallback]) => j == null
      ? base
      : Pal(
          bg: hexColor(j['bg'] as String?, base.bg),
          ink: hexColor(j['ink'] as String?, base.ink),
          accent: hexColor(j['accent'] as String?, base.accent),
          accent2: hexColor(j['accent2'] as String?, base.accent2),
          soft: hexColor(j['soft'] as String?, base.soft),
        );
  Map<String, String> toJson() => {
    'bg': colorHex(bg),
    'ink': colorHex(ink),
    'accent': colorHex(accent),
    'accent2': colorHex(accent2),
    'soft': colorHex(soft),
  };
  Color role(String? r, [Color? fallbackColor]) {
    switch (r) {
      case 'bg':
        return bg;
      case 'ink':
        return ink;
      case 'accent':
        return accent;
      case 'accent2':
        return accent2;
      case 'soft':
        return soft;
      case 'white':
        return Colors.white;
      case 'black':
        return Colors.black;
      default:
        return hexColor(r, fallbackColor ?? ink);
    }
  }

  bool get isDark => bg.computeLuminance() < .3;
  @override
  bool operator ==(Object o) =>
      o is Pal &&
      o.bg == bg &&
      o.ink == ink &&
      o.accent == accent &&
      o.accent2 == accent2 &&
      o.soft == soft;
  @override
  int get hashCode => Object.hash(bg, ink, accent, accent2, soft);
}

class ColorCombo {
  final int id;
  final String name, tone;
  final Pal pal;
  const ColorCombo({
    required this.id,
    required this.name,
    required this.tone,
    required this.pal,
  });
  factory ColorCombo.fromJson(Map<String, dynamic> j) => ColorCombo(
    id: j['id'],
    name: j['name'],
    tone: j['tone'] ?? 'light',
    pal: Pal.fromJson(j['colors'] as Map),
  );
}

/// Page design stored on the event: palette + page height (in page widths) + optional gradient.
String motionForStyle(String? style) => switch (style) {
  'playful' || 'kids' => 'bounce',
  'modern' || 'minimalist' || 'editorial' => 'slide',
  'botanical' || 'boho' || 'tropical' || 'magical' => 'float',
  _ => 'soft',
};

class PageDesign {
  final Pal pal;
  final double height;
  final bool gradient;

  /// Animation family for the public page: soft, slide, bounce or float.
  final String motion;
  const PageDesign({
    required this.pal,
    required this.height,
    required this.gradient,
    this.motion = 'soft',
  });
  factory PageDesign.fromJson(Map<String, dynamic>? d, [PageDesign? base]) =>
      PageDesign(
        pal: Pal.fromJson(d?['palette'] as Map?, base?.pal ?? Pal.fallback),
        height: ((d?['height'] as num?) ?? base?.height ?? 2.4)
            .toDouble()
            .clamp(1.2, 6.0),
        gradient: (d?['grad'] as bool?) ?? base?.gradient ?? false,
        motion: (d?['motion'] as String?) ?? base?.motion ?? 'soft',
      );
  Map<String, dynamic> toJson() => {
    'palette': pal.toJson(),
    'height': double.parse(height.toStringAsFixed(3)),
    'grad': gradient,
    'motion': motion,
  };
}

class TemplateLayout {
  final PageDesign design;
  final List<Map<String, dynamic>> layers;
  const TemplateLayout({required this.design, required this.layers});
  factory TemplateLayout.fromJson(Map<String, dynamic>? j, [String? style]) {
    final d = PageDesign.fromJson({
      'palette': j?['palette'],
      'height': j?['height'],
      'grad': j?['grad'],
      'motion': motionForStyle(style),
    });
    return TemplateLayout(
      design: d,
      layers: [
        for (final l in (j?['layers'] as List? ?? const []))
          Map<String, dynamic>.from(l as Map),
      ],
    );
  }
  Pal get pal => design.pal;
}

class Template {
  final String id, name, style, minPlan, status;
  final int? categoryId;
  final List<String> languages, themes;
  final TemplateLayout layout;
  const Template({
    required this.id,
    required this.name,
    required this.style,
    required this.minPlan,
    required this.status,
    this.categoryId,
    required this.languages,
    required this.themes,
    required this.layout,
  });
  factory Template.fromJson(Map<String, dynamic> j) => Template(
    id: j['id'],
    name: j['name'],
    style: j['style'],
    minPlan: j['min_plan'],
    status: j['status'],
    categoryId: j['category_id'],
    languages: List<String>.from(j['languages'] ?? const ['en']),
    themes: List<String>.from(j['themes'] ?? const []),
    layout: TemplateLayout.fromJson(
      j['layout'] as Map<String, dynamic>?,
      j['style'] as String?,
    ),
  );
  bool get isPremium => minPlan == 'premium';

  /// Small swatch row shown on template cards.
  List<Color> get swatches => [
    layout.pal.bg,
    layout.pal.accent,
    layout.pal.accent2,
    layout.pal.ink,
  ];
}

class EventModel {
  final String id, ownerId, title, language, status, publicToken;
  final int? categoryId;
  final String? templateId, plan, venueName, venueAddress;
  final DateTime? startsAt,
      rsvpDeadline,
      createdAt,
      updatedAt,
      draftExpiresAt,
      publishedAt,
      expiresAt;
  final Map<String, dynamic> design;
  const EventModel({
    required this.id,
    required this.ownerId,
    required this.title,
    required this.language,
    required this.status,
    required this.publicToken,
    this.categoryId,
    this.templateId,
    this.plan,
    this.venueName,
    this.venueAddress,
    this.startsAt,
    this.rsvpDeadline,
    this.createdAt,
    this.updatedAt,
    this.draftExpiresAt,
    this.publishedAt,
    this.expiresAt,
    this.design = const {},
  });
  factory EventModel.fromJson(Map<String, dynamic> j) => EventModel(
    id: j['id'],
    ownerId: j['owner_id'],
    title: j['title'] ?? '',
    language: j['language'] ?? 'en',
    status: j['status'],
    publicToken: j['public_token'],
    categoryId: j['category_id'],
    templateId: j['template_id'],
    plan: j['plan'],
    venueName: j['venue_name'],
    venueAddress: j['venue_address'],
    startsAt: _dt(j['starts_at']),
    rsvpDeadline: _dt(j['rsvp_deadline']),
    createdAt: _dt(j['created_at']),
    updatedAt: _dt(j['updated_at']),
    draftExpiresAt: _dt(j['draft_expires_at']),
    publishedAt: _dt(j['published_at']),
    expiresAt: _dt(j['expires_at']),
    design: Map<String, dynamic>.from(j['design'] as Map? ?? const {}),
  );
  bool get isDraft => status == 'draft';
  bool get isEnded =>
      !isDraft &&
      (status != 'published' ||
          (expiresAt != null && expiresAt!.isBefore(DateTime.now())));
  int get daysLeft {
    if (expiresAt == null) return 0;
    final d = expiresAt!.difference(DateTime.now()).inHours / 24;
    return d <= 0 ? 0 : d.ceil();
  }

  double get validityProgress {
    if (publishedAt == null || expiresAt == null) return 0;
    final total = expiresAt!.difference(publishedAt!).inSeconds;
    if (total <= 0) return 0;
    return (expiresAt!.difference(DateTime.now()).inSeconds / total).clamp(
      0.0,
      1.0,
    );
  }

  EventModel withDesign(Map<String, dynamic> d) => EventModel(
    id: id,
    ownerId: ownerId,
    title: title,
    language: language,
    status: status,
    publicToken: publicToken,
    categoryId: categoryId,
    templateId: templateId,
    plan: plan,
    venueName: venueName,
    venueAddress: venueAddress,
    startsAt: startsAt,
    rsvpDeadline: rsvpDeadline,
    createdAt: createdAt,
    updatedAt: updatedAt,
    draftExpiresAt: draftExpiresAt,
    publishedAt: publishedAt,
    expiresAt: expiresAt,
    design: d,
  );
  PageDesign get pageDesign => PageDesign.fromJson(design);
  String get displayTitle =>
      title.trim().isEmpty ? 'Untitled event' : title.trim();
  String get url => publicUrl(publicToken);
}

/// One element of the invitation canvas (text, photo, shape, decoration, RSVP button, QR).
/// Stored in `event_blocks`: `kind` is the layer type, `position` its z-order.
class EventBlock {
  String? id;
  String kind;
  bool enabled;
  int position;
  Map<String, dynamic> content;
  EventBlock({
    this.id,
    required this.kind,
    this.enabled = true,
    this.position = 0,
    Map<String, dynamic>? content,
  }) : content = content ?? {};
  factory EventBlock.fromJson(Map<String, dynamic> j) => EventBlock(
    id: j['id'],
    kind: j['kind'],
    enabled: j['is_enabled'] ?? true,
    position: j['position'] ?? 0,
    content: Map<String, dynamic>.from(j['content'] as Map? ?? const {}),
  );
  EventBlock copy({bool newId = false}) => EventBlock(
    id: newId ? newLayerId() : id,
    kind: kind,
    enabled: enabled,
    position: position,
    content: deepCopy(content),
  );
  Map<String, dynamic> toRow(String eventId) => {
    'id': id,
    'event_id': eventId,
    'kind': kind,
    'is_enabled': enabled,
    'position': position,
    'content': content,
  };

  double n(String k, [double d = 0]) => (content[k] as num?)?.toDouble() ?? d;
  String? str(String k) => content[k] as String?;
  bool flag(String k) => content[k] == true;
  double get x => n('x');
  double get y => n('y');
  double get w => n('w', .3);
  double get h => n('h', .1);
  double get rot => n('r');
  bool get locked => flag('lk');
  void setBox(double x, double y, double w, double h) => content
    ..['x'] = _r(x)
    ..['y'] = _r(y)
    ..['w'] = _r(w)
    ..['h'] = _r(h);
  static double _r(double v) => double.parse(v.toStringAsFixed(4));
}

Map<String, dynamic> deepCopy(Map<String, dynamic> m) => {
  for (final e in m.entries)
    e.key: e.value is Map
        ? deepCopy(Map<String, dynamic>.from(e.value as Map))
        : e.value is List
        ? List.of(e.value as List)
        : e.value,
};

String newLayerId() {
  final r = Random.secure();
  String h(int n) =>
      List.generate(n, (_) => r.nextInt(16).toRadixString(16)).join();
  return '${h(8)}-${h(4)}-4${h(3)}-${'89ab'[r.nextInt(4)]}${h(3)}-${h(12)}';
}

/// Copies a template's layers into fresh layers for an event.
List<EventBlock> layersFromTemplate(Template t) => [
  for (final (i, l) in t.layout.layers.indexed)
    EventBlock(
      id: newLayerId(),
      kind: l['t'] as String,
      position: i,
      content: deepCopy(Map<String, dynamic>.from(l)..remove('t')),
    ),
];

class Guest {
  final String id, eventId, fullName, rsvp, personalToken;
  final String? email, phone, groupName, message;
  final int companions, openCount;
  final DateTime? respondedAt, lastOpenedAt, createdAt;
  const Guest({
    required this.id,
    required this.eventId,
    required this.fullName,
    required this.rsvp,
    required this.personalToken,
    this.email,
    this.phone,
    this.groupName,
    this.message,
    required this.companions,
    required this.openCount,
    this.respondedAt,
    this.lastOpenedAt,
    this.createdAt,
  });
  factory Guest.fromJson(Map<String, dynamic> j) => Guest(
    id: j['id'],
    eventId: j['event_id'],
    fullName: j['full_name'],
    rsvp: j['rsvp'],
    personalToken: j['personal_token'],
    email: j['email'],
    phone: j['phone'],
    groupName: j['group_name'],
    message: j['message'],
    companions: j['companions'] ?? 0,
    openCount: j['open_count'] ?? 0,
    respondedAt: _dt(j['responded_at']),
    lastOpenedAt: _dt(j['last_opened_at']),
    createdAt: _dt(j['created_at']),
  );
}

class GuestInput {
  final String name;
  final String? email, phone, group;
  const GuestInput(this.name, {this.email, this.phone, this.group});
  Map<String, dynamic> toJson(String source) => {
    'name': name,
    'email': email,
    'phone': phone,
    'group': group,
    'source': source,
  };
}

class ImportResult {
  final int inserted, duplicates, overLimit;
  const ImportResult(this.inserted, this.duplicates, this.overLimit);
  String get summary {
    final parts = <String>['$inserted added'];
    if (duplicates > 0)
      parts.add('$duplicates duplicate${duplicates == 1 ? '' : 's'} skipped');
    if (overLimit > 0) parts.add('$overLimit over your plan limit');
    return parts.join(' · ');
  }
}

class Quote {
  final int subtotal, discount, total;
  final String? code;
  const Quote(this.subtotal, this.discount, this.total, this.code);
  factory Quote.fromJson(Map<String, dynamic> j) =>
      Quote(j['subtotal'], j['discount'], j['total'], j['code']);
}

class GuestCounts {
  int total = 0, confirmed = 0, people = 0;
}

class PublicInvite {
  final EventModel event;
  final List<EventBlock> layers;
  final bool hasEnded, showBranding, rsvpOpen;
  final Map<String, dynamic>? guest;
  const PublicInvite({
    required this.event,
    required this.layers,
    required this.hasEnded,
    required this.showBranding,
    required this.rsvpOpen,
    this.guest,
  });
  factory PublicInvite.fromJson(Map<String, dynamic> j) {
    final e = Map<String, dynamic>.from(j['event'] as Map);
    return PublicInvite(
      event: EventModel.fromJson({...e, 'owner_id': '', 'status': 'published'}),
      layers: [
        for (final (i, b) in (j['blocks'] as List).indexed)
          EventBlock(
            kind: b['kind'],
            position: i,
            content: Map<String, dynamic>.from(
              b['content'] as Map? ?? const {},
            ),
          ),
      ],
      hasEnded: j['has_ended'] == true,
      showBranding: j['show_branding'] == true,
      rsvpOpen: j['rsvp_open'] == true,
      guest: j['guest'] == null
          ? null
          : Map<String, dynamic>.from(j['guest'] as Map),
    );
  }
}

class AdminKpis {
  final Map<String, dynamic> raw;
  const AdminKpis(this.raw);
  int i(String k) => (raw[k] as num?)?.toInt() ?? 0;
}

class AdminTicket {
  final String id, kind, status, title;
  final String? body;
  final DateTime createdAt;
  const AdminTicket({
    required this.id,
    required this.kind,
    required this.status,
    required this.title,
    this.body,
    required this.createdAt,
  });
  factory AdminTicket.fromJson(Map<String, dynamic> j) => AdminTicket(
    id: j['id'],
    kind: j['kind'],
    status: j['status'],
    title: j['title'],
    body: j['body'],
    createdAt: DateTime.parse(j['created_at']),
  );
}

class CheckoutResult {
  final String? url;
  final bool free;
  final String orderId;
  const CheckoutResult({this.url, required this.free, required this.orderId});
}

class OrderInfo {
  final String status, kind;
  final String? eventId, error;
  const OrderInfo({
    required this.status,
    required this.kind,
    this.eventId,
    this.error,
  });
  bool get paid => status == 'paid';
}
