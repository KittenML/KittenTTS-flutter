import 'dart:io';
import 'dart:typed_data';

import '../kitten_tts_error.dart';

Future<Uint8List> readNPZBytes(String source) async {
  final path = source.startsWith('file://')
      ? source.substring('file://'.length)
      : source;
  final file = File(path);
  if (!await file.exists()) throw KittenTTSError.voicesFileNotFound(source);
  return file.readAsBytes();
}
