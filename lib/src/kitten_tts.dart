import 'dart:async';

import 'analytics/analytics_client.dart';
import 'audio/audio_output.dart';
import 'audio/playback_queue.dart';
import 'engine/sentence_splitter.dart';
import 'engine/timestamp_joiner.dart';
import 'engine/tts_engine.dart';
import 'kitten_model.dart';
import 'kitten_tts_config.dart';
import 'kitten_tts_error.dart';
import 'kitten_tts_result.dart';
import 'kitten_voice.dart';
import 'kitten_word_timing.dart';
import 'loader/model_downloader.dart' as loader;
import 'loader/model_downloader.dart'
    show DownloadProgressInfo, ModelCacheInfo, ProgressHandler;
import 'loader/npz_loader.dart';

class KittenTTS {
  KittenTTS._({
    required TTSEngine engine,
    required this.config,
    required AnalyticsClient analytics,
    AudioPlayer? player,
  })  : _engine = engine,
        _analytics = analytics,
        _audioOutput = AudioOutput(player);

  final ResolvedKittenTTSConfig config;
  final TTSEngine _engine;
  final AnalyticsClient _analytics;
  final AudioOutput _audioOutput;
  var _disposed = false;

  static Future<KittenTTS> create({
    KittenTTSConfig? config,
    ProgressHandler? onProgress,
    AudioPlayer? player,
    bool forceRedownload = false,
  }) async {
    final resolved = await resolveConfig(config);
    final setupProgress = _AggregateSetupProgress(onProgress);
    var analyticsAssetSource =
        resolved.modelFiles == null ? 'runtime-download' : 'bundled';
    void modelProgress(double progress, [DownloadProgressInfo? info]) {
      if (info?.stage == loader.DownloadProgressStage.cached &&
          info?.cached == true) {
        analyticsAssetSource =
            resolved.modelFiles == null ? 'cache' : 'bundled';
      } else if (info?.stage == loader.DownloadProgressStage.downloading ||
          (info?.stage == loader.DownloadProgressStage.complete &&
              info?.cached == false)) {
        analyticsAssetSource = 'runtime-download';
      }
      setupProgress.call(0.2 + progress * 0.8, info);
    }

    await resolved.phonemizer.downloadIfNeeded(
      resolved.storageDirectory,
      onProgress: (progress) => setupProgress.call(progress * 0.2),
    );

    final paths = await loader.resolveModelPaths(
      resolved.model,
      resolved.storageDirectory,
      modelProgress,
      modelFiles: resolved.modelFiles,
      force: forceRedownload,
      retries: resolved.downloadRetries,
      baseUrl: resolved.modelBaseUrl,
    );

    final voices = await loadNPZ(paths.voicesPath);
    final engine = await TTSEngine.create(paths.onnxPath, voices, resolved);
    setupProgress.call(
      1,
      const DownloadProgressInfo(stage: loader.DownloadProgressStage.complete),
    );
    final modelInfo = analyticsModelInfo(resolved.model);
    return KittenTTS._(
      engine: engine,
      config: resolved,
      analytics: AnalyticsClient(
        selectedModel: modelInfo.selectedModel,
        modelVersion: modelInfo.modelVersion,
        assetSource: analyticsAssetSource,
        enabled: resolved.analytics,
        anonymousIdPath: '${resolved.storageDirectory}/analytics_id',
      ),
      player: player,
    );
  }

  Future<KittenTTSResult> generate(
    String text, {
    KittenTTSVoiceId? voice,
    double? speed,
  }) async {
    final selectedVoice = voice ?? config.defaultVoice;
    try {
      final result = await _generateResult(text, voice: voice, speed: speed);
      _trackGeneration('wav', result.voice);
      return result;
    } catch (error) {
      _trackGeneration('wav', selectedVoice, analyticsErrorCode(error));
      rethrow;
    }
  }

  Future<KittenTTSResult> _generateResult(
    String text, {
    KittenTTSVoiceId? voice,
    double? speed,
  }) async {
    if (_disposed) throw KittenTTSError.engineNotReady();
    final trimmed = text.trim();
    if (trimmed.isEmpty) throw KittenTTSError.emptyInput();
    final selectedVoice = validateVoice(voice ?? config.defaultVoice);
    final selectedSpeed = (speed ?? config.speed).clamp(0.5, 2.0);
    final output =
        await _engine.generate(trimmed, selectedVoice, selectedSpeed);
    final effectiveSpeed =
        selectedSpeed * speedPrior(config.model, selectedVoice);
    final wordTimings = _normalizeWordTimingsToDuration(
      joinTimestamps(trimmed, output.phonemes, output.durations),
      output.samples.length / outputSampleRate,
    );
    return KittenTTSResult(
      samples: output.samples,
      sampleRate: outputSampleRate,
      voice: selectedVoice,
      effectiveSpeed: effectiveSpeed,
      inputText: trimmed,
      wordTimings: wordTimings,
    );
  }

  Stream<KittenTTSResult> stream(
    String text, {
    KittenTTSVoiceId? voice,
    double? speed,
  }) async* {
    if (_disposed) throw KittenTTSError.engineNotReady();
    final trimmed = text.trim();
    if (trimmed.isEmpty) throw KittenTTSError.emptyInput();
    final selectedVoice = validateVoice(voice ?? config.defaultVoice);
    final selectedSpeed = (speed ?? config.speed).clamp(0.5, 2.0);
    var trackedSuccess = false;
    try {
      for (final sentence in splitSentences(trimmed)) {
        final result = await _generateResult(
          sentence,
          voice: selectedVoice,
          speed: selectedSpeed,
        );
        if (!trackedSuccess) {
          trackedSuccess = true;
          _trackGeneration('stream', result.voice);
        }
        yield result;
      }
    } catch (error) {
      if (!trackedSuccess) {
        _trackGeneration('stream', selectedVoice, analyticsErrorCode(error));
      }
      rethrow;
    }
  }

