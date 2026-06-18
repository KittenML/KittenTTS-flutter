import 'dart:async';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart' as audio;
import 'package:flutter/material.dart';
import 'package:kittentts/kittentts.dart';

void main() {
  runApp(const KittenTTSExampleApp());
}

enum WorkKind { booting, ready, preparing, loading, generating, playing, error }

const _models = ['nano-int8', 'nano', 'micro', 'mini'];
const _speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

const _background = Color(0xFFFAFAFA);
const _foreground = Color(0xFF09090B);
const _muted = Color(0xFF71717A);
const _mutedForeground = Color(0xFF52525B);
const _border = Color(0xFFE4E4E7);
const _primary = Color(0xFF18181B);
const _chip = Color(0xFFF4F4F5);
const _chipSelected = Color(0xFFD4D4D8);

class KittenTTSExampleApp extends StatelessWidget {
  const KittenTTSExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KittenTTS Example',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _primary,
          primary: _primary,
          surface: Colors.white,
        ),
        scaffoldBackgroundColor: _background,
      ),
      home: const KittenTTSExamplePage(),
    );
  }
}

class KittenTTSExamplePage extends StatefulWidget {
  const KittenTTSExamplePage({super.key});

  @override
  State<KittenTTSExamplePage> createState() => _KittenTTSExamplePageState();
}

class _KittenTTSExamplePageState extends State<KittenTTSExamplePage> {
  final _textController = TextEditingController(
    text:
        'Thank you for trying KittenTTS in this Flutter demo. This voice is generated on your device after the model assets are available.',
  );
  final _player = ExampleAudioPlayer();

  KittenTTS? _tts;
  KittenTTSResult? _result;
  WorkKind _state = WorkKind.booting;
  KittenTTSModelId _model = 'nano-int8';
  KittenTTSVoiceId _voice = 'bella';
  double _speed = 1;
  double _progress = 0;
  String? _errorMessage;

  bool get _busy =>
      _state == WorkKind.booting ||
      _state == WorkKind.preparing ||
      _state == WorkKind.loading ||
      _state == WorkKind.generating ||
      _state == WorkKind.playing;

  @override
  void initState() {
    super.initState();
    _loadModel(_model);
  }

  @override
  void dispose() {
    _textController.dispose();
    _tts?.dispose();
    unawaited(_player.dispose());
    super.dispose();
  }

  Future<void> _loadModel(KittenTTSModelId nextModel) async {
    setState(() {
      _state = WorkKind.preparing;
      _result = null;
      _errorMessage = null;
      _progress = 0;
    });

    try {
      await _tts?.dispose();
      final instance = await KittenTTS.create(
        config: KittenTTSConfig(model: nextModel),
        player: _player,
        onProgress: (progress, [info]) {
          if (!mounted) return;
          if (info?.stage.name == 'downloading') {
            setState(() {
              _state = WorkKind.loading;
              _progress = progress;
            });
          }
        },
      );
      if (!mounted) {
        await instance.dispose();
        return;
      }
      setState(() {
        _tts = instance;
        _state = WorkKind.ready;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _tts = null;
        _state = WorkKind.error;
        _errorMessage = _friendlyError(error);
      });
    }
  }

  void _selectModel(KittenTTSModelId model) {
    if (_busy || model == _model) return;
    setState(() => _model = model);
    _loadModel(model);
  }

  Future<void> _generate() async {
    final tts = _tts;
    final text = _textController.text;
    if (tts == null || text.trim().isEmpty) return;

    setState(() {
      _state = WorkKind.generating;
      _errorMessage = null;
    });
    try {
      final result = await tts.generate(text, voice: _voice, speed: _speed);
      if (!mounted) return;
      setState(() {
        _result = result;
        _state = WorkKind.ready;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _state = WorkKind.error;
        _errorMessage = _friendlyError(error);
      });
    }
  }

