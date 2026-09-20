import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart' as web;

void saveFile(Uint8List bytes, String name, String mime) {
  final blob = web.Blob([bytes.toJS].toJS, web.BlobPropertyBag(type: mime));
  final url = web.URL.createObjectURL(blob);
  final a = web.HTMLAnchorElement()
    ..href = url
    ..download = name;
  a.click();
  web.URL.revokeObjectURL(url);
}
