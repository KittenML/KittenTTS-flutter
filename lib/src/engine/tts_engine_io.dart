import 'dart:typed_data';

import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';

import '../kitten_model.dart';
import '../kitten_tts_config.dart';
import '../kitten_tts_error.dart';
import '../kitten_voice.dart';
import '../loader/npz_loader.dart';
import 'text_cleaner.dart';
import 'text_preprocessor.dart';

class TTSEngineOutput {
  const TTSEngineOutput({
    required this.samples,
    required this.durations,
    required this.phonemes,
  });

  final Float32List samples;
  final List<num> durations;
  final String phonemes;
}

class TTSEngine {
  TTSEngine._({
    required OrtSession session,
    required VoiceEmbeddings voices,
    required ResolvedKittenTTSConfig config,
    required String waveformOutputName,
    required String? durationOutputName,
  })  : _session = session,
        _voices = voices,
        _config = config,
        _waveformOutputName = waveformOutputName,
        _durationOutputName = durationOutputName;

  final OrtSession _session;
  final VoiceEmbeddings _voices;
  final ResolvedKittenTTSConfig _config;
  final String _waveformOutputName;
  final String? _durationOutputName;
  var _disposed = false;

  static Future<TTSEngine> create(
    String modelPath,
    VoiceEmbeddings voices,
    ResolvedKittenTTSConfig config,
  ) async {
    try {
      final runtime = OnnxRuntime();
      final session = await runtime.createSession(
        modelPath,
        options: OrtSessionOptions(intraOpNumThreads: config.ortNumThreads),
      );
      final outputNames = session.outputNames;
      final waveformOutputName = outputNames.contains('waveform')
          ? 'waveform'
          : outputNames.isNotEmpty
              ? outputNames.first
              : 'waveform';
      final durationOutputName =
          outputNames.contains('duration') ? 'duration' : null;
      return TTSEngine._(
        session: session,
        voices: voices,
        config: config,
        waveformOutputName: waveformOutputName,
        durationOutputName: durationOutputName,
      );
    } catch (error) {
      throw KittenTTSError.inferenceFailed(
        'Could not initialise ONNX Runtime: ${errorMessage(error)}',
        error,
      );
    }
  }

  Future<TTSEngineOutput> generate(
    String text,
    KittenTTSVoiceId voice,
    double speed,
  ) async {
    if (_disposed) throw KittenTTSError.engineNotReady();
    final embedding = _voices[voiceEmbeddingKey(voice)];
    if (embedding == null) throw KittenTTSError.noVoiceEmbedding(voice);

    final normalized = preprocess(text);
    if (normalized.isEmpty) throw KittenTTSError.emptyInput();

    late final String phonemes;
    try {
      phonemes = await _config.phonemizer.phonemize(normalized);
    } catch (error) {
      if (error is KittenTTSError) rethrow;
      throw KittenTTSError.phonemizerFailed(errorMessage(error), error);
    }

    try {
      final tokens = encodePhonemes(phonemes);
      final chunks = _splitIntoChunks(tokens);
      final effectiveSpeed = speed * speedPrior(_config.model, voice);
      final singleChunk = chunks.length == 1;
      final sampleChunks = <Float32List>[];
      var durations = <num>[];

      for (final chunk in chunks) {
        final chunkTextLength = (chunk.length - 3).clamp(0, chunk.length);
        final output = await _runChunk(
          chunk,
          embedding,
          chunkTextLength,
          effectiveSpeed,
        );
        sampleChunks.add(output.samples);
        if (singleChunk) durations = output.durations;
      }

      final totalLength = sampleChunks.fold<int>(
        0,
        (sum, chunk) => sum + chunk.length,
      );
      if (totalLength == 0) throw KittenTTSError.emptyOutput();
      final result = Float32List(totalLength);
      var offset = 0;
      for (final chunk in sampleChunks) {
        result.setRange(offset, offset + chunk.length, chunk);
        offset += chunk.length;
      }
      return TTSEngineOutput(
        samples: result,
        durations: durations,
        phonemes: phonemes,
      );
    } catch (error) {
      if (error is KittenTTSError) rethrow;
      throw KittenTTSError.inferenceFailed(errorMessage(error), error);
    }
  }

