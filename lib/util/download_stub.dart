import 'dart:typed_data';

/// Saving files is only implemented for the web build.
void saveFile(Uint8List bytes, String name, String mime) =>
    throw UnsupportedError('Downloads are available in the web app.');
