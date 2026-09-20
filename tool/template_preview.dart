// Dev tool: renders every generated template with the real engine.
// flutter build web -t tool/template_preview.dart   (then open ?from=0&n=10)
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
    final from = int.tryParse(q['from'] ?? '') ?? 0,
        n = int.tryParse(q['n'] ?? '') ?? 10;
    final w = double.tryParse(q['w'] ?? '') ?? 300;
    final data = (jsonDecode(kTemplatesJson) as List)
        .cast<Map<String, dynamic>>();
    final tpls = [
      for (final (i, d) in data.indexed)
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
    final ev = previewEvent(
      title: 'Sofia & Daniel',
      date: DateTime(2026, 6, 14, 18),
      venue: 'Garden Estate',
      address: '123 Rose Avenue, Mexico City',
    );
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: Scaffold(
        backgroundColor: const Color(0xFFE9E6E4),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: Wrap(
            spacing: 12,
            runSpacing: 16,
            children: [
              for (final t in tpls.skip(from).take(n))
                SizedBox(
                  width: w,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${tpls.indexOf(t) + 1}. ${t.name} · ${t.style} · h=${t.layout.design.height}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      InvitationPage(
                        event: ev,
                        design: t.layout.design,
                        layers: templateLayers(t),
                        url: 'https://myinviteqr.com',
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
