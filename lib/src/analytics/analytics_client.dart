import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import '../kitten_model.dart';
import '../kitten_tts_error.dart';
import '../kitten_voice.dart';
import 'analytics_platform.dart' as platform;

const analyticsEndpoint = 'https://kittenmlanalytics.com/v1/track';
const analyticsSdkType = 'flutter';
const analyticsSdkVersion = '0.1.0';
const defaultAnalyticsTimeout = Duration(seconds: 2);

typedef AnalyticsGeneration = String;
typedef AnalyticsAssetSource = String;
typedef AnalyticsPayload = Map<String, String>;
typedef AnalyticsPostJson = FutureOr<void> Function(
  Uri endpoint,
  AnalyticsPayload payload,
  Duration timeout,
);

class AnalyticsModelInfo {
  const AnalyticsModelInfo({
    required this.selectedModel,
    required this.modelVersion,
  });

  final String selectedModel;
  final String modelVersion;
}

class AnalyticsClient {
  AnalyticsClient({
    required this.selectedModel,
    required this.modelVersion,
    required this.assetSource,
    this.enabled = true,
    Uri? endpoint,
    this.sdkVersion = analyticsSdkVersion,
    this.timeout = defaultAnalyticsTimeout,
    this.anonymousIdPath,
    AnalyticsPostJson? postJson,
    this.asyncDelivery = true,
  })  : endpoint = endpoint ?? Uri.parse(analyticsEndpoint),
        _postJson = postJson ?? postJsonRequest;

  final bool enabled;
  final Uri endpoint;
  final String sdkVersion;
  final String selectedModel;
  final String modelVersion;
  final AnalyticsAssetSource assetSource;
  final Duration timeout;
  final String? anonymousIdPath;
  final bool asyncDelivery;
  final AnalyticsPostJson _postJson;

  String? _anonymousId;

  Future<void> trackGeneration({
    required KittenTTSVoiceId selectedVoice,
    required AnalyticsGeneration generation,
    String? sdkErrorCode,
  }) async {
    if (!enabled) return;

    try {
      final payload = await _createPayload(
        selectedVoice: selectedVoice,
        generation: generation,
        sdkErrorCode: sdkErrorCode,
      );
      if (asyncDelivery) {
        unawaited(_send(payload));
        return;
      }
      await _send(payload);
    } catch (_) {
      // Analytics must never affect TTS calls.
    }
  }

  Future<AnalyticsPayload> _createPayload({
    required KittenTTSVoiceId selectedVoice,
    required AnalyticsGeneration generation,
    String? sdkErrorCode,
  }) async {
    final payload = <String, String>{
      'anonymous_id': await _loadOrCreateAnonymousId(),
      'client_event_id': _randomUuid(),
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'sdk_version': sdkVersion,
      'sdk_type': analyticsSdkType,
      'platform': platform.currentPlatform(),
      'runtime_version': platform.runtimeVersion(),
      'selected_model': selectedModel,
      'model_version': modelVersion,
      'selected_voice': selectedVoice,
      'generation': generation,
      'asset_source': assetSource,
    };

    if (sdkErrorCode != null && sdkErrorCode.trim().isNotEmpty) {
      payload['sdk_error_code'] = sdkErrorCode.trim();
    }

    return payload;
  }

  Future<String> _loadOrCreateAnonymousId() async {
    final existing = _anonymousId ??
        await platform.readAnonymousId(
          _anonymousIdStorageKey,
          anonymousIdPath,
        );
    if (existing != null) {
      _anonymousId = existing;
      return existing;
    }

    final id = _randomUuid();
    _anonymousId = id;
    await platform.writeAnonymousId(
        _anonymousIdStorageKey, anonymousIdPath, id);
    return id;
  }

  Future<void> _send(AnalyticsPayload payload) async {
    try {
      await _postJson(endpoint, payload, timeout);
    } catch (_) {
      // Swallow analytics delivery errors.
    }
  }
}

AnalyticsModelInfo analyticsModelInfo(KittenTTSModelId model) {
  final repoName = modelRepoId(model);
  final match = RegExp(
    r'^(.+?)-(\d+(?:\.\d+)*(?:-[A-Za-z0-9]+)*)$',
  ).firstMatch(repoName);
  if (match == null) {
    return AnalyticsModelInfo(
      selectedModel: repoName,
      modelVersion: 'unknown',
    );
  }
  return AnalyticsModelInfo(
    selectedModel: match.group(1)!,
    modelVersion: match.group(2)!,
  );
}

String analyticsErrorCode(Object error) {
  if (error is KittenTTSError) return _enumErrorCode(error.code.name);
  final text = error.runtimeType.toString();
  return _enumErrorCode(text.isEmpty ? 'unknownError' : text);
}

Future<void> postJsonRequest(
  Uri endpoint,
  AnalyticsPayload payload,
  Duration timeout,
) async {
  final client = http.Client();
  try {
    final response = await client
        .post(
          endpoint,
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            ...platform.analyticsHeaders(payload['sdk_version'] ?? 'unknown'),
          },
          body: jsonEncode(payload),
        )
        .timeout(timeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
          'Analytics request failed with HTTP ${response.statusCode}');
    }
  } finally {
    client.close();
  }
}

const _anonymousIdStorageKey = 'kittentts_flutter_analytics_id';

String _enumErrorCode(String value) {
  final spaced = value
      .replaceAllMapped(
        RegExp(r'(?<!^)([A-Z])'),
        (match) => '_${match.group(1)}',
      )
      .replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_')
      .toUpperCase()
      .replaceAll(RegExp(r'^_+|_+$'), '');
  return spaced.isEmpty ? 'UNKNOWN_ERROR' : spaced;
}

String _randomUuid() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex =
      bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-'
      '${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-'
      '${hex.substring(16, 20)}-'
      '${hex.substring(20)}';
}
