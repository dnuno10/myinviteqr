import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/backend.dart';
import '../../data/models.dart';
import '../../theme/app_theme.dart';
import '../../util/format.dart';
import '../../widgets/common.dart';
import '../../widgets/invitation.dart';
import 'wizard.dart';
import 'wizard_ui.dart';

const _kindIcons = {
  'text': Icons.title_rounded,
  'photo': Icons.image_outlined,
  'shape': Icons.category_outlined,
  'deco': Icons.auto_awesome_outlined,
  'rsvp': Icons.mark_email_read_outlined,
  'qr': Icons.qr_code_2_rounded,
};

const _shapeChoices = <(String, String)>[
  ('rect', 'Square'),
  ('round', 'Rounded'),
  ('circle', 'Circle'),
  ('oval', 'Oval'),
  ('arch', 'Arch'),
  ('pill', 'Pill'),
  ('heart', 'Heart'),
  ('diamond', 'Diamond'),
  ('triangle', 'Triangle'),
];

const _bindChoices = <(String, String)>[
  ('', 'Custom text'),
  ('title', 'Event title'),
  ('datetime', 'Date and time'),
  ('date', 'Full date'),
  ('datesh', 'Short date'),
  ('time', 'Time'),
  ('weekday', 'Weekday'),
  ('day', 'Day number'),
  ('month', 'Month'),
  ('year', 'Year'),
  ('venue', 'Venue name'),
  ('address', 'Address'),
  ('place', 'Venue and address'),
  ('countdown', 'Countdown'),
];

const _collages = <(String, String)>[
  ('grid4', 'Grid 2×2'),
  ('hero2', 'Hero + 2'),
  ('polaroids', 'Polaroids'),
  ('arches', 'Three arches'),
  ('circles', 'Circle duo'),
  ('row3', 'Circle row'),
  ('strip', 'Film strip'),
  ('mosaic', 'Mosaic'),
  ('hearts', 'Hearts'),
];

List<Map<String, dynamic>> _collage(String id, double y) {
  Map<String, dynamic> p(
    double x,
    double yy,
    double w,
    double h, {
    String? sh,
    double? r,
    double? bw,
    bool pol = false,
    double? rd,
  }) => {
    'x': x,
    'y': yy,
    'w': w,
    'h': h,
    if (sh != null) 'sh': sh,
    if (r != null) 'r': r,
    if (bw != null) 'bw': bw,
    if (bw != null) 'bc': 'white',
    if (pol) 'pol': true,
    if (pol) 'bw': .03,
    if (rd != null) 'rd': rd,
  };
  switch (id) {
    case 'grid4':
      return [
        p(.06, y, .43, .3, sh: 'round', rd: .08),
        p(.51, y, .43, .3, sh: 'round', rd: .08),
        p(.06, y + .32, .43, .3, sh: 'round', rd: .08),
        p(.51, y + .32, .43, .3, sh: 'round', rd: .08),
      ];
    case 'hero2':
      return [
        p(.06, y, .56, .5, sh: 'round', rd: .08),
        p(.64, y, .3, .24, sh: 'round', rd: .12),
        p(.64, y + .26, .3, .24, sh: 'round', rd: .12),
      ];
    case 'polaroids':
      return [
        p(.06, y, .46, .56, pol: true, r: -5),
        p(.46, y + .08, .46, .56, pol: true, r: 5),
        p(.24, y + .46, .44, .5, pol: true, r: -2),
      ];
    case 'arches':
      return [
        p(.05, y, .28, .42, sh: 'arch'),
        p(.36, y + .04, .28, .42, sh: 'arch'),
        p(.67, y, .28, .42, sh: 'arch'),
      ];
    case 'circles':
      return [
        p(.1, y, .55, .55, sh: 'circle', bw: .012),
        p(.5, y + .4, .38, .38, sh: 'circle', bw: .014),
      ];
    case 'row3':
      return [
        p(.04, y, .29, .29, sh: 'circle'),
        p(.355, y, .29, .29, sh: 'circle'),
        p(.67, y, .29, .29, sh: 'circle'),
      ];
    case 'strip':
      return [
        for (int i = 0; i < 4; i++)
          p(
            .04 + i * .24,
            y,
            .22,
            .26,
            r: const [-3.0, 2.0, -2.0, 3.0][i],
            bw: .006,
          ),
      ];
    case 'mosaic':
      return [
        p(.06, y, .56, .5, sh: 'round', rd: .08),
        p(.64, y, .3, .25, sh: 'round', rd: .12),
        p(.64, y + .27, .3, .25, sh: 'round', rd: .12),
        p(.06, y + .54, .88, .3, sh: 'round', rd: .06),
      ];
    case 'hearts':
      return [
        p(.04, y + .08, .3, .3, sh: 'heart', r: -8),
        p(.35, y, .3, .3, sh: 'heart'),
        p(.66, y + .08, .3, .3, sh: 'heart', r: 8),
      ];
  }
  return [];
}

class EditorStep extends StatefulWidget {
  final WizardController c;
  const EditorStep(this.c, {super.key});
  @override
  State<EditorStep> createState() => _EditorStepState();
}

class _EditorStepState extends State<EditorStep> {
  late List<EventBlock> layers = [for (final b in widget.c.blocks) b.copy()]
    ..sort((a, b) => a.position.compareTo(b.position));
  late PageDesign design = _initialDesign();
  final history = <String>[];
  int hi = -1;
  String? selId;
  Timer? timer;
  bool saving = false, dirty = false, uploading = false, _closing = false;
  DateTime? savedAt;
  String? saveError;
  int tab = 0; // panel tab: 0 Add, 1 Layers, 2 Element, 3 Page
  String toneFilter = 'all';
  final canvasKey = GlobalKey();
  // drag state
  Offset? _lastGlobal;
  ({
    double x,
    double y,
    double w,
    double h,
    double r,
    Offset pStart,
    Offset handleStart,
  })?
  _rs;

