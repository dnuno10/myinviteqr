import 'package:url_launcher/url_launcher.dart';

/// Leaves the app for [url] (Stripe Checkout).
Future<void> goToUrl(String url) async {
  await launchUrl(Uri.parse(url));
}

/// Removes the query string from the address bar (web only).
void clearQuery() {}
