import 'dart:convert';
import 'dart:typed_data';

import 'audio/mp3_encoder.dart';
import 'audio/wav_encoder.dart';
import 'kitten_voice.dart';
import 'kitten_word_timing.dart';

class KittenTTSResult {
  const KittenTTSResult({
    required this.samples,
    required this.sampleRate,
    required this.voice,
    required this.effectiveSpeed,
    required this.inputText,
    this.wordTimings = const [],
  });

  final Float32List samples;
  final int sampleRate;
  final KittenTTSVoiceId voice;
  final double effectiveSpeed;
  final String inputText;
  final List<KittenWordTiming> wordTimings;

  double get duration => samples.length / sampleRate;

  Uint8List wavData() => WAVEncoder.encode(samples, sampleRate);

  String wavBase64() => base64Encode(wavData());

  Future<Uint8List> mp3Data({int bitRate = 128}) {
    return MP3Encoder.encode(samples, sampleRate, bitRate: bitRate);
  }

  Future<String> mp3Base64({int bitRate = 128}) async {
    return base64Encode(await mp3Data(bitRate: bitRate));
  }
}