  PageDesign _initialDesign() {
    final e = widget.c.event!;
    if (e.design['palette'] != null) return PageDesign.fromJson(e.design);
    final t = widget.c.template;
    return t?.layout.design ?? PageDesign.fromJson(null);
  }

  EventBlock? get sel => layers.where((l) => l.id == selId).firstOrNull;

  @override
  void initState() {
    super.initState();
    _record();
  }

  @override
  void dispose() {
    _closing = true;
    timer?.cancel();
    if (dirty) _save();
    super.dispose();
  }

  // ------------------------------------------------------------------ history / save
  String _snap() => jsonEncode({
    'l': [for (final l in layers) l.toRow('-')],
    'd': design.toJson(),
  });

  void _record() {
    history.removeRange(hi + 1, history.length);
    history.add(_snap());
    hi = history.length - 1;
    if (history.length > 80) {
      history.removeAt(0);
      hi--;
    }
  }

  void _touch() {
    dirty = true;
    timer?.cancel();
    timer = Timer(const Duration(milliseconds: 800), _save);
  }

  /// A discrete change: mutate, record in history, schedule save.
  void _change(VoidCallback fn) {
    setState(fn);
    _record();
    _touch();
  }

  /// A continuous change (drag / slider): no history entry until [_commit].
  void _live(VoidCallback fn) {
    setState(fn);
    _touch();
  }

  void _commit() {
    if (history.isEmpty || history[hi] != _snap()) _record();
  }

  void _restore() {
    final j = jsonDecode(history[hi]) as Map<String, dynamic>;
    setState(() {
      layers = [
        for (final r in j['l'] as List)
          EventBlock(
            id: r['id'] as String?,
            kind: r['kind'],
            enabled: r['is_enabled'],
            position: r['position'],
            content: Map<String, dynamic>.from(r['content'] as Map),
          ),
      ];
      design = PageDesign.fromJson(Map<String, dynamic>.from(j['d'] as Map));
      if (sel == null) selId = null;
    });
    _touch();
  }

  Future<bool> _save() async {
    timer?.cancel();
    final c = widget.c;
    final toSave = [for (final l in layers) l.copy()];
    final d = design.toJson();
    if (_closing || !mounted) {
      try {
        await Backend.i.saveBlocks(c.event!.id, toSave);
        await Backend.i.updateEvent(c.event!.id, {'design': d});
      } catch (_) {}
      return true;
    }
    setState(() {
      saving = true;
      saveError = null;
    });
    try {
      await Backend.i.saveBlocks(c.event!.id, toSave);
      final ev = await Backend.i.updateEvent(c.event!.id, {'design': d});
      c.blocks = [for (final l in layers) l.copy()];
      c.event = ev;
      dirty = false;
      if (mounted)
        setState(() {
          saving = false;
          savedAt = DateTime.now();
        });
      return true;
    } catch (e) {
      if (mounted)
        setState(() {
          saving = false;
          saveError = errText(e);
        });
      return false;
    }
  }

  Future<void> _next() async {
    if (!await _save() || !mounted) return;
    if (widget.c.published) {
      Navigator.of(context).pop();
    } else {
      widget.c.goTo(4);
    }
  }

  // ------------------------------------------------------------------ layer operations
  void _select(String? id) {
    setState(() {
      selId = id;
      if (id != null && tab != 2 && MediaQuery.sizeOf(context).width >= 1180)
        tab = 2;
    });
  }

  void _add(EventBlock l) {
    l.id = newLayerId();
    l.position = layers.length;
    _change(() {
      layers.add(l);
      selId = l.id;
      tab = 2;
      final bottom = l.y + l.h + .1;
      if (bottom > design.height)
        design = PageDesign(
          pal: design.pal,
          height: bottom.clamp(1.2, 6.0),
          gradient: design.gradient,
        );
    });
  }

  double get _spawnY => (.25 + (layers.length % 6) * .04)
      .clamp(.1, math.max(.2, design.height - .6))
      .toDouble();

  void _addText() => _add(
    EventBlock(
      kind: 'text',
      content: {
        'x': .12,
        'y': _spawnY,
        'w': .76,
        'h': .12,
        'tx': 'Your text here',
        'f': 'Playfair Display',
        's': .07,
        'c': 'ink',
      },
    ),
  );
  void _addPhoto() => _add(
    EventBlock(
      kind: 'photo',
      content: {
        'x': .2,
        'y': _spawnY,
        'w': .6,
        'h': .45,
        'sh': 'round',
        'rd': .1,
      },
    ),
  );
  void _addShape() => _add(
    EventBlock(
      kind: 'shape',
      content: {
        'sh': 'circle',
        'x': .3,
        'y': _spawnY,
        'w': .4,
        'h': .4,
        'fl': 'accent',
        'o': .9,
      },
    ),
  );
  void _addRsvp() => _add(
    EventBlock(
      kind: 'rsvp',
      content: {
        'x': .2,
        'y': _spawnY,
        'w': .6,
        'h': .09,
        'lb': 'Confirm attendance',
        'st': 'solid',
        'c': 'accent',
        'f': 'Inter',
        's': .038,
      },
    ),
  );
  void _addQr() => _add(
    EventBlock(kind: 'qr', content: {'x': .4, 'y': _spawnY, 'w': .2, 'h': .2}),
  );
  void _addDeco(String k) => _add(
    EventBlock(
      kind: 'deco',
      content: {
        'k': k,
        'x': 0,
        'y': _spawnY,
        'w': 1,
        'h': k == 'divider' ? .05 : .4,
        'sd': math.Random().nextInt(90) + 1,
      },
    ),
  );

