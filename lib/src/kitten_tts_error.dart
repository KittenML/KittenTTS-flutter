enum KittenTTSErrorCode {
  emptyInput,
  engineNotReady,
  modelFileNotFound,
  voicesFileNotFound,
  noVoiceEmbedding,
  inferenceFailed,
  emptyOutput,
  downloadFailed,
  invalidModelData,
  phonemizerFailed,
  playbackFailed,
}

class KittenTTSError implements Exception {
  KittenTTSError(this.code, this.message, [this.cause]);

  final KittenTTSErrorCode code;
  final String message;
  final Object? cause;

  factory KittenTTSError.emptyInput() => KittenTTSError(
        KittenTTSErrorCode.emptyInput,
        'Input text must not be empty.',
      );

  factory KittenTTSError.engineNotReady() => KittenTTSError(
        KittenTTSErrorCode.engineNotReady,
        'KittenTTS engine is not initialised. Call KittenTTS.create() first.',
      );

  factory KittenTTSError.modelFileNotFound(String path) => KittenTTSError(
        KittenTTSErrorCode.modelFileNotFound,
        'Model file not found: $path',
      );

  factory KittenTTSError.voicesFileNotFound(String path) => KittenTTSError(
        KittenTTSErrorCode.voicesFileNotFound,
        'Voice embeddings file not found: $path',
      );

  factory KittenTTSError.noVoiceEmbedding(String voice) => KittenTTSError(
        KittenTTSErrorCode.noVoiceEmbedding,
        "No embedding found for voice '$voice'.",
      );

  factory KittenTTSError.inferenceFailed(String detail, [Object? cause]) =>
      KittenTTSError(
        KittenTTSErrorCode.inferenceFailed,
        'ONNX inference failed: $detail',
        cause,
      );

  factory KittenTTSError.emptyOutput() => KittenTTSError(
        KittenTTSErrorCode.emptyOutput,
        'The model produced no audio samples.',
      );

  factory KittenTTSError.downloadFailed(String detail, [Object? cause]) =>
      KittenTTSError(
        KittenTTSErrorCode.downloadFailed,
        'Model download failed: $detail',
        cause,
      );

  factory KittenTTSError.invalidModelData(String detail, [Object? cause]) =>
      KittenTTSError(
        KittenTTSErrorCode.invalidModelData,
        'Invalid model data: $detail',
        cause,
      );

  factory KittenTTSError.phonemizerFailed(String detail, [Object? cause]) =>
      KittenTTSError(
        KittenTTSErrorCode.phonemizerFailed,
        'Phonemizer failed: $detail',
        cause,
      );

  factory KittenTTSError.playbackFailed(String detail, [Object? cause]) =>
      KittenTTSError(
        KittenTTSErrorCode.playbackFailed,
        'Playback failed: $detail',
        cause,
      );

  @override
  String toString() => 'KittenTTSError(${code.name}): $message';
}

String errorMessage(Object? error) => error is KittenTTSError
    ? error.message
    : error is Exception
        ? error.toString()
        : '$error';
