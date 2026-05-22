import 'dart:typed_data';

import 'package:archive/archive.dart';

import '../kitten_tts_error.dart';
import 'npz_file_reader.dart';

class VoiceEmbedding {
  const VoiceEmbedding({
    required this.rows,
    required this.cols,
    required this.data,
  });

  final int rows;
  final int cols;
  final Float32List data;
}

typedef VoiceEmbeddings = Map<String, VoiceEmbedding>;

Future<VoiceEmbeddings> loadNPZ(String filePath) async {
  try {
    return loadNPZData(await readNPZBytes(filePath), source: filePath);
  } catch (error) {
    if (error is KittenTTSError) rethrow;
    throw KittenTTSError.invalidModelData(
      'Could not load voice embeddings from $filePath: ${errorMessage(error)}',
      error,
    );
  }
}

VoiceEmbeddings loadNPZData(Uint8List data,
    {String source = 'provided voice data'}) {
  final archive = ZipDecoder().decodeBytes(data);
  final result = <String, VoiceEmbedding>{};
  for (final file in archive.files) {
    if (!file.isFile || !file.name.endsWith('.npy')) continue;
    final bytes = file.content;
    final embedding = _parseNPY(bytes);
    if (embedding != null) {
      result[file.name.substring(0, file.name.length - 4)] = embedding;
    }
  }
  if (result.isEmpty) {
    throw KittenTTSError.invalidModelData(
        'No voice embeddings were found in $source');
  }
  return result;
}

VoiceEmbedding? _parseNPY(Uint8List data) {
  if (data.length < 10) return null;
  if (data[0] != 0x93 ||
      data[1] != 0x4e ||
      data[2] != 0x55 ||
      data[3] != 0x4d ||
      data[4] != 0x50 ||
      data[5] != 0x59) {
    return null;
  }
  final major = data[6];
  final view = ByteData.sublistView(data);
  final headerBase = major >= 2 ? 12 : 10;
  final headerLen = major >= 2
      ? view.getUint32(8, Endian.little)
      : view.getUint16(8, Endian.little);
  if (headerBase + headerLen > data.length) return null;

  final header =
      String.fromCharCodes(data.sublist(headerBase, headerBase + headerLen));
  final shape = _parseShape(header);
  if (shape.isEmpty) return null;
  final raw = data.sublist(headerBase + headerLen);
  if (header.contains("'f4'") ||
      header.contains('<f4') ||
      header.contains('>f4')) {
    return _makeFloat32Embedding(raw, shape, header.contains('>f4'));
  }
  if (header.contains("'f2'") ||
      header.contains('<f2') ||
      header.contains('>f2')) {
    return _makeFloat16Embedding(raw, shape, header.contains('>f2'));
  }
  return null;
}

List<int> _parseShape(String header) {
  final start = header.indexOf('(');
  final end = header.indexOf(')', start);
  if (start < 0 || end < 0) return const [];
  final inside = header.substring(start + 1, end).trim();
  if (inside.isEmpty) return const [1];
  return inside
      .split(',')
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .map(int.parse)
      .toList();
}

VoiceEmbedding _makeFloat32Embedding(
  Uint8List raw,
  List<int> shape,
  bool bigEndian,
) {
  final count = raw.length ~/ 4;
  final floats = Float32List(count);
  final view = ByteData.sublistView(raw);
  for (var i = 0; i < count; i += 1) {
    floats[i] = view.getFloat32(i * 4, bigEndian ? Endian.big : Endian.little);
  }
  return VoiceEmbedding(
    rows: shape.length >= 2 ? shape[0] : 1,
    cols: shape.length >= 2 ? shape[1] : shape[0],
    data: floats,
  );
}

VoiceEmbedding _makeFloat16Embedding(
  Uint8List raw,
  List<int> shape,
  bool bigEndian,
) {
  final count = raw.length ~/ 2;
  final floats = Float32List(count);
  final view = ByteData.sublistView(raw);
  for (var i = 0; i < count; i += 1) {
    final bits = view.getUint16(i * 2, bigEndian ? Endian.big : Endian.little);
    floats[i] = _float16ToFloat(bits);
  }
  return VoiceEmbedding(
    rows: shape.length >= 2 ? shape[0] : 1,
    cols: shape.length >= 2 ? shape[1] : shape[0],
    data: floats,
  );
}

double _float16ToFloat(int bits) {
  final sign = (bits & 0x8000) != 0 ? -1.0 : 1.0;
  final exp = (bits >> 10) & 0x1f;
  final mant = bits & 0x03ff;
  if (exp == 0) {
    if (mant == 0) return sign * 0.0;
    return sign * _pow2(-14) * (mant / 1024.0);
  }
  if (exp == 31) {
    return mant == 0 ? sign * double.infinity : double.nan;
  }
  return sign * _pow2(exp - 15) * (1 + mant / 1024.0);
}

double _pow2(int exponent) {
  if (exponent == 0) return 1;
  var value = 1.0;
  if (exponent > 0) {
    for (var i = 0; i < exponent; i += 1) {
      value *= 2;
    }
  } else {
    for (var i = 0; i < -exponent; i += 1) {
      value /= 2;
    }
  }
  return value;
}