  void _addCollage(String id) {
    final y = _spawnY;
    final rows = _collage(id, y);
    final base = layers.length;
    _change(() {
      for (final (i, r) in rows.indexed) {
        layers.add(
          EventBlock(
            id: newLayerId(),
            kind: 'photo',
            position: base + i,
            content: r,
          ),
        );
      }
      selId = layers.last.id;
      tab = 2;
      final bottom =
          rows
              .map((r) => (r['y'] as double) + (r['h'] as double))
              .reduce(math.max) +
          .1;
      if (bottom > design.height)
        design = PageDesign(
          pal: design.pal,
          height: bottom.clamp(1.2, 6.0),
          gradient: design.gradient,
        );
    });
  }

  void _delete(EventBlock l) => _change(() {
    layers.remove(l);
    if (selId == l.id) selId = null;
  });

  void _duplicate(EventBlock l) {
    final n = l.copy(newId: true);
    n.content['x'] = math.min(.9, l.x + .03);
    n.content['y'] = l.y + .03;
    _change(() {
      layers.add(n);
      selId = n.id;
    });
  }

  void _z(EventBlock l, int delta) {
    final i = layers.indexOf(l);
    final j = (i + delta).clamp(0, layers.length - 1);
    if (i == j) return;
    _change(() {
      layers.removeAt(i);
      layers.insert(j, l);
    });
  }

