import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

import '../../kitten_tts_error.dart';

typedef _CreateNative = Pointer<Void> Function(
  Pointer<Utf8> rulesPath,
  Pointer<Utf8> listPath,
  Pointer<Utf8> dialect,
);
typedef _CreateDart = Pointer<Void> Function(
  Pointer<Utf8> rulesPath,
  Pointer<Utf8> listPath,
  Pointer<Utf8> dialect,
);
typedef _DestroyNative = Void Function(Pointer<Void> handle);
typedef _DestroyDart = void Function(Pointer<Void> handle);
typedef _PhonemizeNative = Pointer<Utf8> Function(
  Pointer<Void> handle,
  Pointer<Utf8> text,
);
typedef _PhonemizeDart = Pointer<Utf8> Function(
  Pointer<Void> handle,
  Pointer<Utf8> text,
);
typedef _FreeStringNative = Void Function(Pointer<Utf8> string);
typedef _FreeStringDart = void Function(Pointer<Utf8> string);

class NativeCEPhonemizerBackend {
  NativeCEPhonemizerBackend({String dialect = 'en-us'}) : _dialect = dialect;

  final String _dialect;
  Pointer<Void> _handle = nullptr;
  _CreateDart? _create;
  _DestroyDart? _destroy;
  _PhonemizeDart? _phonemize;
  _FreeStringDart? _freeString;

  bool get isSupported =>
      Platform.isAndroid ||
      Platform.isIOS ||
      Platform.isLinux ||
      Platform.isMacOS ||
      Platform.isWindows;

  Future<void> load({
    required String rulesPath,
    required String listPath,
  }) async {
    await dispose();
    final library = _loadLibrary();
    _create =
        library.lookupFunction<_CreateNative, _CreateDart>('phonemizer_create');
    _destroy = library
        .lookupFunction<_DestroyNative, _DestroyDart>('phonemizer_destroy');
    _phonemize = library.lookupFunction<_PhonemizeNative, _PhonemizeDart>(
      'phonemizer_phonemize',
    );
    _freeString = library.lookupFunction<_FreeStringNative, _FreeStringDart>(
      'phonemizer_free_string',
    );

    final rulesPtr = rulesPath.toNativeUtf8();
    final listPtr = listPath.toNativeUtf8();
    final dialectPtr = _dialect.toNativeUtf8();
    try {
      final handle = _create!(rulesPtr, listPtr, dialectPtr);
      if (handle == nullptr) {
        throw KittenTTSError.phonemizerFailed(
          'CEPhonemizer failed to load en_rules/en_list.',
        );
      }
      _handle = handle;
    } finally {
      calloc
        ..free(rulesPtr)
        ..free(listPtr)
        ..free(dialectPtr);
    }
  }

  Future<String> phonemize(String text) async {
    final phonemize = _phonemize;
    final freeString = _freeString;
    if (_handle == nullptr || phonemize == null || freeString == null) {
      throw KittenTTSError.phonemizerFailed(
        'CEPhonemizer data is not ready. Call downloadIfNeeded() before phonemize().',
      );
    }

    final textPtr = text.toNativeUtf8();
    Pointer<Utf8> resultPtr = nullptr;
    try {
      resultPtr = phonemize(_handle, textPtr);
      if (resultPtr == nullptr) {
        throw KittenTTSError.phonemizerFailed(
          'CEPhonemizer failed to phonemize text.',
        );
      }
      return resultPtr.toDartString();
    } finally {
      calloc.free(textPtr);
      if (resultPtr != nullptr) freeString(resultPtr);
    }
  }

  Future<void> dispose() async {
    if (_handle != nullptr && _destroy != null) {
      _destroy!(_handle);
    }
    _handle = nullptr;
  }

  DynamicLibrary _loadLibrary() {
    if (Platform.isIOS || Platform.isMacOS) {
      try {
        return DynamicLibrary.process();
      } catch (_) {
        return DynamicLibrary.open('libkittentts_cephonemizer.dylib');
      }
    }
    if (Platform.isAndroid || Platform.isLinux) {
      return DynamicLibrary.open('libkittentts_cephonemizer.so');
    }
    if (Platform.isWindows) {
      return DynamicLibrary.open('kittentts_cephonemizer.dll');
    }
    throw KittenTTSError.phonemizerFailed(
      'Native CEPhonemizer is not available on this platform.',
    );
  }
}
