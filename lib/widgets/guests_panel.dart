import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data/backend.dart';
import '../data/models.dart';
import '../theme/app_theme.dart';
import '../util/download.dart';
import '../util/format.dart';
import 'common.dart';
import 'responsive.dart';

/// Guest list with filters, add / import / export. Used in the wizard and in the event page.
class GuestsPanel extends StatefulWidget {
  final EventModel event;
  final List<Guest> guests;
  final int? maxGuests;
  final Future<void> Function() onChanged;
  const GuestsPanel({
    super.key,
    required this.event,
    required this.guests,
    required this.onChanged,
    this.maxGuests,
  });
  @override
  State<GuestsPanel> createState() => GuestsPanelState();
}

class GuestsPanelState extends State<GuestsPanel> {
  String filter = 'all';
  String query = '';
  String sort = 'name';

  List<Guest> get _shown => _sorted(
    widget.guests.where((g) {
      final q = query.trim().toLowerCase();
      final okQ =
          q.isEmpty ||
          g.fullName.toLowerCase().contains(q) ||
          (g.email ?? '').toLowerCase().contains(q);
      final okF = switch (filter) {
        'yes' => g.rsvp == 'yes',
        'pending' => g.rsvp == 'pending',
        'no' => g.rsvp == 'no',
        'maybe' => g.rsvp == 'maybe',
        'opened' => g.openCount > 0,
        'unopened' => g.openCount == 0,
        _ => true,
      };
      return okQ && okF;
    }).toList(),
  );

