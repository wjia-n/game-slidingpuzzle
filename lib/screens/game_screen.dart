import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../engine/sliding_engine.dart';
import '../services/audio_service.dart';
import '../services/settings_service.dart';
import '../theme/atelier.dart';
import '../theme/conservator_themes.dart';
import 'victory_screen.dart';

/// Board screen: carved oak frame, canvas tiles, brass status plinth and
/// round control buttons. Matches the Stitch board screen (DESIGN.md).
class GameScreen extends StatefulWidget {
  final WorkshopAudio audio;
  final WorkshopSettings settings;
  final int size;
  final GameMode mode;
  final bool cont;
  final int partyCount;
  const GameScreen({
    super.key,
    required this.audio,
    required this.settings,
    required this.size,
    required this.mode,
    this.cont = false,
    this.partyCount = 2,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _TileAnim {
  final int value;
  final double from;
  final double to;
  final int ms;
  final DateTime start = DateTime.now();
  _TileAnim(this.value, this.from, this.to, this.ms);
  double get t =>
      DateTime.now().difference(start).inMilliseconds / ms.clamp(1, 1 << 30);
}

double _settle(double t) {
  final c = t.clamp(0.0, 1.0);
  // Weighted settle: fast attack, smooth landing, whisper of overshoot.
  return 1 + 2.0 * pow(c - 1, 3) + 1.0 * pow(c - 1, 2);
}

class _GameScreenState extends State<GameScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  late final SlidingEngine engine;
  late final Ticker _ticker;

  // Visual tile positions: value -> fractional cell index.
  final Map<int, double> _pos = {};
  final List<_TileAnim> _anims = [];
  List<int>? _displayBoard; // non-null only during the scramble cascade
  bool _cascadeStarted = false;
  int _lastSlideId = 0;

  // Drag state.
  int _dragValue = -1;
  Offset _dragOffset = Offset.zero;
  Offset _dragBase = Offset.zero; // accumulated pan
  bool _dragging = false;

  // Invalid-tap shake.
  int _shakeCell = -1;
  DateTime? _shakeStart;
  int _pendingInvalidCell = -1;

  bool _showPause = false;
  bool _showGameOver = false;
  String _gameOverReason = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    engine = SlidingEngine();
    engine.onEvent = _onEngineEvent;
    engine.addListener(_onEngineChanged);
    _ticker = createTicker(_onTick)..start();
    widget.audio.startGameMusic();
    if (widget.cont) {
      engine.loadSave().then((ok) {
        if (!mounted) return;
        if (!ok) {
          _newGame();
        } else {
          _syncPos();
        }
      });
    } else {
      _newGame();
    }
  }

  void _newGame() {
    int? seed;
    if (widget.mode == GameMode.daily) {
      final now = DateTime.now();
      seed = now.year * 10000 + now.month * 100 + now.day;
    }
    List<String>? party;
    if (widget.mode == GameMode.party) {
      final count = widget.partyCount.clamp(2, 4);
      party = widget.settings.partyNames.sublist(0, count);
    }
    setState(() {
      _showPause = false;
      _showGameOver = false;
      _cascadeStarted = false;
      _cascadeGen++; // retire any in-flight cascade
      _displayBoard = null;
      _anims.clear();
      _pos.clear();
    });
    engine.newGame(n: widget.size, m: widget.mode, seed: seed, party: party);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker.dispose();
    engine.removeListener(_onEngineChanged);
    engine.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------- lifecycle
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      widget.audio.onAppPaused();
      engine.setPaused(true); // RULES.md §12: timer pauses on backgrounding
    } else if (state == AppLifecycleState.resumed) {
      widget.audio.onAppResumed();
      if (engine.phase == SlidePhase.paused && mounted) {
        if (engine.resumeNeedsOverlay) {
          // A live game was interrupted: wait behind the pause overlay.
          setState(() => _showPause = true);
        } else {
          // Scrambling/ready pause: resume silently, no overlay needed.
          engine.setPaused(false);
        }
      }
    }
  }

