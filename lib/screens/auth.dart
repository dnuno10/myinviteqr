import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data/backend.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

/// Email + one-time code sign in. New emails are registered automatically.
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final email = TextEditingController();
  final code = TextEditingController();
  bool codeSent = false, busy = false;
  String? error;
  int cooldown = 0;
  Timer? timer;

  @override
  void dispose() {
    timer?.cancel();
    email.dispose();
    code.dispose();
    super.dispose();
  }

  bool get emailValid =>
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email.text.trim());

  void _startCooldown() {
    timer?.cancel();
    setState(() => cooldown = 60);
    timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => cooldown--);
      if (cooldown <= 0) t.cancel();
    });
  }

  Future<void> _send() async {
    if (!emailValid)
      return setState(() => error = 'Enter a valid email address.');
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await Backend.i.sendCode(email.text.trim().toLowerCase());
      if (!mounted) return;
      setState(() => codeSent = true);
      _startCooldown();
    } catch (e) {
      if (mounted) setState(() => error = errText(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _verify() async {
    final c = code.text.trim();
    if (c.length < 8)
      return setState(() => error = 'Enter the code we emailed you.');
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await Backend.i.verifyCode(email.text.trim().toLowerCase(), c);
      // The root gate reacts to the new session.
    } catch (e) {
      if (mounted)
        setState(() {
          error = errText(e);
          busy = false;
          code.clear();
        });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: C.bg,
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              children: [
                const LogoIcon(height: 96),
                const SizedBox(height: 8),
                const Logo(height: 40),
                const SizedBox(height: 24),
                AppCard(
                  padding: const EdgeInsets.all(26),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        codeSent
                            ? 'Check your email'
                            : 'Sign in or create your account',
                        style: serif(24, h: 1.2),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        codeSent
                            ? 'We sent a one-time code to ${email.text.trim()}. Enter it below to continue.'
                            : 'Enter your email and we will send you a one-time code. No password needed.',
                        style: sans(14, h: 1.45),
                      ),
                      const SizedBox(height: 20),
                      if (!codeSent) ...[
                        Field(
                          'Email',
                          email,
                          hint: 'you@example.com',
                          keyboard: TextInputType.emailAddress,
                          autofocus: true,
                          autofill: const [AutofillHints.email],
                          onSubmitted: (_) => _send(),
                        ),
                        const SizedBox(height: 16),
                        PrimaryButton(
                          'Send code',
                          icon: Icons.arrow_forward_rounded,
                          busy: busy,
                          onTap: _send,
                        ),
                      ] else ...[
                        Text(
                          'Check your spam folder if you don’t see the email.',
                          textAlign: TextAlign.center,
                          style: sans(13.5, w: FontWeight.w700, color: C.ink),
                        ),
                        const SizedBox(height: 16),
                        PinInput(
                          controller: code,
                          onCompleted: (_) => _verify(),
                        ),
                        const SizedBox(height: 16),
                        PrimaryButton(
                          'Verify and continue',
                          icon: Icons.arrow_forward_rounded,
                          busy: busy,
                          onTap: _verify,
                        ),
                        const SizedBox(height: 20),
                        Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          spacing: 24,
                          runSpacing: 14,
                          children: [
                            InkWell(
                              onTap: cooldown > 0 || busy ? null : _send,
                              child: Text(
                                cooldown > 0
                                    ? 'Resend code in ${cooldown}s'
                                    : 'Resend code',
                                style: sans(
                                  13,
                                  w: FontWeight.w600,
                                  color: cooldown > 0 ? C.muted : C.brand,
                                ),
                              ),
                            ),
                            InkWell(
                              onTap: () => setState(() {
                                codeSent = false;
                                code.clear();
                                error = null;
                              }),
                              child: Text(
                                'Use a different email',
                                style: sans(
                                  13,
                                  w: FontWeight.w600,
                                  color: C.body,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (error != null) ...[
                        const SizedBox(height: 14),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.error_outline_rounded,
                              size: 18,
                              color: C.red,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                error!,
                                style: sans(13, color: C.red),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Guests never need an account — they only open the link.',
                  textAlign: TextAlign.center,
                  style: sans(12.5, color: C.muted),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
