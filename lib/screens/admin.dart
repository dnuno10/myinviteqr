import 'package:flutter/material.dart';
import '../data/backend.dart';
import '../data/models.dart';
import '../theme/app_theme.dart';
import '../util/format.dart';
import '../widgets/common.dart';
import '../widgets/responsive.dart';
import '../widgets/shell.dart';

/// Internal administration. Every number comes from the database; access is enforced by RLS.
class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});
  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _Data {
  final AdminKpis kpis;
  final Map<String, int> sales;
  final List<Map<String, dynamic>> templates;
  final List<AdminTicket> tickets;
  _Data(this.kpis, this.sales, this.templates, this.tickets);
}

class _AdminScreenState extends State<AdminScreen> {
  late Future<_Data> future = _load();

  Future<_Data> _load() async {
    final r = await Future.wait([
      Backend.i.adminKpis(),
      Backend.i.adminSales(),
      Backend.i.adminTemplates(),
      Backend.i.adminTickets(),
    ]);
    return _Data(
      r[0] as AdminKpis,
      r[1] as Map<String, int>,
      r[2] as List<Map<String, dynamic>>,
      r[3] as List<AdminTicket>,
    );
  }

  void _reload() => setState(() {
    future = _load();
  });

  @override
  Widget build(BuildContext context) => AppShell(
    admin: true,
    child: ValueListenableBuilder<Profile?>(
      valueListenable: profileNotifier,
      builder: (context, p, _) {
        if (!(p?.isAdmin ?? false))
          return Center(
            child: Text(
              'You do not have access to this area.',
              style: sans(14),
            ),
          );
        return FutureBuilder<_Data>(
          future: future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done)
              return const LoadingView();
            if (snap.hasError)
              return ErrorView(errText(snap.error!), onRetry: _reload);
            return _body(snap.data!);
          },
        );
      },
    ),
  );

  Widget _body(_Data d) {
    final k = d.kpis;
    final prev = k.i('sales_prev_cents');
    final change = prev == 0
        ? null
        : ((k.i('sales_cents') - prev) * 100 / prev).round();
    return PageBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageTitle(
            'Administration',
            'Manage templates, sales, support and expirations.',
          ),
          const SizedBox(height: 22),
          AutoGrid(
            minTile: 210,
            gap: 14,
            children: [
              _kpi(
                Icons.attach_money_rounded,
                'Sales this month',
                money(k.i('sales_cents')),
                change == null
                    ? '${k.i('orders_month')} orders'
                    : '${change >= 0 ? '+' : ''}$change% · ${k.i('orders_month')} orders',
              ),
              _kpi(
                Icons.description_outlined,
                'Published events',
                '${k.i('published_month')}',
                'This month · ${k.i('published_total')} total',
              ),
              _kpi(
                Icons.autorenew_rounded,
                'Extensions',
                '${k.i('extensions_month')}',
                'This month',
              ),
              _kpi(
                Icons.history_rounded,
                'Refunds',
                '${k.i('refunds_month')}',
                'This month',
              ),
              _kpi(
                Icons.headset_mic_outlined,
                'Open tickets',
                '${k.i('open_tickets')}',
                'Support & moderation',
              ),
            ],
          ),
          const SizedBox(height: 18),
          AdaptiveRow(
            breakpoint: 1000,
            gap: 18,
            flex: const [1, 1],
            children: [_templates(d), _tickets(d)],
          ),
          const SizedBox(height: 18),
          AdaptiveRow(
            breakpoint: 1000,
            gap: 18,
            flex: const [1, 1],
            children: [_sales(d), _expirations(k)],
          ),
        ],
      ),
    );
  }

  Widget _kpi(IconData i, String l, String v, String sub) => AppCard(
    padding: const EdgeInsets.all(18),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(i, size: 28, color: C.brand),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l, overflow: TextOverflow.ellipsis, style: sans(12.5)),
              const SizedBox(height: 4),
              Text(v, style: serif(26)),
              Text(sub, overflow: TextOverflow.ellipsis, style: sans(12.5)),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _templates(_Data d) => AppCard(
    padding: const EdgeInsets.all(20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HeaderRow(
          'Template management',
          trailing: Pill(
            '${d.templates.length} templates',
            fg: C.body,
            bg: const Color(0xFFF1EEED),
          ),
        ),
        const SizedBox(height: 10),
        if (d.templates.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('No templates.', style: sans(14)),
          ),
        for (final t in d.templates.take(30))
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: C.line)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t['name'] as String,
                        overflow: TextOverflow.ellipsis,
                        style: sans(13.5, w: FontWeight.w600, color: C.ink),
                      ),
                      Text(
                        '${t['style']} · ${((t['themes'] as List?) ?? const []).take(3).join(', ')} · ${(t['languages'] as List).join('/').toUpperCase()}',
                        overflow: TextOverflow.ellipsis,
                        style: sans(12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                PopupMenuButton<String>(
                  tooltip: '',
                  color: Colors.white,
                  onSelected: (s) async {
                    try {
                      await Backend.i.adminSetTemplateStatus(
                        t['id'] as String,
                        s,
                      );
                      _reload();
                    } catch (e) {
                      if (mounted) toast(context, errText(e), error: true);
                    }
                  },
                  itemBuilder: (_) => [
                    for (final s in const [
                      'draft',
                      'in_review',
                      'published',
                      'retired',
                    ])
                      PopupMenuItem(
                        value: s,
                        child: Text(s.replaceAll('_', ' '), style: sans(14)),
                      ),
                  ],
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Dot(switch (t['status']) {
                        'published' => C.green,
                        'draft' => C.amber,
                        'in_review' => C.purple,
                        _ => C.muted,
                      }),
                      const SizedBox(width: 6),
                      Text(
                        (t['status'] as String).replaceAll('_', ' '),
                        style: sans(12.5, w: FontWeight.w500, color: C.ink),
                      ),
                      const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
  );

  Widget _tickets(_Data d) => AppCard(
    padding: const EdgeInsets.all(20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Support and moderation queue', style: serif(19)),
        const SizedBox(height: 10),
        if (d.tickets.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('The queue is empty.', style: sans(14, color: C.muted)),
          ),
        for (final t in d.tickets)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: C.line)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            t.title,
                            style: sans(13.5, w: FontWeight.w600, color: C.ink),
                          ),
                          Pill(
                            t.kind,
                            fg: C.purple,
                            bg: const Color(0xFFEDEAFB),
                          ),
                          Text(
                            fmtAgo(t.createdAt),
                            style: sans(11.5, color: C.muted),
                          ),
                        ],
                      ),
                      if ((t.body ?? '').isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Text(
                            t.body!,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: sans(12.5),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                OutlineBtn(
                  'Resolve',
                  height: 34,
                  onTap: () async {
                    try {
                      await Backend.i.adminResolveTicket(t.id);
                      _reload();
                    } catch (e) {
                      if (mounted) toast(context, errText(e), error: true);
                    }
                  },
                ),
              ],
            ),
          ),
      ],
    ),
  );

  Widget _sales(_Data d) {
    final total = d.sales.values.fold<int>(0, (a, b) => a + b);
    const colors = {
      'Essential': Color(0xFFF4A6B4),
      'Premium': C.brand,
      'Extension': Color(0xFFC79BAA),
      'Keepsake': Color(0xFF9B59B6),
    };
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Sales by plan', style: serif(19)),
          Text('Last 30 days · paid orders', style: sans(12.5, color: C.muted)),
          const SizedBox(height: 12),
          Text(money(total), style: serif(30)),
          const SizedBox(height: 12),
          if (d.sales.isEmpty)
            Text(
              'No paid orders yet. Orders appear here once payments are connected.',
              style: sans(13.5, color: C.muted),
            ),
          for (final e in d.sales.entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: colors[e.key],
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(e.key, style: sans(13, color: C.ink)),
                      ),
                      Text(
                        money(e.value),
                        style: sans(13, w: FontWeight.w600, color: C.ink),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '${(100 * e.value / total).round()}%',
                        style: sans(12.5, color: C.muted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: e.value / total,
                      minHeight: 6,
                      backgroundColor: const Color(0xFFEDEBEA),
                      valueColor: AlwaysStoppedAnimation(
                        colors[e.key] ?? C.brand,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _expirations(AdminKpis k) => AppCard(
    padding: const EdgeInsets.all(20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Expirations', style: serif(19)),
        const SizedBox(height: 10),
        _exp(
          Icons.schedule_rounded,
          C.amber,
          'Expiring in 30–60 days',
          k.i('exp_60'),
        ),
        _exp(
          Icons.schedule_rounded,
          C.amber,
          'Expiring in 7–30 days',
          k.i('exp_30'),
        ),
        _exp(
          Icons.schedule_rounded,
          C.red,
          'Expiring in the next 7 days',
          k.i('exp_7'),
        ),
        _exp(
          Icons.inventory_2_outlined,
          C.ink,
          'Ended (grace or archived)',
          k.i('expired'),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: C.blueSoft,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline_rounded, size: 20, color: C.purple),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Host data is kept for 12 months after an event ends.',
                  style: sans(12, h: 1.4),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _exp(IconData i, Color c, String t, int n) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(
      children: [
        Icon(i, size: 26, color: c),
        const SizedBox(width: 12),
        Expanded(
          child: Text(t, style: sans(13.5, color: C.ink)),
        ),
        Text('$n', style: serif(20)),
      ],
    ),
  );
}
