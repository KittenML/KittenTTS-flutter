import 'dart:async';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart' as audio;
import 'package:flutter/material.dart';
import 'package:kittentts_flutter/kittentts_flutter.dart';

void main() {
  runApp(const WordTimingsExampleApp());
}

enum WorkKind { ready, preparing, loading, generating, playing, error }

const _model = 'nano-int8';
const _speeds = [0.75, 1.0, 1.25, 1.5];

const _background = Color(0xFFFAFAFA);
const _foreground = Color(0xFF09090B);
const _muted = Color(0xFF71717A);
const _mutedForeground = Color(0xFF52525B);
const _border = Color(0xFFE4E4E7);
const _primary = Color(0xFF18181B);
const _chip = Color(0xFFF4F4F5);
const _chipSelected = Color(0xFFD4D4D8);

class WordTimingsExampleApp extends StatelessWidget {
  const WordTimingsExampleApp({super.key});

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
      home: const WordTimingsPage(),
    );
  }
}

class WordTimingsPage extends StatefulWidget {
  const WordTimingsPage({super.key});

  @override
  State<WordTimingsPage> createState() => _WordTimingsPageState();
}

class _WordTimingsPageState extends State<WordTimingsPage> {
  final _textController = TextEditingController(
    text:
        'KittenTTS runs fully on device and returns word-level timestamps. Generate this paragraph to see when each word starts and ends in the audio.',
  );
  final _player = TimingAudioPlayer();

  KittenTTS? _tts;
  KittenTTSResult? _result;
  Timer? _highlightTimer;
  WorkKind _state = WorkKind.ready;
  KittenTTSVoiceId _voice = 'bella';
  double _speed = 1;
  double _progress = 0;
  int? _activeWordIndex;
  String _statusMessage = 'Ready to load the model.';
  bool _modelCached = false;

  bool get _busy =>
      _state == WorkKind.preparing ||
      _state == WorkKind.loading ||
      _state == WorkKind.generating ||
      _state == WorkKind.playing;

  @override
  void dispose() {
    _highlightTimer?.cancel();
    _highlightTimer = null;
    _textController.dispose();
    _tts?.dispose();
    _player.stop();
    super.dispose();
  }

  Future<KittenTTS> _getTTS() async {
    final loaded = _tts;
    if (loaded != null) return loaded;

    setState(() {
      _state = WorkKind.preparing;
      _progress = 0;
      _statusMessage = 'Preparing model and phonemizer...';
    });

    final cached = (await KittenTTS.cacheInfo(
      const KittenTTSConfig(model: _model),
    )).isCached;
    final instance = await KittenTTS.create(
      config: KittenTTSConfig(model: _model, defaultVoice: _voice),
      player: _player,
      onProgress: (progress, [info]) {
        if (!mounted || info?.stage.name != 'downloading') return;
        setState(() {
          _state = WorkKind.loading;
          _progress = progress;
          _statusMessage = 'Downloading (${(progress * 100).round()}%)';
        });
      },
    );

    if (!mounted) {
      await instance.dispose();
      return instance;
    }

    setState(() {
      _tts = instance;
      _state = WorkKind.ready;
      _modelCached = true;
      _statusMessage = cached ? 'Loaded from cache.' : 'Downloaded and loaded.';
    });
    return instance;
  }

  Future<void> _generateOnly() async {
    if (_textController.text.trim().isEmpty) {
      _showError('Enter text before generating.');
      return;
    }

    try {
      _stopWordHighlighting();
      setState(() {
        _result = null;
        _state = WorkKind.generating;
        _statusMessage = 'Generating audio...';
      });
      final tts = await _getTTS();
      final result = await tts.generate(
        _textController.text,
        voice: _voice,
        speed: _speed,
      );
      if (!mounted) return;
      setState(() {
        _result = result;
        _state = WorkKind.ready;
        _statusMessage = 'Generated audio with word timings.';
      });
    } catch (error) {
      if (!mounted) return;
      _showError(_friendlyError(error));
    }
  }

