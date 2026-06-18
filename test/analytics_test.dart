import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kittentts/src/analytics/analytics_client.dart';
import 'package:kittentts/src/kitten_tts_error.dart';

void main() {
  test('analytics disabled sends no request', () async {
    final calls = <List<Object?>>[];
    final client = AnalyticsClient(
      selectedModel: 'kitten-tts-nano',
      modelVersion: '0.8',
      assetSource: 'cache',
      enabled: false,
      postJson: (endpoint, payload, timeout) => calls.add([
        endpoint,
        payload,
        timeout,
      ]),
      asyncDelivery: false,
    );

    await client.trackGeneration(selectedVoice: 'bella', generation: 'wav');

    expect(calls, isEmpty);
  });

  test('success event contains required analytics fields', () async {
    final calls = <List<Object?>>[];
    final anonymousIdPath =
        '${Directory.systemTemp.createTempSync('kittentts_').path}/analytics_id';
    final client = AnalyticsClient(
      selectedModel: 'kitten-tts-nano',
      modelVersion: '0.8',
      assetSource: 'cache',
      anonymousIdPath: anonymousIdPath,
      postJson: (endpoint, payload, timeout) => calls.add([
        endpoint,
        payload,
        timeout,
      ]),
      asyncDelivery: false,
    );

    await client.trackGeneration(selectedVoice: 'bella', generation: 'wav');

    expect(calls, hasLength(1));
    final endpoint = calls[0][0] as Uri;
    final payload = calls[0][1] as AnalyticsPayload;
    final timeout = calls[0][2] as Duration;
    expect(endpoint.toString(), analyticsEndpoint);
    expect(timeout, defaultAnalyticsTimeout);
    for (final key in [
      'anonymous_id',
      'client_event_id',
      'timestamp',
      'sdk_version',
      'sdk_type',
      'platform',
      'runtime_version',
      'selected_model',
      'model_version',
      'selected_voice',
      'generation',
      'asset_source',
    ]) {
      expect(payload[key], isNotEmpty, reason: key);
    }
    expect(payload['sdk_type'], analyticsSdkType);
    expect(payload['selected_model'], 'kitten-tts-nano');
    expect(payload['model_version'], '0.8');
    expect(payload['selected_voice'], 'bella');
    expect(payload['generation'], 'wav');
    expect(payload['asset_source'], 'cache');
    expect(payload.containsKey('ip_address'), isFalse);
    expect(payload.containsKey('ip_location'), isFalse);
  });

  test('failure event includes sdk error code', () async {
    final calls = <AnalyticsPayload>[];
    final client = AnalyticsClient(
      selectedModel: 'kitten-tts-nano',
      modelVersion: '0.8',
      assetSource: 'runtime-download',
      postJson: (endpoint, payload, timeout) => calls.add(payload),
      asyncDelivery: false,
    );

    await client.trackGeneration(
      selectedVoice: 'jasper',
      generation: 'speak',
      sdkErrorCode: 'PLAYBACK_FAILED',
    );

    expect(calls.single['sdk_error_code'], 'PLAYBACK_FAILED');
  });

  test('stream event uses stream generation type', () async {
    final calls = <AnalyticsPayload>[];
    final client = AnalyticsClient(
      selectedModel: 'kitten-tts-nano',
      modelVersion: '0.8',
      assetSource: 'cache',
      postJson: (endpoint, payload, timeout) => calls.add(payload),
      asyncDelivery: false,
    );

    await client.trackGeneration(
      selectedVoice: 'bella',
      generation: 'stream',
    );

    expect(calls.single['generation'], 'stream');
  });

  test('network errors do not reject analytics calls', () async {
    final client = AnalyticsClient(
      selectedModel: 'kitten-tts-nano',
      modelVersion: '0.8',
      assetSource: 'cache',
      postJson: (endpoint, payload, timeout) {
        throw StateError('network failed');
      },
      asyncDelivery: false,
    );

    await expectLater(
      client.trackGeneration(selectedVoice: 'bella', generation: 'wav'),
      completes,
    );
  });

  test('analytics transport posts JSON through HTTP', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final endpoint = Uri.parse(
      'http://${server.address.host}:${server.port}/v1/track',
    );
    final requestFuture = server.first;
    final postFuture = postJsonRequest(
        endpoint,
        {
          'sdk_version': '0.1.0',
          'selected_voice': 'bella',
        },
        const Duration(seconds: 1));

    final request = await requestFuture;
    final body = await utf8.decoder.bind(request).join();
    request.response.statusCode = 202;
    await request.response.close();
    await postFuture;
    await server.close(force: true);

    expect(request.method, 'POST');
    expect(request.headers.value(HttpHeaders.contentTypeHeader),
        'application/json');
    expect(request.headers.value(HttpHeaders.acceptHeader), 'application/json');
    expect(
      request.headers.value(HttpHeaders.userAgentHeader),
      'KittenTTS-Flutter/0.1.0',
    );
    expect(
      jsonDecode(body),
      {'sdk_version': '0.1.0', 'selected_voice': 'bella'},
    );
  });

  test('anonymous id is stable across analytics clients', () async {
    final dir = Directory.systemTemp.createTempSync('kittentts_');
    final anonymousIdPath = '${dir.path}/analytics_id';
    final calls = <AnalyticsPayload>[];

    AnalyticsClient makeClient() => AnalyticsClient(
          selectedModel: 'kitten-tts-nano',
          modelVersion: '0.8',
          assetSource: 'cache',
          anonymousIdPath: anonymousIdPath,
          postJson: (endpoint, payload, timeout) => calls.add(payload),
          asyncDelivery: false,
        );

    await makeClient()
        .trackGeneration(selectedVoice: 'bella', generation: 'wav');
    await makeClient()
        .trackGeneration(selectedVoice: 'bella', generation: 'wav');

    expect(calls[0]['anonymous_id'], calls[1]['anonymous_id']);
    expect(calls[0]['anonymous_id'], File(anonymousIdPath).readAsStringSync());
  });

  test('model metadata uses provider-stable names and versions', () {
    final info = analyticsModelInfo('nano-int8');

    expect(info.selectedModel, 'kitten-tts-nano');
    expect(info.modelVersion, '0.8-int8');
  });

  test('analytics error code maps SDK enum names to contract values', () {
    expect(
      analyticsErrorCode(KittenTTSError.playbackFailed('bad output')),
      'PLAYBACK_FAILED',
    );
  });
}
