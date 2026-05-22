import '../../kitten_tts_error.dart';

class NativeCEPhonemizerBackend {
  NativeCEPhonemizerBackend({String dialect = 'en-us'});

  bool get isSupported => false;

  Future<void> load({
    required String rulesPath,
    required String listPath,
  }) async {
    throw KittenTTSError.phonemizerFailed(
      'Native CEPhonemizer is not available on this platform.',
    );
  }

  Future<String> phonemize(String text) async {
    throw KittenTTSError.phonemizerFailed(
      'Native CEPhonemizer is not available on this platform.',
    );
  }

  Future<void> dispose() async {}
}