  Future<_RunChunkOutput> _runChunk(
    List<int> tokens,
    VoiceEmbedding embedding,
    int phonemeLength,
    double speed,
  ) async {
    final rowIndex = phonemeLength.clamp(0, embedding.rows - 1);
    final styleStart = rowIndex * embedding.cols;
    final style = Float32List.fromList(
      embedding.data.sublist(styleStart, styleStart + embedding.cols),
    );

    final inputIds = await OrtValue.fromList(Int64List.fromList(tokens), [
      1,
      tokens.length,
    ]);
    final styleTensor = await OrtValue.fromList(style, [1, style.length]);
    final speedTensor =
        await OrtValue.fromList(Float32List.fromList([speed]), [1]);
    final inputs = {
      'input_ids': inputIds,
      'style': styleTensor,
      'speed': speedTensor,
    };

    final outputs = await _session.run(inputs);
    try {
      final waveform =
          outputs[_waveformOutputName] ?? outputs.values.firstOrNull;
      if (waveform == null) throw KittenTTSError.emptyOutput();
      final samples = await _float32FromOrtValue(waveform);
      if (samples.isEmpty) throw KittenTTSError.emptyOutput();
      return _RunChunkOutput(
        samples: _trimTrailingSilence(samples),
        durations: await _readDurations(outputs, waveform),
      );
    } finally {
      await Future.wait([
        inputIds.dispose(),
        styleTensor.dispose(),
        speedTensor.dispose(),
        ...outputs.values.map((value) => value.dispose()),
      ]);
    }
  }

  Future<Float32List> _float32FromOrtValue(OrtValue value) async {
    final flat = await value.asFlattenedList();
    return Float32List.fromList(
        flat.map((item) => (item as num).toDouble()).toList());
  }

  Future<List<num>> _readDurations(
    Map<String, OrtValue> outputs,
    OrtValue waveform,
  ) async {
    OrtValue? duration;
    final durationName = _durationOutputName;
    if (durationName != null) duration = outputs[durationName];
    duration ??= outputs.entries
        .where((entry) => entry.value.id != waveform.id)
        .map((entry) => entry.value)
        .where(
          (value) =>
              value.dataType == OrtDataType.int32 ||
              value.dataType == OrtDataType.int64 ||
              value.dataType == OrtDataType.uint32 ||
              value.dataType == OrtDataType.uint64,
        )
        .firstOrNull;
    if (duration == null) return const [];
    final flat = await duration.asFlattenedList();
    return flat.map((item) => item as num).toList(growable: false);
  }

  Float32List _trimTrailingSilence(Float32List samples) {
    if (!_config.trimTrailingSilence || samples.isEmpty) return samples;
    final maxTrimSamples = (samples.length)
        .clamp(0, (_config.maxSilenceTrimMs / 1000 * outputSampleRate).round());
    var trimCount = 0;
    while (trimCount < maxTrimSamples &&
        samples[samples.length - 1 - trimCount].abs() <=
            _config.silenceThreshold) {
      trimCount += 1;
    }
    if (trimCount == 0 || trimCount >= samples.length) return samples;
    return Float32List.sublistView(samples, 0, samples.length - trimCount);
  }

  List<List<int>> _splitIntoChunks(List<int> tokens) {
    final body = tokens.sublist(1, tokens.length - 2);
    final maxBody = _config.maxTokensPerChunk - 3;
    if (body.length <= maxBody) return [tokens];
    final chunks = <List<int>>[];
    for (var i = 0; i < body.length; i += maxBody) {
      final end = i + maxBody < body.length ? i + maxBody : body.length;
      chunks
          .add([startTokenId, ...body.sublist(i, end), endTokenId, padTokenId]);
    }
    return chunks;
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _session.close();
  }
}

class _RunChunkOutput {
  const _RunChunkOutput({required this.samples, required this.durations});

  final Float32List samples;
  final List<num> durations;
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