  // ------------------------------------------------------------- engine glue
  void _onEngineChanged() {
    if (!mounted) return;
    if (engine.phase == SlidePhase.scrambling && !_cascadeStarted) {
      _cascadeStarted = true;
      _runCascade();
      return;
    }
    if (engine.slideId != _lastSlideId) {
      _lastSlideId = engine.slideId;
      for (final s in engine.lastSlide) {
        _anims.add(_TileAnim(s.value, s.from.toDouble(), s.to.toDouble(), 230));
      }
      _syncPos();
    }
    setState(() {});
  }

  void _syncPos() {
    final b = _displayBoard ?? engine.board;
    if (b.isEmpty) return;
    final animating = _anims.map((a) => a.value).toSet();
    for (int cell = 0; cell < b.length; cell++) {
      final v = b[cell];
      if (v != 0 && !animating.contains(v)) {
        _pos[v] = cell.toDouble();
      }
    }
  }

  void _onTick(Duration _) {
    if (!mounted) return;
    var dirty = false;
    final now = DateTime.now();
    _anims.removeWhere((a) {
      final t = a.t;
      if (t >= 1) {
        _pos[a.value] = a.to;
        dirty = true;
        return true;
      }
      _pos[a.value] = a.from + (a.to - a.from) * _settle(t);
      dirty = true;
      return false;
    });
    if (_shakeStart != null) {
      final e = now.difference(_shakeStart!).inMilliseconds;
      if (e > 380) {
        _shakeStart = null;
        _shakeCell = -1;
      }
      dirty = true;
    }
    if (dirty) setState(() {});
  }

  int _cascadeGen = 0; // bails stale cascades after a restart

  /// Waits while the engine is paused (backgrounded mid-cascade).
  /// Returns false when this cascade generation is stale or superseded.
  Future<bool> _holdWhilePaused(int gen) async {
    while (engine.phase == SlidePhase.paused &&
        mounted &&
        gen == _cascadeGen) {
      await Future.delayed(const Duration(milliseconds: 200));
    }
    return mounted &&
        gen == _cascadeGen &&
        engine.phase == SlidePhase.scrambling;
  }

  /// Animated scramble cascade: replays the tail of the recorded walk so
  /// the player SEES the tiles scatter into place.
  Future<void> _runCascade() async {
    final gen = _cascadeGen;
    final n = engine.size;
    final walk = engine.scrambleWalk;
    final cells = n * n;
    var b = List<int>.generate(cells, (i) => i == cells - 1 ? 0 : i + 1);
    var g = cells - 1;
    final keep = walk.length > 22 ? 22 : walk.length;
    final silentUpTo = walk.length - keep;
    for (int i = 0; i < silentUpTo; i++) {
      final ng = walk[i];
      b[g] = b[ng];
      b[ng] = 0;
      g = ng;
    }
    setState(() {
      _displayBoard = List.of(b);
      _syncPos();
    });
    await Future.delayed(const Duration(milliseconds: 250));
    if (!await _holdWhilePaused(gen)) return;
    for (int i = silentUpTo; i < walk.length; i++) {
      if (!await _holdWhilePaused(gen)) return;
      final ng = walk[i];
      final value = b[ng];
      final from = ng.toDouble();
      final to = g.toDouble();
      b[g] = value;
      b[ng] = 0;
      g = ng;
      _anims.add(_TileAnim(value, from, to, 55));
      if (mounted) {
        setState(() => _displayBoard = List.of(b));
      }
      await Future.delayed(const Duration(milliseconds: 62));
    }
    if (!mounted) return;
    // Let the last hops land, then hand the live board to the engine.
    await Future.delayed(const Duration(milliseconds: 120));
    if (!await _holdWhilePaused(gen)) return;
    setState(() {
      _displayBoard = null;
      _anims.clear();
      _syncPos();
    });
    engine.finishScramble();
  }

  void _onEngineEvent(SlideEvent e) {
    final audio = widget.audio;
    switch (e) {
      case SlideEvent.gameStart:
        audio.gameStart();
      case SlideEvent.slide:
        audio.slide();
      case SlideEvent.multiSlide:
        audio.multiSlide();
      case SlideEvent.invalid:
        audio.invalid();
        _shakeStart = DateTime.now();
        _shakeCell = _pendingInvalidCell;
      case SlideEvent.undo:
        audio.undo();
        _anims.clear();
        _syncPos();
      case SlideEvent.hint:
        audio.hint();
      case SlideEvent.win:
        audio.win();
        _onWin();
      case SlideEvent.lose:
        audio.lose();
        _onLose();
      case SlideEvent.tick:
        break;
    }
    _pendingInvalidCell = -1;
  }