  List<Guest> _sorted(List<Guest> l) {
    l.sort(
      (a, b) => switch (sort) {
        'rsvp' => a.rsvp.compareTo(b.rsvp),
        'opened' => (b.lastOpenedAt ?? DateTime(1970)).compareTo(
          a.lastOpenedAt ?? DateTime(1970),
        ),
        _ => a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()),
      },
    );
    return l;
  }

  void _sampleCsv() {
    try {
      saveFile(
        Uint8List.fromList(
          utf8.encode(
            'Name,Email,Phone,Group\nAna Lopez,ana@example.com,+1 555 0100,Family\nJohn Smith,john@example.com,,Friends\n',
          ),
        ),
        'guests-sample.csv',
        'text/csv',
      );
    } catch (e) {
      toast(context, 'Downloads are available in the web app.', error: true);
    }
  }

  int _count(String f) => widget.guests
      .where(
        (g) => switch (f) {
          'yes' => g.rsvp == 'yes',
          'pending' => g.rsvp == 'pending',
          'no' => g.rsvp == 'no',
          'maybe' => g.rsvp == 'maybe',
          'opened' => g.openCount > 0,
          'unopened' => g.openCount == 0,
          _ => true,
        },
      )
      .length;

  Future<void> addDialog() async {
    final name = TextEditingController(),
        email = TextEditingController(),
        phone = TextEditingController(),
        group = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text('Add guest', style: serif(20)),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Field('Full name', name, autofocus: true),
                const SizedBox(height: 12),
                Field('Email', email, keyboard: TextInputType.emailAddress),
                const SizedBox(height: 12),
                Field('Phone (optional)', phone, keyboard: TextInputType.phone),
                const SizedBox(height: 12),
                Field(
                  'Group (optional)',
                  group,
                  hint: 'Family, Friends, Work…',
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: sans(14, color: C.body)),
          ),
          TextButton(
            onPressed: () {
              if (name.text.trim().isEmpty) return;
              Navigator.pop(ctx, true);
            },
            child: Text(
              'Add',
              style: sans(14, w: FontWeight.w600, color: C.brand),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _import([
      GuestInput(
        name.text.trim(),
        email: email.text.trim(),
        phone: phone.text.trim(),
        group: group.text.trim(),
      ),
    ], 'manual');
  }

  Future<void> _import(List<GuestInput> rows, String source) async {
    try {
      final r = await Backend.i.importGuests(widget.event.id, rows, source);
      await widget.onChanged();
      if (mounted)
        toast(context, r.summary, error: r.inserted == 0 && rows.isNotEmpty);
    } catch (e) {
      if (mounted) toast(context, errText(e), error: true);
    }
  }

  Future<void> importDialog() async {
    final text = TextEditingController();
    final rows = await showDialog<List<GuestInput>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) {
          final parsed = parseGuestsCsv(text.text);
          return AlertDialog(
            backgroundColor: Colors.white,
            title: Text('Import guests', style: serif(20)),
            content: SizedBox(
              width: 480,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Upload a CSV file or paste rows with these columns: name, email, phone, group.',
                      style: sans(13.5, h: 1.4),
                    ),
                    const SizedBox(height: 12),
                    OutlineBtn(
                      'Choose CSV file',
                      icon: Icons.upload_file_rounded,
                      onTap: () async {
                        final f = await FilePicker.platform.pickFiles(
                          type: FileType.custom,
                          allowedExtensions: ['csv', 'txt'],
                          withData: true,
                        );
                        final bytes = f?.files.single.bytes;
                        if (bytes != null)
                          setD(
                            () => text.text = utf8.decode(
                              bytes,
                              allowMalformed: true,
                            ),
                          );
                      },
                    ),
                    const SizedBox(height: 12),
                    Field(
                      'Or paste here',
                      text,
                      maxLines: 6,
                      hint: 'Ana Torres,ana@email.com,,Family',
                      onChanged: (_) => setD(() {}),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '${parsed.length} guest${parsed.length == 1 ? '' : 's'} found',
                      style: sans(13, w: FontWeight.w600, color: C.ink),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Cancel', style: sans(14, color: C.body)),
              ),
              TextButton(
                onPressed: parsed.isEmpty
                    ? null
                    : () => Navigator.pop(ctx, parsed),
                child: Text(
                  'Import',
                  style: sans(
                    14,
                    w: FontWeight.w600,
                    color: parsed.isEmpty ? C.muted : C.brand,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
    if (rows != null) await _import(rows, 'csv');
  }

  void exportCsv() {
    String q(String? v) => '"${(v ?? '').replaceAll('"', '""')}"';
    final b = StringBuffer(
      'Name,Email,Phone,Group,RSVP,Guests,Message,Last opened\n',
    );
    for (final g in widget.guests) {
      b.writeln(
        [
          q(g.fullName),
          q(g.email),
          q(g.phone),
          q(g.groupName),
          q(g.rsvp),
          g.companions,
          q(g.message),
          q(g.lastOpenedAt?.toIso8601String()),
        ].join(','),
      );
    }
    try {
      saveFile(
        Uint8List.fromList(utf8.encode(b.toString())),
        'guests-${widget.event.publicToken}.csv',
        'text/csv',
      );
    } catch (e) {
      toast(context, 'Downloads are available in the web app.', error: true);
    }
  }

  Future<void> _copy(String text, String msg) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) toast(context, msg);
  }

  @override
  Widget build(BuildContext context) {
    final shown = _shown;
    final mobile = isMobile(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AdaptiveRow(
          breakpoint: 900,
          gap: 16,
          crossAxisAlignment: CrossAxisAlignment.center,
          flex: const [2, 6],
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.maxGuests == null
                      ? '${widget.guests.length} guests'
                      : '${widget.guests.length} of ${widget.maxGuests} guests',
                  style: serif(20),
                ),
                const SizedBox(height: 4),
                Text(
                  'You can add guests now or do it later.',
                  style: sans(13, color: C.muted),
                ),
              ],
            ),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: mobile ? WrapAlignment.start : WrapAlignment.end,
              children: [
                OutlineBtn(
                  'Add manually',
                  icon: Icons.person_add_alt_outlined,
                  onTap: addDialog,
                ),
                OutlineBtn(
                  'Import CSV',
                  icon: Icons.file_upload_outlined,
                  onTap: importDialog,
                ),
                OutlineBtn(
                  'Copy invitation link',
                  icon: Icons.link_rounded,
                  onTap: widget.event.isDraft
                      ? null
                      : () => _copy(widget.event.url, 'Link copied'),
                ),
                OutlineBtn(
                  widget.guests.isEmpty ? 'Download sample CSV' : 'Export CSV',
                  icon: Icons.file_download_outlined,
                  onTap: widget.guests.isEmpty ? _sampleCsv : exportCsv,
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final (k, l) in const [
              ('all', 'All'),
              ('yes', 'Confirmed'),
              ('pending', 'Pending'),
              ('no', 'Declined'),
              ('maybe', 'Maybe'),
              ('opened', 'Opened'),
              ('unopened', 'Not opened'),
            ])
              InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: () => setState(() => filter = k),
                child: Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: filter == k ? C.brandSoft : Colors.white,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: filter == k ? C.brandBorder : C.line,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        l,
                        style: sans(
                          12.5,
                          w: filter == k ? FontWeight.w600 : FontWeight.w400,
                          color: filter == k ? C.brand : C.body,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${_count(k)}',
                        style: sans(12, color: filter == k ? C.brand : C.muted),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Container(
                height: 46,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: C.line),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.search_rounded, size: 19, color: C.muted),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        onChanged: (v) => setState(() => query = v),
                        style: sans(14, color: C.ink),
                        decoration: InputDecoration(
                          isCollapsed: true,
                          border: InputBorder.none,
                          hintText: 'Search guests by name, email or phone...',
                          hintStyle: sans(14, color: C.muted),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (!mobile) ...[
              const SizedBox(width: 12),
              SizedBox(
                width: 220,
                child: SelectBox<String>(
                  label: 'Sort by',
                  value: sort,
                  options: const [
                    ('name', 'Sort by: Name (A–Z)'),
                    ('rsvp', 'Sort by: RSVP'),
                    ('opened', 'Sort by: Last opened'),
                  ],
                  onChanged: (v) => setState(() => sort = v ?? 'name'),
                  anyLabel: 'Sort by: Name (A–Z)',
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 14),
        if (widget.guests.isEmpty)
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                if (!mobile) _header(),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 48,
                  ),
                  child: Center(
                    child: Column(
                      children: [
                        const Icon(
                          Icons.groups_rounded,
                          size: 44,
                          color: C.muted,
                        ),
                        const SizedBox(height: 12),
                        Text('No guests yet', style: serif(19)),
                        const SizedBox(height: 6),
                        Text(
                          'Add guests manually or import a CSV file to get started.',
                          textAlign: TextAlign.center,
                          style: sans(13.5, color: C.muted),
                        ),
                        const SizedBox(height: 20),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          alignment: WrapAlignment.center,
                          children: [
                            PrimaryButton(
                              'Add your first guest',
                              icon: Icons.person_add_alt_outlined,
                              expand: false,
                              onTap: addDialog,
                            ),
                            OutlineBtn(
                              'Import CSV',
                              icon: Icons.file_upload_outlined,
                              height: 40,
                              onTap: importDialog,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          )
        else if (shown.isEmpty)
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text('No guests match this filter.', style: sans(14)),
          )
        else
          AppCard(
            padding: EdgeInsets.zero,
            radius: 12,
            child: Column(
              children: [
                if (!mobile) _header(),
                for (final g in shown) mobile ? _mobileRow(g) : _row(g),
              ],
            ),
          ),
      ],
    );
  }

  Widget _header() => Container(
    height: 46,
    padding: const EdgeInsets.symmetric(horizontal: 16),
    decoration: const BoxDecoration(
      color: Color(0xFFF9F8F8),
      border: Border(bottom: BorderSide(color: C.line)),
    ),
    child: Row(
      children: [
        _h('Guest', 4),
        _h('Contact', 4),
        _h('Group', 2),
        _h('RSVP', 2),
        _h('Guests', 1),
        _h('Last activity', 3),
        const SizedBox(width: 40),
      ],
    ),
  );

  Widget _h(String t, int f) => Expanded(
    flex: f,
    child: Text(
      t,
      overflow: TextOverflow.ellipsis,
      style: sans(12.5, w: FontWeight.w600, color: C.ink),
    ),
  );

  Widget _menu(Guest g) => PopupMenuButton<String>(
    tooltip: '',
    color: Colors.white,
    padding: EdgeInsets.zero,
    icon: const Icon(Icons.more_vert_rounded, size: 20, color: C.ink),
    onSelected: (v) async {
      if (v == 'copy')
        await _copy(
          publicUrl(widget.event.publicToken, guest: g.personalToken),
          'Personal link copied',
        );
      if (v == 'delete') {
        try {
          await Backend.i.deleteGuest(g.id);
          await widget.onChanged();
        } catch (e) {
          if (mounted) toast(context, errText(e), error: true);
        }
      }
    },
    itemBuilder: (_) => [
      if (!widget.event.isDraft)
        PopupMenuItem(
          value: 'copy',
          child: Text('Copy personal link', style: sans(14)),
        ),
      PopupMenuItem(
        value: 'delete',
        child: Text('Delete guest', style: sans(14, color: C.red)),
      ),
    ],
  );

  Widget _row(Guest g) => Container(
    constraints: const BoxConstraints(minHeight: 56),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: C.line)),
    ),
    child: Row(
      children: [
        Expanded(
          flex: 4,
          child: Row(
            children: [
              Avatar(g.fullName, size: 34),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  g.fullName,
                  overflow: TextOverflow.ellipsis,
                  style: sans(13, w: FontWeight.w600, color: C.ink),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          flex: 4,
          child: Text(
            (g.email ?? g.phone) ?? '—',
            overflow: TextOverflow.ellipsis,
            style: sans(12.5),
          ),
        ),
        Expanded(
          flex: 2,
          child: Text(
            g.groupName ?? '—',
            overflow: TextOverflow.ellipsis,
            style: sans(12.5),
          ),
        ),
        Expanded(
          flex: 2,
          child: Align(
            alignment: Alignment.centerLeft,
            child: rsvpPill(g.rsvp),
          ),
        ),
        Expanded(flex: 1, child: Text('${g.companions}', style: sans(13))),
        Expanded(
          flex: 3,
          child: Text(
            g.lastOpenedAt == null ? "Hasn't opened" : fmtAgo(g.lastOpenedAt),
            overflow: TextOverflow.ellipsis,
            style: sans(12.5),
          ),
        ),
        SizedBox(width: 40, child: _menu(g)),
      ],
    ),
  );

  Widget _mobileRow(Guest g) => Container(
    padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: C.line)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Avatar(g.fullName, size: 38),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                g.fullName,
                overflow: TextOverflow.ellipsis,
                style: sans(14, w: FontWeight.w600, color: C.ink),
              ),
              if ((g.email ?? g.phone) != null)
                Text(
                  (g.email ?? g.phone)!,
                  overflow: TextOverflow.ellipsis,
                  style: sans(12.5),
                ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  rsvpPill(g.rsvp),
                  if (g.companions > 0)
                    Text(
                      '+${g.companions}',
                      style: sans(12.5, w: FontWeight.w600, color: C.ink),
                    ),
                  if (g.groupName != null)
                    Text(g.groupName!, style: sans(12.5, color: C.muted)),
                  Text(
                    g.lastOpenedAt == null
                        ? "Hasn't opened"
                        : 'Opened ${fmtAgo(g.lastOpenedAt)}',
                    style: sans(12, color: C.muted),
                  ),
                ],
              ),
            ],
          ),
        ),
        _menu(g),
      ],
    ),
  );
}

