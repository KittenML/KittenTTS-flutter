import 'kitten_model.dart';
import 'kitten_voice.dart';
import 'platform/kitten_platform.dart';
import 'phonemizer/ce_phonemizer.dart';
import 'phonemizer/phonemizer_protocol.dart';

const outputSampleRate = 24000;

class KittenTTSModelFiles {
  const KittenTTSModelFiles({
    required this.onnxPath,
    required this.voicesPath,
  });

  final String onnxPath;
  final String voicesPath;
}

class KittenTTSConfig {
  const KittenTTSConfig({
    this.model = 'nano',
    this.defaultVoice = 'bella',
    this.speed = 1.0,
    this.storageDirectory,
    this.modelBaseUrl,
    this.modelFiles,
    this.downloadRetries = 4,
    this.ortNumThreads = 4,
    this.maxTokensPerChunk = 400,
    this.trimTrailingSilence = true,
    this.silenceThreshold = 0.005,
    this.maxSilenceTrimMs = 250,
    this.phonemizer,
    this.analytics = true,
  });

  final KittenTTSModelId model;
  final KittenTTSVoiceId defaultVoice;
  final double speed;
  final String? storageDirectory;
  final String? modelBaseUrl;
  final KittenTTSModelFiles? modelFiles;
  final int downloadRetries;
  final int ortNumThreads;
  final int maxTokensPerChunk;
  final bool trimTrailingSilence;
  final double silenceThreshold;
  final int maxSilenceTrimMs;
  final KittenPhonemizerProtocol? phonemizer;
  final bool analytics;
}

class ResolvedKittenTTSConfig {
  const ResolvedKittenTTSConfig({
    required this.model,
    required this.defaultVoice,
    required this.speed,
    required this.storageDirectory,
    required this.modelBaseUrl,
    required this.modelFiles,
    required this.downloadRetries,
    required this.ortNumThreads,
    required this.maxTokensPerChunk,
    required this.trimTrailingSilence,
    required this.silenceThreshold,
    required this.maxSilenceTrimMs,
    required this.phonemizer,
    required this.analytics,
  });

  final KittenTTSModelId model;
  final KittenTTSVoiceId defaultVoice;
  final double speed;
  final String storageDirectory;
  final String modelBaseUrl;
  final KittenTTSModelFiles? modelFiles;
  final int downloadRetries;
  final int ortNumThreads;
  final int maxTokensPerChunk;
  final bool trimTrailingSilence;
  final double silenceThreshold;
  final int maxSilenceTrimMs;
  final KittenPhonemizerProtocol phonemizer;
  final bool analytics;
}

Future<ResolvedKittenTTSConfig> resolveConfig(KittenTTSConfig? config) async {
  final storageDirectory =
      config?.storageDirectory ?? await defaultStorageDirectory();
  return ResolvedKittenTTSConfig(
    model: validateModel(config?.model ?? 'nano'),
    defaultVoice: validateVoice(config?.defaultVoice ?? 'bella'),
    speed: (config?.speed ?? 1.0).clamp(0.5, 2.0),
    storageDirectory: storageDirectory,
    modelBaseUrl: config?.modelBaseUrl ?? '',
    modelFiles: config?.modelFiles,
    downloadRetries: (config?.downloadRetries ?? 4).clamp(1, 1000),
    ortNumThreads: (config?.ortNumThreads ?? 4).clamp(1, 128),
    maxTokensPerChunk: (config?.maxTokensPerChunk ?? 400).clamp(50, 100000),
    trimTrailingSilence: config?.trimTrailingSilence ?? true,
    silenceThreshold: (config?.silenceThreshold ?? 0.005).clamp(0, 1),
    maxSilenceTrimMs: (config?.maxSilenceTrimMs ?? 250).clamp(0, 60000),
    phonemizer: config?.phonemizer ?? CEPhonemizer(),
    analytics: config?.analytics ?? true,
  );
}
