// Dev tool for the marketing site: renders ONE template with the real engine.
// flutter build web -t tool/site_render.dart -o /tmp/sr
//   ?i=0&title=Sofia&sub=...&mode=thumb  (thumb = 4:5 top crop, tall = phone-height page)
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:myinviteqr/data/models.dart';
import 'package:myinviteqr/theme/app_theme.dart';
import 'package:myinviteqr/widgets/invitation.dart';
import 'templates_data.dart';

void main() => runApp(const _App());

class _App extends StatelessWidget {
  const _App();
  @override
  Widget build(BuildContext context) {
    final q = Uri.base.queryParameters;
    final i = int.tryParse(q['i'] ?? '') ?? 0;
    final mode = q['mode'] ?? 'thumb';
    final d = (jsonDecode(kTemplatesJson) as List).cast<Map<String, dynamic>>()[i];
    final t = Template.fromJson({
      'id': 'p$i',
      'name': d['name'],
      'style': d['style'],
      'min_plan': 'essential',
      'status': 'published',
      'category_id': null,
      'languages': d['languages'],
      'themes': d['themes'],
      'layout': d['layout'],
    });
    final ev = previewEvent(
      title: q['title'] ?? 'Sofia & Daniel',
      date: DateTime(2026, 10, 19, 18),
      venue: q['venue'] ?? 'Garden Las Flores',
      address: q['addr'] ?? '123 Rose Avenue',
    );
    final size = MediaQuery.sizeOf(context);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: Scaffold(
        backgroundColor: t.layout.design.pal.bg,
        body: LayoutBuilder(
          builder: (context, c) => ClipRect(
            child: OverflowBox(
              alignment: Alignment.topCenter,
              minHeight: 0,
              maxHeight: double.infinity,
              child: SizedBox(
                width: c.maxWidth,
                child: InvitationPage(
                  event: ev,
                  design: t.layout.design,
                  layers: templateLayers(t),
                  url: 'https://myinviteqr.com',
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