  Future<void> _onWin() async {
    final s = widget.settings;
    final won = await s.recordSolve(
        size: engine.size, moves: engine.moves, seconds: engine.seconds);
    engine.newBest = won;
    if (widget.mode == GameMode.daily) {
      await s.recordDailySolve(DateTime.now());
    }
    await Future.delayed(const Duration(milliseconds: 650));
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => VictoryScreen(
          audio: widget.audio,
          settings: s,
          engine: engine,
        ),
      ),
    );
  }

  void _onLose() {
    if (!mounted || engine.phase != SlidePhase.over) return;
    setState(() {
      _gameOverReason = engine.result == SlideResult.timeUp
          ? 'The clock ran out — the restoration will have to wait.'
          : 'Out of moves — the budget is spent.';
      _showGameOver = true;
    });
  }

  // ------------------------------------------------------------- input
  int _cellOfValue(int value) {
    final b = _displayBoard ?? engine.board;
    return b.indexOf(value);
  }

  void _tapCell(int cell) {
    if (engine.phase == SlidePhase.scrambling) return;
    _pendingInvalidCell = cell;
    widget.audio.click();
    engine.tapTile(cell);
  }

  void _onPanStart(int value, DragStartDetails d) {
    _dragValue = value;
    _dragBase = Offset.zero;
    _dragging = false;
    _dragOffset = Offset.zero;
  }

  void _onPanUpdate(DragUpdateDetails d, double cellPx) {
    if (_dragValue < 0) return;
    if (engine.phase != SlidePhase.ready &&
        engine.phase != SlidePhase.playing) {
      return;
    }
    _dragBase += d.delta;
    if (!_dragging && _dragBase.distance > 10) _dragging = true;
    if (!_dragging) {
      setState(() {});
      return;
    }
    // Only the tile adjacent to the gap may be dragged, along its axis.
    final cell = _cellOfValue(_dragValue);
    final n = engine.size;
    final gr = engine.gap ~/ n, gc = engine.gap % n;
    final r = cell ~/ n, c = cell % n;
    Offset off = Offset.zero;
    if (r == gr && (c - gc).abs() == 1) {
      final dir = gc > c ? 1.0 : -1.0;
      off = Offset((_dragBase.dx * dir).clamp(0.0, cellPx) * dir, 0);
    } else if (c == gc && (r - gr).abs() == 1) {
      final dir = gr > r ? 1.0 : -1.0;
      off = Offset(0, (_dragBase.dy * dir).clamp(0.0, cellPx) * dir);
    }
    setState(() => _dragOffset = off);
  }

  void _onPanEnd(DragEndDetails d, double cellPx) {
    final value = _dragValue;
    final wasDrag = _dragging;
    final off = _dragOffset;
    _dragValue = -1;
    _dragging = false;
    _dragOffset = Offset.zero;
    if (value < 0) return;
    if (!wasDrag) {
      _tapCell(_cellOfValue(value)); // treated as a tap
      return;
    }
    // RULES.md §12: dragged >50% across the boundary completes the slide.
    if (off.distance > cellPx * 0.5) {
      engine.tapTile(_cellOfValue(value));
    } else {
      setState(() {}); // snap back (offset already zeroed)
    }
  }

  // ------------------------------------------------------------- build
  @override
  Widget build(BuildContext context) {
    final t = widget.settings.theme;
    return Scaffold(
      backgroundColor: t.backdrop,
      body: WoodBackdrop(
        theme: t,
        child: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  _topBar(t),
                  const SizedBox(height: 10),
                  _statusPlinth(t),
                  const SizedBox(height: 12),
                  Expanded(child: Center(child: _board(t))),
                  const SizedBox(height: 12),
                  _controls(t),
                  const SizedBox(height: 14),
                ],
              ),
              if (_showPause) _pauseOverlay(t),
              if (_showGameOver) _gameOverOverlay(t),
            ],
          ),
        ),
      ),
    );
  }

  Widget _topBar(AtelierTheme t) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          BrassRoundButton(
            theme: t,
            icon: Icons.arrow_back,
            tooltip: 'Menu',
            size: 44,
            onTap: () {
              widget.audio.click();
              Navigator.of(context).pop();
            },
          ),
          Expanded(
            child: Text(
              '${widget.size}×${widget.size} · ${widget.mode.label.toUpperCase()}',
              textAlign: TextAlign.center,
              style: AtelierType.label(12, t),
            ),
          ),
          if (widget.mode == GameMode.party && engine.partyNames.isNotEmpty)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: t.brass,
                border: Border.all(color: t.brassDark),
              ),
              child: Text(
                '🎭 ${engine.partyNames[engine.partyTurn % engine.partyNames.length]} to move',
                style: AtelierType.label(10, t, color: t.inkBrown),
              ),
            )
          else
            const SizedBox(width: 44),
        ],
      ),
    );
  }

  Widget _statusPlinth(AtelierTheme t) {
    final movesText = widget.mode == GameMode.challenge
        ? '${(SlidingScoring.parFor(engine.size) - engine.moves).clamp(0, 1 << 30)} LEFT'
        : '${engine.moves}';
    final timeText = widget.mode == GameMode.clock
        ? engine.formatTime(engine.remaining)
        : engine.formatTime(engine.seconds);
    final timeUrgent =
        widget.mode == GameMode.clock && engine.remaining <= 60;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [t.brassLight, t.brass, t.brassDark],
          stops: const [0.0, 0.5, 1.0],
        ),
        border: Border.all(color: t.brassDark, width: 1.5),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.55),
              offset: const Offset(0, 4),
              blurRadius: 8),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _plinthStat(t, widget.mode == GameMode.challenge ? 'MOVES' : 'MOVES',
              movesText),
          Container(width: 1.5, height: 30, color: t.brassDark),
          _plinthStat(
              t,
              widget.mode == GameMode.clock ? 'REMAINING' : 'TIME',
              timeText,
              urgent: timeUrgent),
        ],
      ),
    );
  }

  Widget _plinthStat(AtelierTheme t, String label, String value,
      {bool urgent = false}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: AtelierType.label(9, t, color: t.inkBrown)),
        Text(value,
            style: AtelierType.plaqueTitle(19, t).copyWith(
                color: urgent ? const Color(0xFF7A2010) : t.inkBrown)),
      ],
    );
  }

  Widget _board(AtelierTheme t) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = min(constraints.maxWidth, constraints.maxHeight);
        final n = engine.size;
        final frameStyle = widget.settings.frameStyleEnum;
        // Frame padding shrinks the tile area: compute cell from the INNER size
        // so the last row/column stays inside the frame.
        final outerCell = side / n;
        final framePad = _framePad(frameStyle, outerCell);
        final inner = side - framePad * 2;
        final cell = inner / n;
        return Container(
          width: side,
          height: side,
          padding: EdgeInsets.all(framePad),
          decoration: _frameDecoration(t, frameStyle),
          child: Stack(
            children: [
              // Empty well, always at the logical gap.
              if ((_displayBoard ?? engine.board).isNotEmpty)
                _wellAt(t, (_displayBoard ?? engine.board).indexOf(0), cell),
              // Tiles by value.
              for (int v = 1; v < n * n; v++) _tileAt(t, v, cell),
            ],
          ),
        );
      },
    );
  }

  double _framePad(FrameStyle s, double cell) => switch (s) {
        FrameStyle.carved => cell * 0.28,
        FrameStyle.brassBound => cell * 0.22,
        FrameStyle.plainBevel => cell * 0.14,
        FrameStyle.museumCase => cell * 0.18,
      };

  BoxDecoration _frameDecoration(AtelierTheme t, FrameStyle s) {
    final baseShadows = [
      BoxShadow(
          color: Colors.black.withValues(alpha: 0.65),
          offset: const Offset(0, 8),
          blurRadius: 18),
      BoxShadow(
          color: t.spotlight.withValues(alpha: 0.22),
          offset: const Offset(-3, -4),
          blurRadius: 6),
    ];
    switch (s) {
      case FrameStyle.carved:
        return BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [t.woodLight, t.woodMid, t.woodDark],
            stops: const [0.0, 0.55, 1.0],
          ),
          border: Border.all(color: t.woodDark, width: 3),
          boxShadow: [
            ...baseShadows,
            const BoxShadow(
                color: Colors.black54,
                offset: Offset(0, 0),
                blurRadius: 2,
                blurStyle: BlurStyle.inner),
          ],
        );
      case FrameStyle.brassBound:
        return BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [t.woodMid, t.woodDark],
          ),
          border: Border.all(color: t.brass, width: 4),
          boxShadow: baseShadows,
        );
      case FrameStyle.plainBevel:
        return BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          color: t.woodMid,
          border: Border(
            top: BorderSide(color: t.woodLight, width: 3),
            left: BorderSide(color: t.woodLight, width: 3),
            bottom: BorderSide(color: t.woodDark, width: 3),
            right: BorderSide(color: t.woodDark, width: 3),
          ),
          boxShadow: baseShadows,
        );
      case FrameStyle.museumCase:
        return BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [t.woodDark, t.woodMid],
          ),
          border: Border.all(color: t.brassLight, width: 1.5),
          boxShadow: [
            ...baseShadows,
            BoxShadow(
                color: Colors.white.withValues(alpha: 0.08),
                offset: const Offset(-6, -8),
                blurRadius: 12),
          ],
        );
    }
  }

  Widget _wellAt(AtelierTheme t, int cellIdx, double cell) {
    if (cellIdx < 0) return const SizedBox.shrink();
    final n = engine.size;
    final pad = cell * 0.06;
    return Positioned(
      left: (cellIdx % n) * cell + pad,
      top: (cellIdx ~/ n) * cell + pad,
      width: cell - pad * 2,
      height: cell - pad * 2,
      child: EmptyWell(theme: t),
    );
  }

  Widget _tileAt(AtelierTheme t, int value, double cell) {
    final n = engine.size;
    final b = _displayBoard ?? engine.board;
    if (b.isEmpty) return const SizedBox.shrink();
    final logical = b.indexOf(value);
    if (logical < 0) return const SizedBox.shrink();
    final frac = _pos[value] ?? logical.toDouble();
    var col = frac % n;
    var row = (frac ~/ n).toDouble();
    // Clamp to the axis-aligned path for multi-tile diagonals (never happen,
    // but keeps rendering sane if a value is mid-flight).
    col = col.clamp(0.0, (n - 1).toDouble());
    row = row.clamp(0.0, (n - 1).toDouble());
    final pad = cell * 0.06;
    var dx = 0.0, dy = 0.0;
    if (value == _dragValue) {
      dx = _dragOffset.dx;
      dy = _dragOffset.dy;
    }
    if (logical == _shakeCell && _shakeStart != null) {
      final e = DateTime.now().difference(_shakeStart!).inMilliseconds;
      final k = (1 - e / 380).clamp(0.0, 1.0);
      dx += sin(e * 0.045) * 7 * k;
    }
    final hinted = engine.hintTile == logical && engine.hintTile >= 0;
    final style = widget.settings.tileStyleEnum;
    return Positioned(
      left: col * cell + pad + dx,
      top: row * cell + pad + dy,
      width: cell - pad * 2,
      height: cell - pad * 2,
      child: GestureDetector(
        onPanStart: (d) => _onPanStart(value, d),
        onPanUpdate: (d) => _onPanUpdate(d, cell),
        onPanEnd: (d) => _onPanEnd(d, cell),
        child: Container(
          decoration: hinted
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                        color: t.brassLight.withValues(alpha: 0.9),
                        blurRadius: 14,
                        spreadRadius: 2),
                  ],
                )
              : null,
          child: TileFace(
            theme: t,
            pressed: value == _dragValue && _dragging,
            numeral: tileNumeral(
                value, style, t, cell * (n >= 6 ? 0.34 : 0.42)),
          ),
        ),
      ),
    );
  }

  Widget _controls(AtelierTheme t) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        BrassRoundButton(
            theme: t,
            icon: Icons.pause,
            tooltip: 'Pause',
            onTap: _pause),
        const SizedBox(width: 18),
        BrassRoundButton(
          theme: t,
          icon: Icons.lightbulb_outline,
          tooltip: engine.hintUsed ? 'Hint used' : 'Hint (1 per game)',
          highlighted: engine.hintTile >= 0,
          onTap: engine.hintUsed ? null : () => engine.hint(),
        ),
        const SizedBox(width: 18),
        BrassRoundButton(
            theme: t,
            icon: Icons.undo,
            tooltip: 'Undo',
            onTap: () => engine.undo()),
        const SizedBox(width: 18),
        BrassRoundButton(
            theme: t,
            icon: Icons.refresh,
            tooltip: 'Restart',
            onTap: () {
              widget.audio.click();
              _newGame();
            }),
      ],
    );
  }

  void _pause() {
    widget.audio.click();
    engine.setPaused(true);
    setState(() => _showPause = true);
  }

  void _resume() {
    widget.audio.click();
    setState(() => _showPause = false);
    engine.setPaused(false);
  }

  Widget _pauseOverlay(AtelierTheme t) {
    final s = widget.settings;
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.55),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [t.woodMid, t.woodDark],
                ),
                border: Border.all(color: t.brass, width: 2.5),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.7),
                      offset: const Offset(0, 10),
                      blurRadius: 24),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  BrassPlaque(theme: t, text: 'PAUSED', fontSize: 18),
                  const SizedBox(height: 18),
                  OakButton(theme: t, label: 'RESUME', onTap: _resume),
                  const SizedBox(height: 10),
                  OakButton(
                    theme: t,
                    label: engine.hintUsed ? 'HINT USED' : 'USE HINT',
                    sublabel: 'One per game · caps stars at 2',
                    onTap: engine.hintUsed
                        ? null
                        : () {
                            _resume();
                            engine.hint();
                          },
                  ),
                  const SizedBox(height: 10),
                  OakButton(
                      theme: t,
                      label: 'RESTART',
                      onTap: () {
                        _newGame();
                      }),
                  const SizedBox(height: 10),
                  OakButton(
                    theme: t,
                    label: 'GIVE UP',
                    sublabel: 'Discard this attempt',
                    onTap: () {
                      widget.audio.click();
                      engine.giveUp();
                      Navigator.of(context).pop();
                    },
                  ),
                  const SizedBox(height: 16),
                  _toggleRow(t, 'Music', s.musicOn, (v) {
                    s.setMusic(v);
                    widget.audio.configure(
                        musicOn: v, sfxOn: s.sfxOn, volume: s.volume);
                    if (v) {
                      widget.audio.startGameMusic();
                    } else {
                      widget.audio.stopMusic();
                    }
                  }),
                  const SizedBox(height: 8),
                  _toggleRow(t, 'Sound FX', s.sfxOn, (v) {
                    s.setSfx(v);
                    widget.audio.configure(
                        musicOn: s.musicOn, sfxOn: v, volume: s.volume);
                  }),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () {
                      widget.audio.click();
                      Navigator.of(context).pop();
                    },
                    child: Text('Quit to menu',
                        style: AtelierType.label(13, t)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _toggleRow(
      AtelierTheme t, String label, bool value, ValueChanged<bool> onChanged) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AtelierType.label(13, t)),
        LeverToggle(theme: t, value: value, onChanged: onChanged),
      ],
    );
  }

  Widget _gameOverOverlay(AtelierTheme t) {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.6),
        child: Center(
          child: Container(
            margin: const EdgeInsets.all(32),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [t.woodMid, t.woodDark],
              ),
              border: Border.all(color: t.brass, width: 2.5),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                BrassPlaque(theme: t, text: 'RESTORATION STALLED', fontSize: 16),
                const SizedBox(height: 14),
                Text(_gameOverReason,
                    textAlign: TextAlign.center,
                    style: AtelierType.body(14, t)),
                const SizedBox(height: 8),
                Text(
                    '${engine.moves} moves · ${engine.formatTime(engine.seconds)}',
                    style: AtelierType.label(12, t)),
                const SizedBox(height: 18),
                OakButton(theme: t, label: 'TRY AGAIN', onTap: _newGame),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () {
                    widget.audio.click();
                    Navigator.of(context).pop();
                  },
                  child:
                      Text('Back to menu', style: AtelierType.label(13, t)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
