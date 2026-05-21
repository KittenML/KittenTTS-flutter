import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../kitten_tts_error.dart';

Future<Uint8List> readNPZBytes(String source) async {
  final uri = Uri.tryParse(source);
  if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
    try {
      final response = await http.get(uri);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw KittenTTSError.voicesFileNotFound(source);
      }
      return response.bodyBytes;
    } catch (error) {
      if (error is KittenTTSError) rethrow;
      throw KittenTTSError.invalidModelData(
        'Could not load voice embeddings from $source: ${errorMessage(error)}',
        error,
      );
    }
  }

  final assetKey = source.startsWith('asset://')
      ? source.substring('asset://'.length)
      : source;
  try {
    final data = await rootBundle.load(assetKey);
    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  } catch (_) {
    throw KittenTTSError.voicesFileNotFound(source);
  }
}