  Future<void> _pickPhoto(EventBlock l) async {
    try {
      final f = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );
      final file = f?.files.singleOrNull;
      if (file == null || file.bytes == null) return;
      setState(() => uploading = true);
      final url = await Backend.i.uploadImage(
        widget.c.event!.id,
        file.bytes!,
        file.name,
      );
      _change(() {
        l.content['url'] = url;
        l.content.remove('fx');
        l.content.remove('fy');
        l.content.remove('z');
      });
    } catch (e) {
      if (mounted) toast(context, errText(e), error: true);
    } finally {
      if (mounted) setState(() => uploading = false);
    }
  }

  Future<void> _resetToTemplate() async {
    final t = widget.c.template;
    if (t == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text('Reset the design?', style: serif(20)),
        content: Text(
          'All your edits and photo placements will be replaced by the original “${t.name}” template.',
          style: sans(14, h: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: sans(14, color: C.body)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Reset',
              style: sans(14, w: FontWeight.w600, color: C.red),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;
    _change(() {
      layers = layersFromTemplate(t);
      design = t.layout.design;
      selId = null;
    });
  }

  // ------------------------------------------------------------------ canvas interaction
  double _pageW = 360;

  Offset _pagePos(Offset global) {
    final box = canvasKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return Offset.zero;
    final p = box.globalToLocal(global);
    return p / _pageW;
  }

  Widget _wrap(BuildContext context, EventBlock l, Widget child, double W) {
    if (l.locked && l.id != selId) return IgnorePointer(child: child);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _select(l.id),
      onDoubleTap: l.kind == 'photo' ? () => _pickPhoto(l) : null,
      onPanStart: (d) {
        if (l.locked) return;
        _select(l.id);
        _lastGlobal = d.globalPosition;
      },
      onPanUpdate: (d) {
        if (l.locked || _lastGlobal == null) return;
        final delta = (d.globalPosition - _lastGlobal!) / W;
        _lastGlobal = d.globalPosition;
        _live(
          () => l.setBox(
            (l.x + delta.dx).clamp(-.5, 1.3),
            (l.y + delta.dy).clamp(-.5, design.height + .3),
            l.w,
            l.h,
          ),
        );
      },
      onPanEnd: (_) => _commit(),
      onPanCancel: _commit,
      child: child,
    );
  }

  void _resizeStart(EventBlock l, int sx, int sy, Offset global) {
    final r = l.rot * math.pi / 180;
    final c = Offset(l.x + l.w / 2, l.y + l.h / 2);
    final handle = c + _rot(Offset(sx * l.w / 2, sy * l.h / 2), r);
    _rs = (
      x: l.x,
      y: l.y,
      w: l.w,
      h: l.h,
      r: r,
      pStart: _pagePos(global),
      handleStart: handle,
    );
  }

  void _resizeUpdate(EventBlock l, int sx, int sy, Offset global) {
    final s = _rs;
    if (s == null) return;
    final c0 = Offset(s.x + s.w / 2, s.y + s.h / 2);
    final opp = c0 + _rot(Offset(-sx * s.w / 2, -sy * s.h / 2), s.r);
    final pNew = s.handleStart + (_pagePos(global) - s.pStart);
    final diag = _rot(pNew - opp, -s.r);
    var w = math.max(.03, sx * diag.dx), h = math.max(.03, sy * diag.dy);
    if (l.kind == 'qr') h = w;
    final corner = _rot(Offset(sx * w, sy * h), s.r);
    final c = opp + corner / 2;
    _live(() => l.setBox(c.dx - w / 2, c.dy - h / 2, w, h));
  }

  void _rotateUpdate(EventBlock l, Offset global) {
    final c = Offset(l.x + l.w / 2, l.y + l.h / 2);
    final p = _pagePos(global) - c;
    var deg = math.atan2(p.dy, p.dx) * 180 / math.pi + 90;
    while (deg > 180) {
      deg -= 360;
    }
    while (deg < -180) {
      deg += 360;
    }
    for (final snap in [0.0, 45.0, 90.0, -45.0, -90.0, 180.0, -180.0]) {
      if ((deg - snap).abs() < 4) deg = snap;
    }
    _live(() => l.content['r'] = double.parse(deg.toStringAsFixed(1)));
  }

  Offset _rot(Offset o, double a) => Offset(
    o.dx * math.cos(a) - o.dy * math.sin(a),
    o.dx * math.sin(a) + o.dy * math.cos(a),
  );

  List<Widget> _overlays(double W) {
    final l = sel;
    if (l == null || !l.enabled) return const [];
    Widget handle(int sx, int sy) => Positioned(
      left: sx < 0 ? -13 : null,
      right: sx > 0 ? -13 : null,
      top: sy < 0 ? -13 : null,
      bottom: sy > 0 ? -13 : null,
      child: MouseRegion(
        cursor: (sx * sy > 0)
            ? SystemMouseCursors.resizeUpLeftDownRight
            : SystemMouseCursors.resizeUpRightDownLeft,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (d) => _resizeStart(l, sx, sy, d.globalPosition),
          onPanUpdate: (d) => _resizeUpdate(l, sx, sy, d.globalPosition),
          onPanEnd: (_) {
            _rs = null;
            _commit();
          },
          child: Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: C.brand, width: 2),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ),
      ),
    );
    return [
      Positioned(
        left: l.x * W,
        top: l.y * W,
        width: l.w * W,
        height: l.h * W,
        child: Transform.rotate(
          angle: l.rot * math.pi / 180,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: C.brand, width: 1.6),
                    ),
                  ),
                ),
              ),
              handle(-1, -1),
              handle(1, -1),
              handle(-1, 1),
              handle(1, 1),
              Positioned(
                top: -40,
                left: 0,
                right: 0,
                child: Center(
                  child: MouseRegion(
                    cursor: SystemMouseCursors.grab,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onPanUpdate: (d) => _rotateUpdate(l, d.globalPosition),
                      onPanEnd: (_) => _commit(),
                      child: SizedBox(
                        width: 30,
                        height: 30,
                        child: Center(
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: C.brand,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.rotate_right_rounded,
                              size: 14,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ];
  }

  // ------------------------------------------------------------------ build
  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    final wide = MediaQuery.sizeOf(context).width >= 1180;
    if (c.template == null)
      return Text('Choose a template first.', style: sans(14));
    final status = saveError != null
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, size: 18, color: C.red),
              const SizedBox(width: 6),
              Flexible(
                child: Text(saveError!, style: sans(12.5, color: C.red)),
              ),
            ],
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              saving || dirty
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: C.muted,
                      ),
                    )
                  : const Icon(
                      Icons.check_circle_outline_rounded,
                      size: 20,
                      color: C.green,
                    ),
              const SizedBox(width: 8),
              Text(
                saving || dirty
                    ? 'Saving…'
                    : savedAt == null
                    ? 'All changes saved'
                    : 'Saved ${fmtAgo(savedAt)}',
                style: sans(12.5, color: C.body),
              ),
            ],
          );

    final toolbar = Wrap(
      spacing: 10,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        OutlineBtn(
          'Undo',
          icon: Icons.undo_rounded,
          onTap: hi > 0
              ? () {
                  hi--;
                  _restore();
                }
              : null,
        ),
        OutlineBtn(
          'Redo',
          icon: Icons.redo_rounded,
          onTap: hi < history.length - 1
              ? () {
                  hi++;
                  _restore();
                }
              : null,
        ),
        OutlineBtn(
          'Preview',
          icon: Icons.visibility_outlined,
          onTap: () => showFullPreview(
            context,
            event: c.event!.withDesign(design.toJson()),
            design: design,
            layers: layers,
          ),
        ),
        status,
      ],
    );

    final canvas = _canvasArea();
    final Widget body = wide
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 300,
                child: Column(
                  children: [
                    _addPanel(),
                    const SizedBox(height: 16),
                    _layersPanel(),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              Expanded(child: canvas),
              const SizedBox(width: 24),
              SizedBox(width: 360, child: _rightPanel()),
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: canvas,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final (i, l) in const [
                    'Add',
                    'Layers',
                    'Element',
                    'Page',
                  ].indexed)
                    InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => setState(() => tab = i),
                      child: Container(
                        height: 40,
                        padding: const EdgeInsets.symmetric(horizontal: 18),

                        decoration: BoxDecoration(
                          color: tab == i ? C.brandSoft : Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: tab == i ? C.brandBorder : C.line,
                          ),
                        ),
                        child: Center(
                          widthFactor: 1,
                          child: Text(
                            l,
                            style: sans(
                              13.5,
                              w: tab == i ? FontWeight.w600 : FontWeight.w400,
                              color: tab == i ? C.brand : C.body,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: [
                  _addPanel(),
                  _layersPanel(),
                  _elementPanel(),
                  _pagePanel(),
                ][tab],
              ),
            ],
          );

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.delete): () {
          final l = sel;
          if (l != null &&
              !(FocusManager.instance.primaryFocus?.context?.widget
                  is EditableText))
            _delete(l);
        },
      },
      child: Focus(
        autofocus: false,
        child: WizardPage(
          c: widget.c,
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [toolbar, const SizedBox(height: 18), body],
          ),
          footer: WizardFooter(
            onBack: widget.c.published
                ? null
                : () async {
                    await _save();
                    widget.c.goTo(2);
                  },
            nextLabel: widget.c.published
                ? 'Save and close'
                : 'Continue to guests',
            busy: saving,
            onNext: _next,
          ),
        ),
      ),
    );
  }

  Widget _canvasArea() => LayoutBuilder(
    builder: (context, box) {
      final avail = box.maxWidth.isFinite ? box.maxWidth : 420.0;
      final W = (avail - 56).clamp(220.0, 460.0);
      _pageW = W;
      final e = widget.c.event!.withDesign(design.toJson());
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: const Color(0xFFF1EEED),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: C.line),
        ),
        child: Column(
          children: [
            Center(
              child: SizedBox(
                width: W + 56,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      GestureDetector(
                        onTap: () => _select(null),
                        child: SizedBox(
                          key: canvasKey,
                          width: W,
                          child: InvitationPage(
                            event: e,
                            design: design,
                            layers: layers,
                            url: e.url,
                            editing: true,
                            wrap: _wrap,
                          ),
                        ),
                      ),
                      ..._overlays(W),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Tap an element to edit it · drag to move · double-tap a photo to change it',
              textAlign: TextAlign.center,
              style: sans(12, color: C.muted),
            ),
          ],
        ),
      );
    },
  );

  // ------------------------------------------------------------------ side panels
  Widget _rightPanel() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: const Color(0xFFF6F4F3),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            for (final (i, l) in const [
              (2, 'Element'),
              (3, 'Page'),
            ].map((e) => e).indexed)
              Expanded(
                child: InkWell(
                  onTap: () => setState(() => tab = l.$1),
                  child: Container(
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: (tab == l.$1 || (i == 0 && tab < 2))
                          ? C.brandSoft
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      l.$2,
                      style: sans(
                        14,
                        w: (tab == l.$1 || (i == 0 && tab < 2))
                            ? FontWeight.w600
                            : FontWeight.w400,
                        color: (tab == l.$1 || (i == 0 && tab < 2))
                            ? C.brand
                            : C.ink,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      tab == 3 ? _pagePanel() : _elementPanel(),
    ],
  );

  Widget _card(String title, Widget child, {Widget? trailing}) => AppCard(
    padding: const EdgeInsets.all(18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(title, style: serif(18))),
            if (trailing != null) trailing,
          ],
        ),
        const SizedBox(height: 12),
        child,
      ],
    ),
  );

  Widget _addPanel() => _card(
    'Add to your page',
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _addBtn(Icons.title_rounded, 'Text', _addText),
            _addBtn(Icons.image_outlined, 'Photo', _addPhoto),
            _addBtn(Icons.category_outlined, 'Shape', _addShape),
            _addBtn(Icons.mark_email_read_outlined, 'RSVP button', _addRsvp),
            _addBtn(Icons.qr_code_2_rounded, 'QR code', _addQr),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          'Photo collages',
          style: sans(13, w: FontWeight.w600, color: C.ink),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final c in _collages)
              _chip(c.$2, false, () => _addCollage(c.$1)),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          'Decorations',
          style: sans(13, w: FontWeight.w600, color: C.ink),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final k in decoKinds.entries)
              _chip(k.value, false, () => _addDeco(k.key)),
          ],
        ),
      ],
    ),
  );

  Widget _addBtn(IconData i, String l, VoidCallback f) =>
      OutlineBtn(l, icon: i, height: 40, onTap: f);

  Widget _chip(String label, bool on, VoidCallback f) => InkWell(
    borderRadius: BorderRadius.circular(9),
    onTap: f,
    child: Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 12),

      decoration: BoxDecoration(
        color: on ? C.brandSoft : Colors.white,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: on ? C.brand : C.line, width: on ? 1.4 : 1),
      ),
      child: Center(
        widthFactor: 1,
        child: Text(
          label,
          style: sans(
            12.5,
            w: on ? FontWeight.w600 : FontWeight.w400,
            color: on ? C.brand : C.ink,
          ),
        ),
      ),
    ),
  );

  String _label(EventBlock l) {
    switch (l.kind) {
      case 'text':
        final b = l.str('b');
        if (b != null && b.isNotEmpty)
          return _bindChoices
              .firstWhere((c) => c.$1 == b, orElse: () => ('', b))
              .$2;
        final t = (l.str('tx') ?? '').trim();
        return t.isEmpty ? 'Text' : t.split('\n').first;
      case 'photo':
        return (l.str('url') ?? '').isEmpty ? 'Photo (empty)' : 'Photo';
      case 'shape':
        return 'Shape · ${_shapeChoices.firstWhere((s) => s.$1 == (l.str('sh') ?? 'rect'), orElse: () => ('', 'Shape')).$2}';
      case 'deco':
        return decoKinds[l.str('k')] ?? 'Decoration';
      case 'rsvp':
        return 'RSVP button';
      case 'qr':
        return 'QR code';
    }
    return l.kind;
  }

  Widget _layersPanel() => _card(
    'Layers',
    layers.isEmpty
        ? Text(
            'Nothing here yet. Add text, photos or decorations.',
            style: sans(13.5),
          )
        : ReorderableListView(
            shrinkWrap: true,
            buildDefaultDragHandles: false,
            physics: const NeverScrollableScrollPhysics(),
            onReorderItem: (o, n) {
              // list is shown top-most first
              final from = layers.length - 1 - o;
              final to = layers.length - 1 - n;
              _change(
                () => layers.insert(
                  to.clamp(0, layers.length - 1),
                  layers.removeAt(from),
                ),
              );
            },
            children: [
              for (final (i, l) in layers.reversed.indexed)
                Container(
                  key: ValueKey(l.id),
                  height: 46,
                  decoration: BoxDecoration(
                    color: l.id == selId ? C.brandSoft : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      ReorderableDragStartListener(
                        index: i,
                        child: const MouseRegion(
                          cursor: SystemMouseCursors.grab,
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 6),
                            child: Icon(
                              Icons.drag_indicator_rounded,
                              size: 18,
                              color: C.muted,
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: InkWell(
                          onTap: () => _select(l.id),
                          child: Row(
                            children: [
                              Icon(
                                _kindIcons[l.kind] ?? Icons.crop_square_rounded,
                                size: 18,
                                color: l.enabled ? C.ink : C.muted,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _label(l),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: sans(
                                    13,
                                    color: l.enabled ? C.ink : C.muted,
                                    w: l.id == selId
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      _mini(
                        l.locked
                            ? Icons.lock_outline_rounded
                            : Icons.lock_open_rounded,
                        l.locked ? 'Unlock' : 'Lock',
                        () => _change(() => l.content['lk'] = !l.locked),
                      ),
                      _mini(
                        l.enabled
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        l.enabled ? 'Hide' : 'Show',
                        () => _change(() => l.enabled = !l.enabled),
                      ),
                    ],
                  ),
                ),
            ],
          ),
  );

  Widget _mini(IconData i, String tip, VoidCallback f) => IconButton(
    visualDensity: VisualDensity.compact,
    tooltip: tip,
    onPressed: f,
    icon: Icon(i, size: 18, color: C.body),
  );

  // ------------------------------------------------------------------ element properties
  Widget _elementPanel() {
    final l = sel;
    if (l == null)
      return _card(
        'Element',
        Text(
          'Select something on the page to edit it: change its text, font, colors, photo, shape and position.',
          style: sans(13.5, h: 1.45),
        ),
      );
    final pal = design.pal;
    return _card(
      _label(l),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              OutlineBtn(
                'Duplicate',
                icon: Icons.copy_rounded,
                height: 36,
                onTap: () => _duplicate(l),
              ),
              OutlineBtn(
                '',
                icon: Icons.flip_to_front_rounded,
                height: 36,
                onTap: () => _z(l, 1),
              ),
              OutlineBtn(
                '',
                icon: Icons.flip_to_back_rounded,
                height: 36,
                onTap: () => _z(l, -1),
              ),
              OutlineBtn(
                'Delete',
                icon: Icons.delete_outline_rounded,
                height: 36,
                onTap: () => _delete(l),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ..._props(l, pal),
          const SizedBox(height: 4),
          _slider(
            'Rotation',
            l.rot,
            -180,
            180,
            (v) => _live(
              () => l.content['r'] = double.parse(v.toStringAsFixed(1)),
            ),
            suffix: '°',
          ),
          _slider(
            'Opacity',
            l.n('o', 1),
            .1,
            1,
            (v) => _live(
              () => l.content['o'] = double.parse(v.toStringAsFixed(2)),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _props(EventBlock l, Pal pal) {
    switch (l.kind) {
      case 'text':
        final bound = (l.str('b') ?? '').isNotEmpty;
        return [
          SelectBox<String>(
            label: 'Content',
            value: bound ? l.str('b') : '',
            options: _bindChoices,
            onChanged: (v) => _change(() {
              if (v == null || v.isEmpty) {
                l.content.remove('b');
              } else {
                l.content['b'] = v;
              }
            }),
            anyLabel: 'Custom text',
          ),
          const SizedBox(height: 10),
          if (!bound)
            _TextInput(
              key: ValueKey('t${l.id}'),
              initial: l.str('tx') ?? '',
              onChanged: (v) => _live(() => l.content['tx'] = v),
              onDone: _commit,
            ),
          if (!bound) const SizedBox(height: 10),
          SelectBox<String>(
            label: 'Font',
            value: l.str('f') ?? 'Playfair Display',
            options: [for (final f in editorFonts) (f, f)],
            onChanged: (v) =>
                _change(() => l.content['f'] = v ?? 'Playfair Display'),
            anyLabel: 'Playfair Display',
          ),
          _slider(
            'Size',
            l.n('s', .05),
            .015,
            .32,
            (v) => _live(
              () => l.content['s'] = double.parse(v.toStringAsFixed(3)),
            ),
          ),
          _slider(
            'Letter spacing',
            l.n('ls'),
            0,
            .5,
            (v) => _live(
              () => l.content['ls'] = double.parse(v.toStringAsFixed(2)),
            ),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _chip(
                'Light',
                l.n('wt', 500) < 400,
                () => _change(() => l.content['wt'] = 300),
              ),
              _chip(
                'Regular',
                l.n('wt', 500) >= 400 && l.n('wt', 500) < 500,
                () => _change(() => l.content['wt'] = 400),
              ),
              _chip(
                'Medium',
                l.n('wt', 500) >= 500 && l.n('wt', 500) < 700,
                () => _change(() => l.content['wt'] = 500),
              ),
              _chip(
                'Bold',
                l.n('wt', 500) >= 700,
                () => _change(() => l.content['wt'] = 700),
              ),
              _chip(
                'Italic',
                l.flag('i'),
                () => _change(() => l.content['i'] = !l.flag('i')),
              ),
              _chip(
                'UPPERCASE',
                l.flag('u'),
                () => _change(() => l.content['u'] = !l.flag('u')),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                'Align',
                style: sans(13, w: FontWeight.w500, color: C.ink),
              ),
              const Spacer(),
              for (final (k, ic) in const [
                ('left', Icons.format_align_left_rounded),
                ('center', Icons.format_align_center_rounded),
                ('right', Icons.format_align_right_rounded),
              ])
                IconButton(
                  onPressed: () => _change(() => l.content['a'] = k),
                  icon: Icon(
                    ic,
                    size: 20,
                    color: (l.str('a') ?? 'center') == k ? C.brand : C.body,
                  ),
                ),
            ],
          ),
          _colors(
            'Color',
            pal,
            l.str('c') ?? 'ink',
            (v) => _change(() => l.content['c'] = v),
          ),
        ];
      case 'photo':
        final has = (l.str('url') ?? '').isNotEmpty;
        return [
          Row(
            children: [
              Expanded(
                child: PrimaryButton(
                  has ? 'Change photo' : 'Upload photo',
                  icon: Icons.upload_rounded,
                  height: 42,
                  busy: uploading,
                  onTap: () => _pickPhoto(l),
                ),
              ),
              if (has) ...[
                const SizedBox(width: 8),
                OutlineBtn(
                  'Remove',
                  height: 42,
                  onTap: () => _change(() => l.content.remove('url')),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Shape',
            style: sans(13, w: FontWeight.w500, color: C.ink),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in _shapeChoices)
                _chip(
                  s.$2,
                  (l.str('sh') ?? 'rect') == s.$1 && !l.flag('pol'),
                  () => _change(() {
                    l.content['sh'] = s.$1;
                    l.content.remove('pol');
                  }),
                ),
              _chip(
                'Polaroid',
                l.flag('pol'),
                () => _change(() {
                  l.content['pol'] = !l.flag('pol');
                  if (l.flag('pol')) l.content['bw'] = .03;
                }),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _slider(
            'Border',
            l.n('bw'),
            0,
            .06,
            (v) => _live(
              () => l.content['bw'] = double.parse(v.toStringAsFixed(3)),
            ),
          ),
          _colors(
            'Border color',
            pal,
            l.str('bc') ?? 'white',
            (v) => _change(() => l.content['bc'] = v),
          ),
          if (has) ...[
            _slider(
              'Zoom',
              l.n('z', 1),
              1,
              3,
              (v) => _live(
                () => l.content['z'] = double.parse(v.toStringAsFixed(2)),
              ),
            ),
            _slider(
              'Move photo ↔',
              l.n('fx'),
              -1,
              1,
              (v) => _live(
                () => l.content['fx'] = double.parse(v.toStringAsFixed(2)),
              ),
            ),
            _slider(
              'Move photo ↕',
              l.n('fy'),
              -1,
              1,
              (v) => _live(
                () => l.content['fy'] = double.parse(v.toStringAsFixed(2)),
              ),
            ),
          ],
        ];
      case 'shape':
        return [
          Text(
            'Shape',
            style: sans(13, w: FontWeight.w500, color: C.ink),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in _shapeChoices)
                _chip(
                  s.$2,
                  (l.str('sh') ?? 'rect') == s.$1,
                  () => _change(() => l.content['sh'] = s.$1),
                ),
            ],
          ),
          const SizedBox(height: 8),
          _colors(
            'Fill',
            pal,
            l.str('fl') ?? 'soft',
            (v) => _change(() => l.content['fl'] = v),
            allowNone: true,
          ),
          _colors(
            'Outline',
            pal,
            l.str('sc') ?? 'none',
            (v) => _change(() {
              if (v == 'none') {
                l.content.remove('sc');
              } else {
                l.content['sc'] = v;
                if (l.n('sw') == 0) l.content['sw'] = .004;
              }
            }),
            allowNone: true,
          ),
          _slider(
            'Outline width',
            l.n('sw'),
            0,
            .03,
            (v) => _live(
              () => l.content['sw'] = double.parse(v.toStringAsFixed(4)),
            ),
          ),
          if ((l.str('sh') ?? 'rect') == 'round')
            _slider(
              'Corner radius',
              l.n('rd', .14),
              0,
              .5,
              (v) => _live(
                () => l.content['rd'] = double.parse(v.toStringAsFixed(2)),
              ),
            ),
        ];
      case 'deco':
        return [
          SelectBox<String>(
            label: 'Style',
            value: l.str('k') ?? 'flowers',
            options: [for (final k in decoKinds.entries) (k.key, k.value)],
            onChanged: (v) => _change(() => l.content['k'] = v ?? 'flowers'),
            anyLabel: 'Flowers',
          ),
          const SizedBox(height: 10),
          _colors(
            'Color 1',
            pal,
            l.str('c1') ?? 'accent',
            (v) => _change(() => l.content['c1'] = v),
          ),
          _colors(
            'Color 2',
            pal,
            l.str('c2') ?? 'accent2',
            (v) => _change(() => l.content['c2'] = v),
          ),
          _colors(
            'Color 3',
            pal,
            l.str('c3') ?? 'soft',
            (v) => _change(() => l.content['c3'] = v),
          ),
          const SizedBox(height: 4),
          OutlineBtn(
            'Shuffle arrangement',
            icon: Icons.shuffle_rounded,
            height: 38,
            onTap: () =>
                _change(() => l.content['sd'] = math.Random().nextInt(900) + 1),
          ),
        ];
      case 'rsvp':
        return [
          _TextInput(
            key: ValueKey('r${l.id}'),
            initial: l.str('lb') ?? 'Confirm attendance',
            label: 'Button label',
            maxLines: 1,
            onChanged: (v) => _live(() => l.content['lb'] = v),
            onDone: _commit,
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _chip(
                'Solid',
                (l.str('st') ?? 'solid') == 'solid',
                () => _change(() => l.content['st'] = 'solid'),
              ),
              _chip(
                'Outline',
                l.str('st') == 'outline',
                () => _change(() => l.content['st'] = 'outline'),
              ),
              _chip(
                'Pill',
                (l.str('sh') ?? 'pill') == 'pill',
                () => _change(() => l.content['sh'] = 'pill'),
              ),
              _chip(
                'Square',
                l.str('sh') == 'rect',
                () => _change(() => l.content['sh'] = 'rect'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SelectBox<String>(
            label: 'Font',
            value: l.str('f') ?? 'Inter',
            options: [for (final f in editorFonts) (f, f)],
            onChanged: (v) => _change(() => l.content['f'] = v ?? 'Inter'),
            anyLabel: 'Inter',
          ),
          _slider(
            'Text size',
            l.n('s', .038),
            .02,
            .1,
            (v) => _live(
              () => l.content['s'] = double.parse(v.toStringAsFixed(3)),
            ),
          ),
          _colors(
            'Color',
            pal,
            l.str('c') ?? 'accent',
            (v) => _change(() => l.content['c'] = v),
          ),
        ];
      case 'qr':
        return [
          Text(
            'Guests can scan this code to open the invitation. Resize it as you like; it stays square.',
            style: sans(13, h: 1.4),
          ),
        ];
    }
    return const [];
  }

  Widget _slider(
    String label,
    double v,
    double min,
    double max,
    ValueChanged<double> onChanged, {
    String suffix = '',
  }) => Row(
    children: [
      SizedBox(
        width: 112,
        child: Text(
          label,
          overflow: TextOverflow.ellipsis,
          style: sans(12.5, color: C.ink),
        ),
      ),
      Expanded(
        child: SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: C.brand,
            inactiveTrackColor: const Color(0xFFEDEBEA),
            thumbColor: C.brand,
            trackHeight: 4,
            overlayShape: SliderComponentShape.noOverlay,
          ),
          child: Slider(
            value: v.clamp(min, max),
            min: min,
            max: max,
            onChanged: onChanged,
            onChangeEnd: (_) => _commit(),
          ),
        ),
      ),
    ],
  );

  Widget _colors(
    String label,
    Pal pal,
    String value,
    ValueChanged<String> onPick, {
    bool allowNone = false,
  }) {
    final roles = [
      'accent',
      'accent2',
      'ink',
      'soft',
      'bg',
      'white',
      'black',
      if (allowNone) 'none',
    ];
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: sans(12.5, w: FontWeight.w500, color: C.ink),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final r in roles)
                GestureDetector(
                  onTap: () => onPick(r),
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: r == 'none' ? Colors.white : pal.role(r),
                      border: Border.all(
                        color: value == r ? C.ink : C.line,
                        width: value == r ? 2.4 : 1,
                      ),
                    ),
                    child: r == 'none'
                        ? const Icon(
                            Icons.block_rounded,
                            size: 16,
                            color: C.muted,
                          )
                        : null,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------ page settings
  Widget _pagePanel() {
    final palettes = widget.c.palettes
        .where((p) => toneFilter == 'all' || p.tone == toneFilter)
        .toList();
    return Column(
      children: [
        _card(
          'Color combination',
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  for (final r in [
                    design.pal.bg,
                    design.pal.soft,
                    design.pal.accent,
                    design.pal.accent2,
                    design.pal.ink,
                  ])
                    Container(
                      width: 34,
                      height: 34,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: r,
                        shape: BoxShape.circle,
                        border: Border.all(color: C.line),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final (k, l) in const [
                    ('all', 'All'),
                    ('light', 'Light'),
                    ('dark', 'Dark'),
                    ('vivid', 'Vivid'),
                  ])
                    _chip(
                      l,
                      toneFilter == k,
                      () => setState(() => toneFilter = k),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '${palettes.length} combinations',
                style: sans(12, color: C.muted),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 300,
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 78,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 1.15,
                  ),
                  itemCount: palettes.length,
                  itemBuilder: (context, i) {
                    final p = palettes[i];
                    final on = p.pal == design.pal;
                    return Tooltip(
                      message: p.name,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => _change(
                          () => design = PageDesign(
                            pal: p.pal,
                            height: design.height,
                            gradient: design.gradient,
                          ),
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            color: p.pal.bg,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: on ? C.brand : C.line,
                              width: on ? 2.2 : 1,
                            ),
                          ),
                          padding: const EdgeInsets.all(6),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  for (final c in [
                                    p.pal.accent,
                                    p.pal.accent2,
                                    p.pal.soft,
                                  ])
                                    Container(
                                      width: 14,
                                      height: 14,
                                      margin: const EdgeInsets.symmetric(
                                        horizontal: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: c,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Container(
                                height: 4,
                                width: 34,
                                decoration: BoxDecoration(
                                  color: p.pal.ink,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _card(
          'Page',
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _slider(
                'Page length',
                design.height,
                1.2,
                6,
                (v) => _live(
                  () => design = PageDesign(
                    pal: design.pal,
                    height: v,
                    gradient: design.gradient,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Soft gradient background',
                      style: sans(13.5, color: C.ink),
                    ),
                  ),
                  Switch(
                    value: design.gradient,
                    onChanged: (v) => _change(
                      () => design = PageDesign(
                        pal: design.pal,
                        height: design.height,
                        gradient: v,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              OutlineBtn(
                'Reset to original template',
                icon: Icons.restart_alt_rounded,
                expand: true,
                onTap: _resetToTemplate,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Text field that keeps its own controller (so the cursor never jumps while typing).
class _TextInput extends StatefulWidget {
  final String initial;
  final String label;
  final int maxLines;
  final ValueChanged<String> onChanged;
  final VoidCallback onDone;
  const _TextInput({
    super.key,
    required this.initial,
    required this.onChanged,
    required this.onDone,
    this.label = 'Text',
    this.maxLines = 3,
  });
  @override
  State<_TextInput> createState() => _TextInputState();
}

class _TextInputState extends State<_TextInput> {
  late final ctl = TextEditingController(text: widget.initial);
  @override
  void dispose() {
    ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Focus(
    onFocusChange: (f) {
      if (!f) widget.onDone();
    },
    child: Field(
      widget.label,
      ctl,
      maxLines: widget.maxLines,
      onChanged: widget.onChanged,
    ),
  );
}
