import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import '../kitten_model.dart';
import '../kitten_tts_config.dart';
import '../kitten_tts_error.dart';
import '../kitten_voice.dart';
import '../loader/npz_loader.dart';
import 'text_cleaner.dart';
import 'text_preprocessor.dart';

@JS('ort')
external JSObject? get _ort;

@JS('BigInt')
external JSBigInt _bigInt(JSAny value);

@JS('BigInt64Array')
external JSFunction get _bigInt64ArrayConstructor;

@JS('ort.Tensor')
external JSFunction get _tensorConstructor;

@JS('Object')
external JSFunction get _objectConstructor;

@JS('Object')
external JSObject get _objectGlobal;

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
    required JSObject session,
    required VoiceEmbeddings voices,
    required ResolvedKittenTTSConfig config,
    required String waveformOutputName,
    required String? durationOutputName,
  })  : _session = session,
        _voices = voices,
        _config = config,
        _waveformOutputName = waveformOutputName,
        _durationOutputName = durationOutputName;

  final JSObject _session;
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
      final ort = _ort;
      if (ort == null) {
        throw KittenTTSError.inferenceFailed(
          'ONNX Runtime Web is not loaded. Add the ort.min.js script before Flutter bootstrap.',
        );
      }
      final inferenceSession =
          ort.getProperty('InferenceSession'.toJS) as JSObject?;
      if (inferenceSession == null) {
        throw KittenTTSError.inferenceFailed(
          'ONNX Runtime Web InferenceSession is not available.',
        );
      }

      final options = _createSessionOptions(config);
      final promise =
          inferenceSession.callMethod('create'.toJS, modelPath.toJS, options);
      final session = await (promise as JSPromise<JSObject>).toDart;
      final outputNames = _readStringArray(session, 'outputNames');
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
      if (error is KittenTTSError) rethrow;
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

    final inputIds = _createTensor(
      'int64',
      _bigInt64ArrayFrom(tokens),
      [1, tokens.length],
    );
    final styleTensor = _createTensor('float32', style.toJS, [1, style.length]);
    final speedTensor = _createTensor(
      'float32',
      Float32List.fromList([speed]).toJS,
      [1],
    );
    final feeds = _createObject();
    feeds.setProperty('input_ids'.toJS, inputIds);
    feeds.setProperty('style'.toJS, styleTensor);
    feeds.setProperty('speed'.toJS, speedTensor);

    final promise = _session.callMethod('run'.toJS, feeds);
    final outputs = await (promise as JSPromise<JSObject>).toDart;
    final waveform = _outputTensor(outputs, _waveformOutputName) ??
        _firstOutputTensor(outputs);
    if (waveform == null) throw KittenTTSError.emptyOutput();
    final samples = _float32TensorData(waveform);
    if (samples.isEmpty) throw KittenTTSError.emptyOutput();
    return _RunChunkOutput(
      samples: _trimTrailingSilence(samples),
      durations: _readDurations(outputs, waveform),
    );
  }

  List<num> _readDurations(JSObject outputs, JSObject waveform) {
    JSObject? duration;
    final durationName = _durationOutputName;
    if (durationName != null) duration = _outputTensor(outputs, durationName);
    duration ??= _readStringArray(_session, 'outputNames')
        .map((name) => _outputTensor(outputs, name))
        .whereType<JSObject>()
        .where((tensor) => !identical(tensor, waveform))
        .where(_isIntegerTensor)
        .firstOrNull;
    if (duration == null) return const [];
    return _numericTensorData(duration);
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
    if (_session.has('release')) {
      _session.callMethod('release'.toJS);
    }
  }
}

class _RunChunkOutput {
  const _RunChunkOutput({required this.samples, required this.durations});

  final Float32List samples;
  final List<num> durations;
}

JSObject _createSessionOptions(ResolvedKittenTTSConfig config) {
  final options = _createObject();
  options.setProperty('intraOpNumThreads'.toJS, config.ortNumThreads.toJS);
  options.setProperty(
    'executionProviders'.toJS,
    <JSString>['wasm'.toJS].toJS,
  );
  return options;
}

JSObject _createObject() => _objectConstructor.callAsConstructor();

JSObject _createTensor(String type, JSObject data, List<int> dims) {
  return _tensorConstructor.callAsConstructorVarArgs([
    type.toJS,
    data,
    dims.map((dim) => dim.toJS).toList().toJS,
  ]);
}

JSObject _bigInt64ArrayFrom(List<int> values) {
  final bigInts = values.map((value) => _bigInt(value.toJS)).toList().toJS;
  return _bigInt64ArrayConstructor.callAsConstructorVarArgs([bigInts]);
}

JSObject? _outputTensor(JSObject outputs, String name) {
  if (!outputs.has(name)) return null;
  return outputs.getProperty(name.toJS) as JSObject?;
}

JSObject? _firstOutputTensor(JSObject outputs) {
  final outputNames = _readObjectKeys(outputs);
  if (outputNames.isEmpty) return null;
  return _outputTensor(outputs, outputNames.first);
}

Float32List _float32TensorData(JSObject tensor) {
  return (tensor.getProperty('data'.toJS) as JSFloat32Array).toDart;
}

List<num> _numericTensorData(JSObject tensor) {
  final data = tensor.getProperty('data'.toJS) as JSObject;
  final length = (data.getProperty('length'.toJS) as JSNumber).toDartInt;
  final type = tensor.getProperty('type'.toJS).toString();
  final result = <num>[];
  for (var i = 0; i < length; i += 1) {
    final value = data.getProperty(i.toString().toJS);
    if (type == 'int64' || type == 'uint64') {
      result.add(int.parse(value.toString()));
    } else {
      result.add((value as JSNumber).toDartDouble);
    }
  }
  return result;
}

bool _isIntegerTensor(JSObject tensor) {
  final type = tensor.getProperty('type'.toJS).toString();
  return type == 'int32' ||
      type == 'int64' ||
      type == 'uint32' ||
      type == 'uint64';
}

List<String> _readStringArray(JSObject object, String property) {
  if (!object.has(property)) return const [];
  final array = object.getProperty(property.toJS) as JSObject;
  final length = (array.getProperty('length'.toJS) as JSNumber).toDartInt;
  return [
    for (var i = 0; i < length; i += 1)
      array.getProperty(i.toString().toJS).toString(),
  ];
}

List<String> _readObjectKeys(JSObject object) {
  final keys = _objectGlobal.callMethod('keys'.toJS, object) as JSObject;
  final length = (keys.getProperty('length'.toJS) as JSNumber).toDartInt;
  return [
    for (var i = 0; i < length; i += 1)
      keys.getProperty(i.toString().toJS).toString(),
  ];
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
