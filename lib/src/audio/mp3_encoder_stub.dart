import 'dart:typed_data';

class MP3Encoder {
  static Future<Uint8List> encode(
    Float32List samples,
    int sampleRate, {
    int bitRate = 128,
  }) {
    throw UnsupportedError(
      'MP3 encoding is not bundled because the available Flutter MP3 encoder '
      'packages use GPL/LGPL codec code. Use wavData() or provide an app-level '
      'MP3 encoder.',
    );
  }
}
