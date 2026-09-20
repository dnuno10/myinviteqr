import 'package:web/web.dart' as web;

/// Leaves the app for [url] in the same tab (Stripe Checkout).
Future<void> goToUrl(String url) async {
  web.window.location.assign(url);
}

/// Removes the query string from the address bar so a refresh does not repeat the payment return.
void clearQuery() {
  web.window.history.replaceState(null, '', web.window.location.pathname);
}
