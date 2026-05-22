import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import '../../kitten_tts_error.dart';
import '../ce_phonemizer_dictionary_web.dart';

@JS('globalThis')
external JSObject get _globalThis;

@JS('document')
external JSObject? get _document;

const _runtimeFactoryName = 'createKittenTtsCePhonemizerModule';
const _runtimeScriptPath =
    'assets/packages/kittentts_flutter/web/kittentts_cephonemizer.js';
const _virtualRulesPath = '/cephonemizer/en_rules';
const _virtualListPath = '/cephonemizer/en_list';

Future<void>? _runtimeLoad;

class NativeCEPhonemizerBackend {
  NativeCEPhonemizerBackend({String dialect = 'en-us'}) : _dialect = dialect;

  final String _dialect;
  JSObject? _module;
  int _handle = 0;
  JSFunction? _destroyHandle;
  JSFunction? _phonemizeHandle;
  JSFunction? _freeString;

  bool get isSupported => true;

  Future<void> load({
    required String rulesPath,
    required String listPath,
  }) async {
    await dispose();
    await _ensureRuntimeLoaded();

    final factory =
        _globalThis.getProperty(_runtimeFactoryName.toJS) as JSFunction;

    final module = await (factory.callMethod('call'.toJS, _globalThis)
            as JSPromise<JSObject>)
        .toDart;
    _ensureDir(module, '/cephonemizer');
    _fs(module).callMethod(
      'writeFile'.toJS,
      _virtualRulesPath.toJS,
      dictionaryTextForPath(rulesPath).toJS,
    );
    _fs(module).callMethod(
      'writeFile'.toJS,
      _virtualListPath.toJS,
      dictionaryTextForPath(listPath).toJS,
    );

    final createHandle = _cwrap(
      module,
      'phonemizer_create',
      'number',
      ['string', 'string', 'string'],
    );
    final destroyHandle = _cwrap(
      module,
      'phonemizer_destroy',
      null,
      ['number'],
    );
    final phonemizeHandle = _cwrap(
      module,
      'phonemizer_phonemize',
      'number',
      ['number', 'string'],
    );
    final freeString = _cwrap(
      module,
      'phonemizer_free_string',
      null,
      ['number'],
    );

    final handle = createHandle.callMethod(
      'call'.toJS,
      _globalThis,
      _virtualRulesPath.toJS,
      _virtualListPath.toJS,
      _dialect.toJS,
    ) as JSNumber;
    final handleInt = handle.toDartInt;
    if (handleInt == 0) {
      throw KittenTTSError.phonemizerFailed(
        'CEPhonemizer failed to load en_rules/en_list.',
      );
    }

    _module = module;
    _handle = handleInt;
    _destroyHandle = destroyHandle;
    _phonemizeHandle = phonemizeHandle;
    _freeString = freeString;
  }

  Future<String> phonemize(String text) async {
    final module = _module;
    final phonemizeHandle = _phonemizeHandle;
    final freeString = _freeString;
    if (module == null ||
        _handle == 0 ||
        phonemizeHandle == null ||
        freeString == null) {
      throw KittenTTSError.phonemizerFailed(
        'CEPhonemizer data is not ready. Call downloadIfNeeded() before phonemize().',
      );
    }

    final result = phonemizeHandle.callMethod(
      'call'.toJS,
      _globalThis,
      _handle.toJS,
      text.toJS,
    ) as JSNumber;
    final resultPtr = result.toDartInt;
    if (resultPtr == 0) {
      throw KittenTTSError.phonemizerFailed(
        'CEPhonemizer failed to phonemize text.',
      );
    }

    try {
      return (module.callMethod('UTF8ToString'.toJS, resultPtr.toJS)
              as JSString)
          .toDart;
    } finally {
      freeString.callMethod('call'.toJS, _globalThis, resultPtr.toJS);
    }
  }

  Future<void> dispose() async {
    if (_handle != 0 && _destroyHandle != null) {
      _destroyHandle!.callMethod('call'.toJS, _globalThis, _handle.toJS);
    }
    _handle = 0;
    _module = null;
    _destroyHandle = null;
    _phonemizeHandle = null;
    _freeString = null;
  }
}

Future<void> _ensureRuntimeLoaded() {
  if (_globalThis.has(_runtimeFactoryName)) return Future.value();
  final existing = _runtimeLoad;
  if (existing != null) return existing;

  final document = _document;
  if (document == null) {
    throw KittenTTSError.phonemizerFailed(
      'CEPhonemizer web runtime can only be loaded in a browser document.',
    );
  }

  final completer = Completer<void>();
  final script =
      document.callMethod('createElement'.toJS, 'script'.toJS) as JSObject;
  script.setProperty('src'.toJS, _runtimeScriptPath.toJS);
  script.setProperty('async'.toJS, true.toJS);
  script.setProperty(
    'onload'.toJS,
    (() {
      completer.complete();
    }).toJS,
  );
  script.setProperty(
    'onerror'.toJS,
    (() {
      completer.completeError(
        KittenTTSError.phonemizerFailed(
          'Failed to load CEPhonemizer web runtime at $_runtimeScriptPath.',
        ),
      );
    }).toJS,
  );
  final head = document.getProperty('head'.toJS) as JSObject;
  head.callMethod('appendChild'.toJS, script);
  _runtimeLoad = completer.future;
  return _runtimeLoad!;
}

JSObject _fs(JSObject module) => module.getProperty('FS'.toJS) as JSObject;

void _ensureDir(JSObject module, String path) {
  try {
    _fs(module).callMethod('mkdir'.toJS, path.toJS);
  } catch (_) {
    // Emscripten throws if the directory already exists.
  }
}

JSFunction _cwrap(
  JSObject module,
  String ident,
  String? returnType,
  List<String> argTypes,
) {
  return module.callMethodVarArgs('cwrap'.toJS, [
    ident.toJS,
    returnType?.toJS,
    argTypes.map((arg) => arg.toJS).toList().toJS,
  ]) as JSFunction;
}