  Future<void> _speak() async {
    final tts = _tts;
    final text = _textController.text;
    if (tts == null || text.trim().isEmpty) return;

    setState(() {
      _state = WorkKind.playing;
      _errorMessage = null;
    });
    try {
      final result = await tts.speak(text, voice: _voice, speed: _speed);
      if (!mounted) return;
      setState(() {
        _result = result;
        _state = WorkKind.ready;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _state = WorkKind.error;
        _errorMessage = _friendlyError(error);
      });
    }
  }

  Future<void> _queueDemo() async {
    final tts = _tts;
    if (tts == null) return;

    final clips = [
      'This is the first queued clip.',
      'This is the second queued clip, generated after the first one finishes.',
      'The third clip confirms that the playback queue stays in order.',
    ];

    setState(() {
      _state = WorkKind.playing;
      _errorMessage = null;
    });

    final queue = tts.createPlaybackQueue();
    try {
      final futures = [
        for (final clip in clips)
          queue.enqueueText(clip, voice: _voice, speed: _speed),
      ];
      await Future.wait(futures);
      if (!mounted) return;
      setState(() => _state = WorkKind.ready);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _state = WorkKind.error;
        _errorMessage = _friendlyError(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    final canSubmit =
        !_busy && _tts != null && _textController.text.trim().isNotEmpty;
    final canQueue = !_busy && _tts != null;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 40),
              children: [
                const _Header(
                  title: 'KittenTTS Example',
                  subtitle: 'Flutter example of the Flutter SDK for KittenTTS',
                ),
                _DemoCard(
                  children: [
                    _ModelRow(
                      model: modelDisplayName(_model),
                      cacheLabel: _cacheLabel(_state, _progress),
                    ),
                    _FieldGroup(
                      label: 'Text',
                      child: TextField(
                        controller: _textController,
                        enabled: !_busy,
                        minLines: 5,
                        maxLines: 8,
                        onChanged: (_) => setState(() {}),
                        decoration: _inputDecoration(
                          'Enter something to speak',
                        ),
                        style: const TextStyle(
                          color: _foreground,
                          fontSize: 15,
                          height: 1.45,
                        ),
                      ),
                    ),
                    _OptionGroup<KittenTTSModelId>(
                      label: 'Model',
                      values: _models,
                      selected: _model,
                      disabled: _busy,
                      labelFor: modelDisplayName,
                      onSelect: _selectModel,
                    ),
                    _VoiceSelector(
                      selected: _voice,
                      disabled: _busy,
                      onSelect: (voice) {
                        setState(() {
                          _voice = voice;
                          _result = null;
                        });
                      },
                    ),
                    _OptionGroup<double>(
                      label: 'Speed: ${_speedLabel(_speed)}',
                      values: _speeds,
                      selected: _speed,
                      disabled: _busy,
                      labelFor: _speedLabel,
                      onSelect: (speed) {
                        setState(() {
                          _speed = speed;
                          _result = null;
                        });
                      },
                    ),
                    _ActionGroup(
                      label: 'Playback',
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _ActionButton(
                                label: 'Generate',
                                disabled: !canSubmit,
                                onPressed: _generate,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _ActionButton(
                                label: 'Speak',
                                primary: true,
                                disabled: !canSubmit,
                                onPressed: _speak,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _ActionButton(
                          label: 'Queue demo',
                          disabled: !canQueue,
                          onPressed: _queueDemo,
                        ),
                      ],
                    ),
                    _StatusPanel(
                      state: _state,
                      progress: _progress,
                      errorMessage: _errorMessage,
                    ),
                    const _Disclaimer(
                      text:
                          'This system is for demonstration purposes only and is not intended to process sensitive or personal data.',
                    ),
                    if (result != null) _ResultPanel(result: result),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ExampleAudioPlayer implements AudioPlayer {
  final _player = audio.AudioPlayer();
  StreamSubscription<void>? _completeSubscription;
  Completer<void>? _playbackCompleter;

  @override
  Future<void> play(
    Float32List samples,
    int sampleRate, {
    AudioPlayOptions options = const AudioPlayOptions(),
  }) async {
    final wav = WAVEncoder.encode(samples, sampleRate);
    await _player.stop();
    _finishPlayback();
    _playbackCompleter = Completer<void>();
    _completeSubscription = _player.onPlayerComplete.listen((_) {
      _finishPlayback();
    });
    final playbackDone = _playbackCompleter!.future;
    try {
      await _player.play(audio.BytesSource(wav, mimeType: 'audio/wav'));
    } catch (_) {
      _finishPlayback();
      rethrow;
    }
    options.onPlaybackStart?.call();
    return playbackDone;
  }

  @override
  Future<void> stop() async {
    await _player.stop();
    _finishPlayback();
  }

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> resume() => _player.resume();

  @override
  bool get isPlaying => _player.state == audio.PlayerState.playing;

  Future<void> dispose() async {
    await _completeSubscription?.cancel();
    _finishPlayback();
    await _player.dispose();
  }

  void _finishPlayback() {
    unawaited(_completeSubscription?.cancel() ?? Future.value());
    _completeSubscription = null;
    final completer = _playbackCompleter;
    _playbackCompleter = null;
    if (completer != null && !completer.isCompleted) {
      completer.complete();
    }
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: _border),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Image.asset('assets/kittenml_logo.png'),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: _foreground,
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                    height: 1.05,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 16,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DemoCard extends StatelessWidget {
  const _DemoCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _border),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

class _ModelRow extends StatelessWidget {
  const _ModelRow({required this.model, required this.cacheLabel});

  final String model;
  final String cacheLabel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        children: [
          const Text(
            'Model',
            style: TextStyle(
              color: _foreground,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 8),
          _Pill(cacheLabel),
          const Spacer(),
          Flexible(child: _SoftBadge(model)),
        ],
      ),
    );
  }
}

class _StatusPanel extends StatelessWidget {
  const _StatusPanel({
    required this.state,
    required this.progress,
    required this.errorMessage,
  });

  final WorkKind state;
  final double progress;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    if (state == WorkKind.ready) return const SizedBox.shrink();

    final error = state == WorkKind.error;
    final text = error
        ? errorMessage ?? 'Something went wrong.'
        : switch (state) {
            WorkKind.booting => 'Preparing...',
            WorkKind.preparing => 'Preparing model and phonemizer...',
            WorkKind.loading => 'Downloading (${(progress * 100).round()}%)',
            WorkKind.generating => 'Generating audio...',
            WorkKind.playing => 'Playing audio...',
            WorkKind.ready => '',
            WorkKind.error => '',
          };

    return Container(
      margin: const EdgeInsets.only(top: 16),
      child: Row(
        children: [
          if (!error)
            const SizedBox.square(
              dimension: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          if (!error) const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: error
                    ? const Color(0xFFB42318)
                    : const Color(0xFF854D0E),
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldGroup extends StatelessWidget {
  const _FieldGroup({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [_Label(label), child],
      ),
    );
  }
}

class _OptionGroup<T> extends StatelessWidget {
  const _OptionGroup({
    required this.label,
    required this.values,
    required this.selected,
    required this.disabled,
    required this.labelFor,
    required this.onSelect,
  });

  final String label;
  final Iterable<T> values;
  final T selected;
  final bool disabled;
  final String Function(T value) labelFor;
  final void Function(T value) onSelect;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Label(label),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final value in values)
                _OptionChip(
                  label: labelFor(value),
                  active: value == selected,
                  disabled: disabled,
                  onPressed: () => onSelect(value),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _VoiceSelector extends StatelessWidget {
  const _VoiceSelector({
    required this.selected,
    required this.disabled,
    required this.onSelect,
  });

  final KittenTTSVoiceId selected;
  final bool disabled;
  final void Function(KittenTTSVoiceId voice) onSelect;

  @override
  Widget build(BuildContext context) {
    return _FieldGroup(
      label: 'Voice',
      child: DropdownButtonFormField<KittenTTSVoiceId>(
        key: ValueKey(selected),
        initialValue: selected,
        isExpanded: true,
        menuMaxHeight: 320,
        borderRadius: BorderRadius.circular(10),
        dropdownColor: Colors.white,
        decoration: _inputDecoration('Select a voice'),
        style: const TextStyle(
          color: _foreground,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
        items: [
          for (final voice in allKittenTTSVoiceIds)
            DropdownMenuItem(
              value: voice,
              child: Text(
                voiceDisplayName(voice),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
        onChanged: disabled
            ? null
            : (voice) {
                if (voice != null) onSelect(voice);
              },
      ),
    );
  }
}

class _ActionGroup extends StatelessWidget {
  const _ActionGroup({required this.label, required this.children});

  final String label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 2),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _chip,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: _mutedForeground,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }
}

class _OptionChip extends StatelessWidget {
  const _OptionChip({
    required this.label,
    required this.active,
    required this.disabled,
    required this.onPressed,
  });

  final String label;
  final bool active;
  final bool disabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: disabled ? 0.48 : 1,
      child: OutlinedButton(
        onPressed: disabled ? null : onPressed,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 38),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          backgroundColor: active ? _chipSelected : _chip,
          foregroundColor: active ? _foreground : _mutedForeground,
          side: BorderSide.none,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        child: Text(label),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.disabled,
    required this.onPressed,
    this.primary = false,
  });

  final String label;
  final bool disabled;
  final bool primary;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: disabled ? null : onPressed,
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(46),
        backgroundColor: primary ? _primary : _chip,
        foregroundColor: primary ? Colors.white : _foreground,
        disabledBackgroundColor: primary ? const Color(0xFFA1A1AA) : _chip,
        disabledForegroundColor: primary ? Colors.white : _mutedForeground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
      child: Text(label),
    );
  }
}

class _ResultPanel extends StatelessWidget {
  const _ResultPanel({required this.result});

  final KittenTTSResult result;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 18),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _background,
        border: Border.all(color: _border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          _ResultRow(label: 'Voice', value: voiceDisplayName(result.voice)),
          _ResultRow(
            label: 'Duration',
            value: '${result.duration.toStringAsFixed(2)}s',
          ),
          _ResultRow(
            label: 'Samples',
            value: _formatInt(result.samples.length),
          ),
          _ResultRow(
            label: 'Sample rate',
            value: '${_formatInt(result.sampleRate)} Hz',
          ),
        ],
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: _muted, fontSize: 13),
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: _foreground,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Disclaimer extends StatelessWidget {
  const _Disclaimer({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 28),
      child: Text(
        text,
        style: const TextStyle(color: _muted, fontSize: 13, height: 1.45),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          color: _foreground,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _chip,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: _mutedForeground,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _SoftBadge extends StatelessWidget {
  const _SoftBadge(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: _chip,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.right,
        style: const TextStyle(
          color: _mutedForeground,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

InputDecoration _inputDecoration(String hint) {
  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: _muted),
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.all(14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: _border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: _border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: _primary),
    ),
  );
}

String _cacheLabel(WorkKind state, double progress) {
  return switch (state) {
    WorkKind.loading => 'Downloading (${(progress * 100).round()}%)',
    WorkKind.ready || WorkKind.generating || WorkKind.playing => 'Cached',
    WorkKind.error => 'Not cached',
    _ => 'Checking',
  };
}

String _speedLabel(double value) =>
    '${value.toStringAsFixed(2).replaceFirst(RegExp(r'0$'), '')}x';

String _formatInt(int value) {
  final text = value.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < text.length; i += 1) {
    if (i > 0 && (text.length - i) % 3 == 0) buffer.write(',');
    buffer.write(text[i]);
  }
  return buffer.toString();
}

String _friendlyError(Object error) {
  final message = error is Error ? error.toString() : '$error';
  final lower = message.toLowerCase();

  if (lower.contains('onnxruntime') || lower.contains('native')) {
    return 'This example needs a native Flutter build because it uses on-device inference.';
  }
  if (lower.contains('download') ||
      lower.contains('network') ||
      lower.contains('http')) {
    return 'Could not download the model assets. Check the network connection and try again.';
  }
  return message.isEmpty ? 'Something went wrong.' : message;
}
