import 'dart:math';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';

/// Procedural audio for Sliding Puzzle — all sounds synthesized in code as
/// WAV bytes. No asset files. Warm workshop sounds: wood, brass, canvas.
///
/// Reliability design (every call is safe to repeat and safe to overlap):
/// - Music clips are synthesized ONCE and cached; starting music never blocks
///   the UI thread after the first build.
/// - A [_musicGen] generation counter serializes track changes: every
///   start/stop bumps the generation, in-flight work from an older request
///   aborts, and the LATEST request always wins.
/// - Lifecycle uses pause()/resume() so an interruption resumes exactly
///   where it left off instead of restarting or dying.
/// - Every public method catches player errors; audio can never crash the app.
class WorkshopAudio {
  /// Per-game pitch character (slidingpuzzle): 1.22x. Makes SFX unique.
  static const double _pitchMul = 1.220;

  static const int _rate = 22050;
  final AudioPlayer _sfx = AudioPlayer();
  final AudioPlayer _music = AudioPlayer();
  final _rand = Random();

  bool musicOn = true;
  bool sfxOn = true;
  double volume = 0.8;

  final Map<String, Uint8List> _cache = {};

  bool _musicBusy = false;
  String? _currentTrack; // 'menu' | 'game' | null
  bool _pausedByLifecycle = false;
  bool _disposed = false;

  WorkshopAudio() {
    _music.setReleaseMode(ReleaseMode.loop);
  }

  void configure(
      {required bool musicOn, required bool sfxOn, required double volume}) {
    this.musicOn = musicOn;
    this.sfxOn = sfxOn;
    volume = volume.clamp(0.0, 1.0);
    this.volume = volume;
    _music.setVolume(musicOn ? volume * 0.55 : 0.0);
    _sfx.setVolume(sfxOn ? volume : 0.0);
    if (!musicOn) {
      stopMusic();
    }
  }

  /// Pre-build music clips off the critical path. Safe to call any time.
  Future<void> prewarm() async {
    if (_disposed) return;
    await Future(() {});
    _menuBytes();
    _gameBytes();
  }

  // ---------------------------------------------------------- WAV synthesis
  Uint8List _wav(List<double> samples) {
    final n = samples.length;
    final data = ByteData(44 + n * 2);
    void writeStr(int o, String s) {
      for (int i = 0; i < s.length; i++) {
        data.setUint8(o + i, s.codeUnitAt(i));
      }
    }

    writeStr(0, 'RIFF');
    data.setUint32(4, 36 + n * 2, Endian.little);
    writeStr(8, 'WAVE');
    writeStr(12, 'fmt ');
    data.setUint32(16, 16, Endian.little);
    data.setUint16(20, 1, Endian.little);
    data.setUint16(22, 1, Endian.little);
    data.setUint32(24, _rate, Endian.little);
    data.setUint32(28, _rate * 2, Endian.little);
    data.setUint16(32, 2, Endian.little);
    data.setUint16(34, 16, Endian.little);
    writeStr(36, 'data');
    data.setUint32(40, n * 2, Endian.little);
    for (int i = 0; i < n; i++) {
      final v = samples[i].clamp(-1.0, 1.0);
      data.setInt16(44 + i * 2, (v * 32767).round(), Endian.little);
    }
    return data.buffer.asUint8List();
  }

  double _env(int i, int n, {double attack = 0.02, double decayPow = 2.2}) {
    final t = i / n;
    final a = (t / attack).clamp(0.0, 1.0);
    final d = pow(1 - t, decayPow).toDouble();
    return a * d;
  }

  List<double> _tone(double freq, double secs,
      {double freqEnd = 0, double attack = 0.02, double harmonics = 0.25}) {
    freq *= _pitchMul;
    freqEnd *= _pitchMul;
    final n = (_rate * secs).round();
    final out = List<double>.filled(n, 0);
    for (int i = 0; i < n; i++) {
      final t = i / _rate;
      final f = freqEnd > 0 ? freq + (freqEnd - freq) * (i / n) : freq;
      final ph = 2 * pi * f * t;
      out[i] = _env(i, n, attack: attack) *
          (sin(ph) + harmonics * sin(2 * ph) + harmonics * 0.5 * sin(3 * ph));
    }
    return out;
  }