  Future<KittenTTSResult> speak(
    String text, {
    KittenTTSVoiceId? voice,
    double? speed,
    AudioPlayOptions options = const AudioPlayOptions(),
  }) async {
    final selectedVoice = voice ?? config.defaultVoice;
    var trackedSuccess = false;
    try {
      final result = await _generateResult(text, voice: voice, speed: speed);
      await play(
        result,
        AudioPlayOptions(
          onPlaybackStart: () {
            options.onPlaybackStart?.call();
            if (trackedSuccess) return;
            trackedSuccess = true;
            _trackGeneration('speak', result.voice);
          },
        ),
      );
      if (!trackedSuccess) {
        trackedSuccess = true;
        _trackGeneration('speak', result.voice);
      }
      return result;
    } catch (error) {
      if (!trackedSuccess) {
        _trackGeneration('speak', selectedVoice, analyticsErrorCode(error));
      }
      rethrow;
    }
  }

  Future<void> play(
    KittenTTSResult result, [
    AudioPlayOptions options = const AudioPlayOptions(),
  ]) async {
    if (_disposed) throw KittenTTSError.engineNotReady();
    await _audioOutput.play(result.samples, result.sampleRate, options);
  }

  PlaybackQueue createPlaybackQueue() {
    return PlaybackQueue(generate: generate, play: play, stop: stopSpeaking);
  }

  Future<void> stopSpeaking() => _audioOutput.stop();

  Future<void> stop() => stopSpeaking();

  Future<void> pauseSpeaking() => _audioOutput.pause();

  Future<void> resumeSpeaking() => _audioOutput.resume();

  bool get isSpeaking => _audioOutput.isSpeaking;

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _audioOutput.stop().catchError((_) {});
    await _engine.dispose();
    await config.phonemizer.dispose();
  }

  static Future<ModelCacheInfo> cacheInfo(KittenTTSConfig? config) async {
    final resolved = await resolveConfig(config);
    final modelFiles = resolved.modelFiles;
    if (modelFiles != null) {
      return loader.getProvidedModelCacheInfo(resolved.model, modelFiles);
    }
    return loader.getModelCacheInfo(resolved.model, resolved.storageDirectory);
  }

  static Future<void> clearModelCache(KittenTTSConfig? config) async {
    final resolved = await resolveConfig(config);
    if (resolved.modelFiles != null) return;
    await loader.clearModelCache(resolved.model, resolved.storageDirectory);
  }

  static Future<void> redownloadModel(
    KittenTTSConfig? config, {
    ProgressHandler? onProgress,
  }) async {
    final resolved = await resolveConfig(config);
    if (resolved.modelFiles != null) {
      await loader.resolveModelPaths(
        resolved.model,
        resolved.storageDirectory,
        onProgress,
        modelFiles: resolved.modelFiles,
      );
      return;
    }
    await loader.clearModelCache(resolved.model, resolved.storageDirectory);
    await loader.resolveModelPaths(
      resolved.model,
      resolved.storageDirectory,
      onProgress,
      force: true,
      retries: resolved.downloadRetries,
      baseUrl: resolved.modelBaseUrl,
    );
  }

  static Future<void> predownload(
    KittenTTSConfig? config, {
    ProgressHandler? onProgress,
  }) async {
    final resolved = await resolveConfig(config);
    final setupProgress = _AggregateSetupProgress(onProgress);
    await resolved.phonemizer.downloadIfNeeded(
      resolved.storageDirectory,
      onProgress: (progress) => setupProgress.call(progress * 0.2),
    );
    await loader.resolveModelPaths(
      resolved.model,
      resolved.storageDirectory,
      (progress, [info]) => setupProgress.call(0.2 + progress * 0.8, info),
      modelFiles: resolved.modelFiles,
      retries: resolved.downloadRetries,
      baseUrl: resolved.modelBaseUrl,
    );
    setupProgress.call(
      1,
      const DownloadProgressInfo(stage: loader.DownloadProgressStage.complete),
    );
  }

  static Future<void> validateAssets(KittenTTSConfig? config) async {
    final info = await cacheInfo(config);
    if (!info.isCached) throw KittenTTSError.modelFileNotFound(info.directory);
  }

  void _trackGeneration(
    String generation,
    KittenTTSVoiceId selectedVoice, [
    String? sdkErrorCode,
  ]) {
    unawaited(
      _analytics.trackGeneration(
        selectedVoice: selectedVoice,
        generation: generation,
        sdkErrorCode: sdkErrorCode,
      ),
    );
  }
}

List<KittenWordTiming> _normalizeWordTimingsToDuration(
  List<KittenWordTiming> wordTimings,
  double audioDuration,
) {
  if (wordTimings.isEmpty || audioDuration <= 0) return [...wordTimings];
  final lastEndTime = wordTimings.last.endTime;
  if (lastEndTime <= 0) return [...wordTimings];
  final scale = audioDuration / lastEndTime;
  return wordTimings
      .map(
        (timing) => timing.copyWith(
          startTime: _clampTime(timing.startTime * scale, audioDuration),
          endTime: _clampTime(timing.endTime * scale, audioDuration),
        ),
      )
      .toList(growable: false);
}

double _clampTime(double value, double duration) => value.clamp(0, duration);

class _AggregateSetupProgress {
  _AggregateSetupProgress(this._handler);

  final ProgressHandler? _handler;

  void call(double progress, [DownloadProgressInfo? info]) {
    _handler?.call(progress.clamp(0, 1), info);
  }
}