  Future<void> _speak() async {
    if (_textController.text.trim().isEmpty) {
      _showError('Enter text before speaking.');
      return;
    }

    try {
      _stopWordHighlighting();
      setState(() {
        _result = null;
        _state = WorkKind.generating;
        _statusMessage = 'Generating audio...';
      });
      final tts = await _getTTS();
      final result = await tts.generate(
        _textController.text,
        voice: _voice,
        speed: _speed,
      );
      if (!mounted) return;
      setState(() {
        _result = result;
        _state = WorkKind.playing;
        _statusMessage = 'Playing with word highlighting...';
      });
      await tts.play(
        result,
        AudioPlayOptions(onPlaybackStart: () => _startWordHighlighting(result)),
      );
      if (!mounted) return;
      _stopWordHighlighting();
      setState(() {
        _state = WorkKind.ready;
        _statusMessage = 'Playback finished.';
      });
    } catch (error) {
      if (!mounted) return;
      _stopWordHighlighting();
      _showError(_friendlyError(error));
    }
  }

  void _startWordHighlighting(KittenTTSResult result) {
    _stopWordHighlighting();
    if (result.wordTimings.isEmpty) return;

    final startedAt = DateTime.now();
    _highlightTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (!mounted) return;
      final elapsedSeconds =
          DateTime.now().difference(startedAt).inMilliseconds / 1000;
      KittenWordTiming? active;
      for (final timing in result.wordTimings) {
        if (elapsedSeconds >= timing.startTime &&
            elapsedSeconds < timing.endTime) {
          active = timing;
          break;
        }
      }
      setState(() => _activeWordIndex = active?.wordIndex);
    });
  }

  void _stopWordHighlighting() {
    _highlightTimer?.cancel();
    _highlightTimer = null;
    if (mounted) setState(() => _activeWordIndex = null);
  }

  void _showError(String message) {
    setState(() {
      _state = WorkKind.error;
      _statusMessage = message;
    });
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    final canSubmit = !_busy && _textController.text.trim().isNotEmpty;

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
                  subtitle:
                      'Word timings example of the Flutter SDK for KittenTTS',
                ),
                _DemoCard(
                  children: [
                    _ModelRow(
                      model: modelDisplayName(_model),
                      cacheLabel: _cacheLabel(_state, _progress, _modelCached),
                    ),
                    _FieldGroup(
                      label: 'Text',
                      child: TextField(
                        controller: _textController,
                        enabled: !_busy,
                        minLines: 5,
                        maxLines: 8,
                        onChanged: (_) => setState(() => _result = null),
                        decoration: _inputDecoration('Type a sentence'),
                        style: const TextStyle(
                          color: _foreground,
                          fontSize: 15,
                          height: 1.45,
                        ),
                      ),
                    ),
                    _VoicePicker(
                      selected: _voice,
                      disabled: _busy,
                      onSelect: (voice) {
                        setState(() {
                          _voice = voice;
                          _result = null;
                        });
                      },
                    ),
                    _SpeedPicker(
                      selected: _speed,
                      disabled: _busy,
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
                                onPressed: _generateOnly,
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
                      ],
                    ),
                    _StatusPanel(state: _state, message: _statusMessage),
                    if (result != null)
                      _ResultPanel(
                        result: result,
                        activeWordIndex: _activeWordIndex,
                      ),
                    const _Disclaimer(
                      text:
                          'This system is for demonstration purposes only and is not intended to process sensitive or personal data.',
                    ),
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

class TimingAudioPlayer implements AudioPlayer {
  final _player = audio.AudioPlayer();

  @override
  Future<void> play(
    Float32List samples,
    int sampleRate, {
    AudioPlayOptions options = const AudioPlayOptions(),
  }) async {
    final completed = _player.onPlayerComplete.first;
    final wav = WAVEncoder.encode(samples, sampleRate);
    await _player.stop();
    await _player.play(audio.BytesSource(wav, mimeType: 'audio/wav'));
    options.onPlaybackStart?.call();
    await Future.any([
      completed,
      Future<void>.delayed(
        Duration(
          milliseconds: (samples.length / sampleRate * 1000).ceil() + 750,
        ),
      ),
    ]);
  }

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> resume() => _player.resume();

  @override
  bool get isPlaying => _player.state == audio.PlayerState.playing;
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

class _VoicePicker extends StatelessWidget {
  const _VoicePicker({
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

class _SpeedPicker extends StatelessWidget {
  const _SpeedPicker({
    required this.selected,
    required this.disabled,
    required this.onSelect,
  });

  final double selected;
  final bool disabled;
  final void Function(double speed) onSelect;

  @override
  Widget build(BuildContext context) {
    return _FieldGroup(
      label: 'Speed: ${_speedLabel(selected)}',
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final speed in _speeds)
            _OptionChip(
              label: _speedLabel(speed),
              active: speed == selected,
              disabled: disabled,
              onPressed: () => onSelect(speed),
            ),
        ],
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

class _StatusPanel extends StatelessWidget {
  const _StatusPanel({required this.state, required this.message});

  final WorkKind state;
  final String message;

  @override
  Widget build(BuildContext context) {
    final error = state == WorkKind.error;
    final busy =
        state == WorkKind.preparing ||
        state == WorkKind.loading ||
        state == WorkKind.generating ||
        state == WorkKind.playing;
    if (!busy && !error) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 16),
      child: Row(
        children: [
          if (busy)
            const SizedBox.square(
              dimension: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          if (busy) const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
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
  const _ResultPanel({required this.result, required this.activeWordIndex});

  final KittenTTSResult result;
  final int? activeWordIndex;

  @override
  Widget build(BuildContext context) {
    final timings = result.wordTimings;
    final transcriptWords = timings.take(80).toList();
    final visibleTimings = timings.take(24).toList();

    return Container(
      margin: const EdgeInsets.only(top: 18),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _background,
        border: Border.all(color: _border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _Metric(
                  label: 'Duration',
                  value: '${result.duration.toStringAsFixed(2)}s',
                ),
              ),
              Expanded(
                child: _Metric(label: 'Words', value: '${timings.length}'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const _Label('Transcript'),
          if (transcriptWords.isNotEmpty)
            _Transcript(
              words: transcriptWords,
              activeWordIndex: activeWordIndex,
            )
          else
            const Text(
              'No word timings returned for this text.',
              style: TextStyle(color: _muted, fontSize: 13),
            ),
          const SizedBox(height: 16),
          const _Label('Word timings'),
          if (visibleTimings.isNotEmpty)
            Column(
              children: [
                for (final timing in visibleTimings)
                  _TimingRow(
                    timing: timing,
                    active: activeWordIndex == timing.wordIndex,
                  ),
              ],
            )
          else
            const Text(
              'Try a shorter sentence or confirm this model build includes duration output.',
              style: TextStyle(color: _muted, fontSize: 13),
            ),
        ],
      ),
    );
  }
}

class _Transcript extends StatelessWidget {
  const _Transcript({required this.words, required this.activeWordIndex});

  final List<KittenWordTiming> words;
  final int? activeWordIndex;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 8,
      children: [
        for (final word in words)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: activeWordIndex == word.wordIndex ? _primary : _chip,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              word.word,
              style: TextStyle(
                color: activeWordIndex == word.wordIndex
                    ? Colors.white
                    : _foreground,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }
}

class _TimingRow extends StatelessWidget {
  const _TimingRow({required this.timing, required this.active});

  final KittenWordTiming timing;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: active ? _chipSelected : Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              timing.word,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _foreground,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            '${timing.startTime.toStringAsFixed(2)}s - ${timing.endTime.toStringAsFixed(2)}s',
            style: const TextStyle(
              color: _mutedForeground,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: _muted, fontSize: 12)),
        Text(
          value,
          style: const TextStyle(
            color: _foreground,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
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

String _cacheLabel(WorkKind state, double progress, bool cached) {
  return switch (state) {
    WorkKind.loading => 'Downloading (${(progress * 100).round()}%)',
    WorkKind.ready ||
    WorkKind.generating ||
    WorkKind.playing => cached ? 'Cached' : 'Not cached',
    WorkKind.error => 'Not cached',
    _ => 'Checking',
  };
}

String _speedLabel(double value) => '${value.toStringAsFixed(2)}x';

String _friendlyError(Object error) {
  final message = error is Error ? error.toString() : '$error';
  final lower = message.toLowerCase();

  if (lower.contains('download') ||
      lower.contains('network') ||
      lower.contains('http')) {
    return 'Download failed. Check the network connection and try again.';
  }
  if (lower.contains('playback')) {
    return 'Playback failed. Check the audio output for this platform.';
  }
  if (lower.contains('empty')) {
    return 'Enter text before generating speech.';
  }
  return message.isEmpty ? 'Something went wrong.' : message;
}
