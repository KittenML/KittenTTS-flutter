import 'dart:typed_data';

class WAVEncoder {
  static Uint8List encode(Float32List samples, int sampleRate) {
    const numChannels = 1;
    const bitsPerSample = 16;
    const blockAlign = 2;
    final byteRate = sampleRate * blockAlign;
    final dataBytes = samples.length * blockAlign;
    final buffer = Uint8List(44 + dataBytes);
    final data = ByteData.sublistView(buffer);
    var offset = 0;

    offset = _writeString(buffer, offset, 'RIFF');
    data.setUint32(offset, 36 + dataBytes, Endian.little);
    offset += 4;
    offset = _writeString(buffer, offset, 'WAVE');
    offset = _writeString(buffer, offset, 'fmt ');
    data.setUint32(offset, 16, Endian.little);
    offset += 4;
    data.setUint16(offset, 1, Endian.little);
    offset += 2;
    data.setUint16(offset, numChannels, Endian.little);
    offset += 2;
    data.setUint32(offset, sampleRate, Endian.little);
    offset += 4;
    data.setUint32(offset, byteRate, Endian.little);
    offset += 4;
    data.setUint16(offset, blockAlign, Endian.little);
    offset += 2;
    data.setUint16(offset, bitsPerSample, Endian.little);
    offset += 2;
    offset = _writeString(buffer, offset, 'data');
    data.setUint32(offset, dataBytes, Endian.little);
    offset += 4;

    for (final sample in samples) {
      final clamped = sample.clamp(-1.0, 1.0);
      data.setInt16(offset, (clamped * 32767).round(), Endian.little);
      offset += 2;
    }

    return buffer;
  }
}

int _writeString(Uint8List buffer, int offset, String value) {
  for (var i = 0; i < value.length; i += 1) {
    buffer[offset + i] = value.codeUnitAt(i);
  }
  return offset + value.length;
}
