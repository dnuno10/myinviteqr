import 'dart:async';
import 'package:flutter/material.dart';
import '../data/backend.dart';
import '../theme/app_theme.dart';
import '../util/browser.dart';
import '../widgets/celebration.dart';
import '../widgets/common.dart';
import 'event_detail.dart';

/// Where Stripe sends the customer after paying. The webhook is what publishes the event, so this
/// screen waits (a few seconds at most) until the order shows as paid, then opens the event.
class CheckoutReturnScreen extends StatefulWidget {
  final String orderId;
  final String? eventId;
  final String kind;
  const CheckoutReturnScreen({
    super.key,
    required this.orderId,
    required this.eventId,
    required this.kind,
  });
  @override
  State<CheckoutReturnScreen> createState() => _CheckoutReturnScreenState();
}

class _CheckoutReturnScreenState extends State<CheckoutReturnScreen> {
  Timer? timer;
  int tries = 0;
  bool timedOut = false, failed = false, done = false;
  String? message;

  @override
  void initState() {
    super.initState();
    clearQuery();
    _poll();
    timer = Timer.periodic(const Duration(seconds: 2), (_) => _poll());
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Future<void> _poll() async {
    if (done) return;
    tries++;
    try {
      final o = await Backend.i.orderStatus(widget.orderId);
      if (!mounted || done) return;
      if (o != null && o.paid) {
        done = true;
        timer?.cancel();
        await _finish(o.eventId ?? widget.eventId);
        return;
      }
      if (o != null && o.status == 'refunded') {
        _stop(failed: true, message: 'This payment was refunded.');
        return;
      }
    } catch (_) {
      // keep trying: the network may be flaky for a moment
    }
    if (tries >= 45 && mounted) {
      _stop(timedOut: true);
    }
  }

  void _stop({bool failed = false, bool timedOut = false, String? message}) {
    timer?.cancel();
    setState(() {
      this.failed = failed;
      this.timedOut = timedOut;
      this.message = message;
    });
  }

  Future<void> _finish(String? eventId) async {
    if (eventId == null) return _home();
    try {
      final ev = await Backend.i.event(eventId);
      if (!mounted) return;
      final nav = Navigator.of(context);
      if (widget.kind == 'publish') {
        final plans = await Backend.i.plans();
        final plan = plans.where((p) => p.code == ev.plan).firstOrNull;
        if (!mounted) return;
        await showPublishedDialog(
          context,
          ev,
          planName: plan?.name ?? 'Premium',
        );
      } else if (mounted) {
        toast(context, 'Your invitation was extended.');
      }
      if (!mounted) return;
      nav.pushReplacement(
        MaterialPageRoute(builder: (_) => EventDetailScreen(eventId: ev.id)),
      );
    } catch (_) {
      _home();
    }
  }

  void _home() {
    if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: C.bg,
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: AppCard(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Logo(height: 44),
                const SizedBox(height: 28),
                if (!timedOut && !failed) ...[
                  const CircularProgressIndicator(color: C.brand),
                  const SizedBox(height: 22),
                  Text('Confirming your payment…', style: serif(22)),
                  const SizedBox(height: 8),
                  Text(
                    'This only takes a few seconds. Please don’t close this page.',
                    textAlign: TextAlign.center,
                    style: sans(14, color: C.muted),
                  ),
                ] else ...[
                  Icon(
                    failed
                        ? Icons.error_outline_rounded
                        : Icons.hourglass_bottom_rounded,
                    size: 40,
                    color: failed ? C.red : C.amber,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    failed ? 'Something went wrong' : 'Still confirming…',
                    style: serif(22),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message ??
                        'Your payment was received, but the confirmation is taking longer than usual. Your event will be published automatically in a moment.',
                    textAlign: TextAlign.center,
                    style: sans(14, color: C.muted, h: 1.4),
                  ),
                  const SizedBox(height: 22),
                  if (!failed)
                    PrimaryButton(
                      'Check again',
                      onTap: () {
                        setState(() {
                          timedOut = false;
                          tries = 0;
                        });
                        timer = Timer.periodic(
                          const Duration(seconds: 2),
                          (_) => _poll(),
                        );
                        _poll();
                      },
                    ),
                  if (!failed) const SizedBox(height: 10),
                  OutlineBtn('Go to my events', expand: true, onTap: _home),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