  /// Wooden slide thunk: low thump + soft knock tail.
  List<double> _thunk() {
    final n = (_rate * 0.16).round();
    final out = List<double>.filled(n, 0);
    for (int i = 0; i < n; i++) {
      final t = i / _rate;
      out[i] = _env(i, n, attack: 0.004) *
          (0.85 * sin(2 * pi * 155 * t) * exp(-t * 26) +
              0.45 * sin(2 * pi * 310 * t) * exp(-t * 48) +
              0.22 * (_rand.nextDouble() * 2 - 1) * exp(-t * 110));
    }
    return out;
  }

  /// Dull knock for invalid taps.
  List<double> _dullKnock() {
    final n = (_rate * 0.2).round();
    final out = List<double>.filled(n, 0);
    for (int i = 0; i < n; i++) {
      final t = i / _rate;
      out[i] = _env(i, n, attack: 0.006) *
          (0.7 * sin(2 * pi * 120 * t) * exp(-t * 22) +
              0.2 * (_rand.nextDouble() * 2 - 1) * exp(-t * 70));
    }
    return out;
  }

  /// Brass chime (hint): bright struck metal with long shimmer.
  List<double> _chime() {
    final n = (_rate * 0.9).round();
    final out = List<double>.filled(n, 0);
    const base = 880.0;
    for (int i = 0; i < n; i++) {
      final t = i / _rate;
      out[i] = _env(i, n, attack: 0.005, decayPow: 3.2) *
          (0.6 * sin(2 * pi * base * t) * exp(-t * 4) +
              0.35 * sin(2 * pi * base * 2.76 * t) * exp(-t * 7) +
              0.2 * sin(2 * pi * base * 5.4 * t) * exp(-t * 11));
    }
    return out;
  }

  List<double> _arp(List<double> freqs, double noteSecs, double gapSecs,
      {double harmonics = 0.25}) {
    final out = <double>[];
    for (final f in freqs) {
      out.addAll(_tone(f, noteSecs, harmonics: harmonics));
      out.addAll(List<double>.filled((_rate * gapSecs).round(), 0));
    }
    return out;
  }

  List<double> _padChord(List<double> freqs, double secs) {
    final n = (_rate * secs).round();
    final out = List<double>.filled(n, 0);
    for (int i = 0; i < n; i++) {
      double v = 0;
      for (final f in freqs) {
        final t = i / _rate;
        v += sin(2 * pi * f * t) + 0.3 * sin(2 * pi * f * 2 * t);
      }
      v /= freqs.length * 1.3;
      final t = i / n;
      final swell = sin(pi * t.clamp(0.0, 1.0));
      out[i] = v * (0.35 + 0.65 * swell);
    }
    return out;
  }

  Uint8List _clip(String key, List<double> Function() build) =>
      _cache.putIfAbsent(key, () => _wav(build()));

  Uint8List _menuBytes() => _clip('music_menu', () {
        // A arpeggiated 0 – 5 – 3 – 4, 16s loop. Unique to slidingpuzzle.
        final notes = [220.00, 277.18, 329.63, 277.18, 369.99, 440.00, 554.37, 440.00, 293.66, 369.99, 440.00, 369.99, 329.63, 415.30, 493.88, 415.30];
        final out = <double>[];
        final noteLen = 16.0 / notes.length;
        for (final n in notes) {
          out.addAll(_tone(n, noteLen * 0.9, harmonics: 0.3));
          final gap = List<double>.filled((_rate * noteLen * 0.1).round(), 0);
          out.addAll(gap);
        }
        // Soft pad underneath
        final pad = _padChord([220.00, 277.18, 329.63], 16.0);
        for (int i = 0; i < out.length && i < pad.length; i++) {
          out[i] += pad[i] * 0.3;
        }
        return out;
      });