/// Parses "name,email,phone,group" rows, with or without a header line.
List<GuestInput> parseGuestsCsv(String raw) {
  final rows = <List<String>>[];
  for (final line in const LineSplitter().convert(raw)) {
    if (line.trim().isEmpty) continue;
    final cells = <String>[];
    final b = StringBuffer();
    var inQ = false;
    for (int i = 0; i < line.length; i++) {
      final ch = line[i];
      if (ch == '"') {
        if (inQ && i + 1 < line.length && line[i + 1] == '"') {
          b.write('"');
          i++;
        } else {
          inQ = !inQ;
        }
      } else if ((ch == ',' || ch == ';' || ch == '\t') && !inQ) {
        cells.add(b.toString().trim());
        b.clear();
      } else {
        b.write(ch);
      }
    }
    cells.add(b.toString().trim());
    rows.add(cells);
  }
  if (rows.isEmpty) return [];
  var idx = {'name': 0, 'email': 1, 'phone': 2, 'group': 3};
  final head = rows.first.map((c) => c.toLowerCase()).toList();
  if (head.any((c) => c == 'name' || c == 'full name' || c == 'email')) {
    idx = {
      'name': head.indexWhere((c) => c == 'name' || c == 'full name'),
      'email': head.indexOf('email'),
      'phone': head.indexWhere((c) => c == 'phone' || c == 'telephone'),
      'group': head.indexOf('group'),
    };
    rows.removeAt(0);
  }
  String? cell(List<String> r, String k) {
    final i = idx[k]!;
    return i >= 0 && i < r.length && r[i].isNotEmpty ? r[i] : null;
  }

  return [
    for (final r in rows)
      if (cell(r, 'name') != null)
        GuestInput(
          cell(r, 'name')!,
          email: cell(r, 'email'),
          phone: cell(r, 'phone'),
          group: cell(r, 'group'),
        ),
  ];
}