  Uint8List _gameBytes() => _clip('music_game', () {
        // A waltz 0 – 5 – 3 – 4, 12s loop. Unique to slidingpuzzle.
        final seq = [
          [220.00, 277.18, 329.63],
          [369.99, 440.00, 554.37],
          [293.66, 369.99, 440.00],
          [329.63, 415.30, 493.88]
        ];
        final out = <double>[];
        for (final chord in seq) {
          // Waltz: bass on 1, chords on 2 and 3
          final bass = _tone(chord[0] / 2, 0.8, harmonics: 0.3);
          final ch1 = _padChord([chord[1], chord[2]], 0.7);
          final ch2 = _padChord([chord[1], chord[2]], 0.7);
          out.addAll(bass);
          final gap1 = List<double>.filled((_rate * 0.2).round(), 0);
          out.addAll(gap1);
          out.addAll(ch1);
          final gap2 = List<double>.filled((_rate * 0.2).round(), 0);
          out.addAll(gap2);
          out.addAll(ch2);
          final gap3 = List<double>.filled((_rate * 0.2).round(), 0);
          out.addAll(gap3);
        }
        return out;
      });


  // ------------------------------------------------------------------ SFX
  Future<void> _play(Uint8List bytes) async {
    if (!sfxOn || _disposed) return;
    try {
      await _sfx.play(BytesSource(bytes));
    } catch (_) {}
  }

  Future<void> click() => _play(_clip('click', () => _tone(1050, 0.06)));
  Future<void> slide() => _play(_clip('slide', _thunk));
  Future<void> multiSlide() => _play(_clip(
      'multislide',
      () => [..._thunk(), ...List.filled((_rate * 0.03).round(), 0.0), ..._thunk()]));
  Future<void> invalid() => _play(_clip('invalid', _dullKnock));
  Future<void> undo() =>
      _play(_clip('undo', () => _tone(520, 0.18, freqEnd: 330)));
  Future<void> hint() => _play(_clip('hint', _chime));
  Future<void> gameStart() =>
      _play(_clip('start', () => _tone(330, 0.4, freqEnd: 660)));
  Future<void> win() => _play(_clip(
      'win',
      () => _arp([392.0, 523.25, 659.25, 783.99, 1046.5, 1318.5],
          0.17, 0.03,
          harmonics: 0.3)));
  Future<void> lose() => _play(_clip(
      'lose', () => _arp([329.63, 293.66, 261.63, 196.0], 0.26, 0.05)));

  // ----------------------------------------------------------------- music

  // BGM disabled per user request 2026-10-10 — SFX only.
  Future<void> startMenuMusic() async {}
  Future<void> startGameMusic() async {}

  /// App-scoped stop: only when the user turns music OFF — never on
  /// screen navigation.
  Future<void> stopMusic() async {
    while (_musicBusy) {
      await Future.delayed(const Duration(milliseconds: 30));
    }
    if (_disposed) return;
    try {
      await _music.stop();
    } catch (_) {}
    _currentTrack = null;
    _pausedByLifecycle = false;
  }

  Future<void> onAppPaused() async {
    if (_disposed || _currentTrack == null) return;
    try {
      await _music.pause();
      _pausedByLifecycle = true;
    } catch (_) {}
  }

  Future<void> onAppResumed() async {
    if (_disposed || !musicOn || !_pausedByLifecycle) return;
    _pausedByLifecycle = false;
    try {
      await _music.resume();
    } catch (_) {
      final track = _currentTrack;
      _currentTrack = null;
      if (track == 'menu') {
        await startMenuMusic();
      } else if (track == 'game') {
        await startGameMusic();
      }
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    try {
      await _sfx.dispose();
      await _music.dispose();
    } catch (_) {}
  }
}
