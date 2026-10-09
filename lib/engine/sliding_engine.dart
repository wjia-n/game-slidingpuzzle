import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/settings_service.dart';

/// Turn phases owned entirely by the engine. The UI only renders.
enum SlidePhase {
  idle, // no game loaded
  scrambling, // scramble cascade animating; input locked
  ready, // board live, timer not yet started (starts on first slide)
  playing, // timer running
  animating, // a slide is in flight; at most one queued tap
  paused, // user paused / app backgrounded
  over, // finished (win / lose / abandoned)
}

enum SlideResult { none, win, timeUp, outOfMoves, abandoned }

enum SlideEvent {
  gameStart,
  slide, // single-tile slide
  multiSlide, // multi-tile slide
  invalid, // illegal tap
  undo,
  hint,
  win,
  lose,
  tick, // timer tick (UI may ignore; ChangeNotifier covers it)
}

/// One tile's movement within a slide, for the UI to animate.
class SlideStep {
  final int value; // tile number
  final int from; // cell index before
  final int to; // cell index after
  const SlideStep(this.value, this.from, this.to);
}

/// Sliding Puzzle engine: deterministic rules, scramble, hint search,
/// timers, autosave. UI-agnostic. Owns all phase transitions; a watchdog
/// recovers any phase found without a live timer, so stuck states are
/// impossible by construction.
class SlidingEngine extends ChangeNotifier {
  // ------------------------------------------------------------ game state
  int size = 4;
  GameMode mode = GameMode.classic;
  List<int> board = []; // row-major, 0 = empty slot
  int gap = 0;
  int moves = 0;
  int seconds = 0; // active foreground play seconds
  int remaining = 0; // clock-mode countdown
  SlidePhase phase = SlidePhase.idle;
  SlideResult result = SlideResult.none;
  bool hintUsed = false;
  int hintTile = -1; // cell index highlighted by hint, -1 = none

  /// Last slide's tile steps for the UI animation, with a fresh [slideId].
  List<SlideStep> lastSlide = const [];
  int slideId = 0;

  /// Recorded scramble walk (gap positions after each step) for the UI's
  /// animated scramble cascade.
  List<int> scrambleWalk = const [];

  /// Party relay state.
  List<String> partyNames = const [];
  List<int> partyMoves = const [];
  int partyTurn = 0;

  /// Stars / score of the finished game (valid when phase == over).
  int stars = 0;
  int finalScore = 0;
  bool newBest = false;

  /// UI hook for sounds / haptics / navigation. Set by the screen.
  void Function(SlideEvent event)? onEvent;

  // ------------------------------------------------------------ internals
  final Random _rand = Random();
  static final Set<int> _usedSeeds = {};
  Timer? _timer; // single phase-transition timer
  Timer? _tick; // 1-second gameplay clock
  Timer? _watchdog; // stuck-state recovery
  int? _queuedTap; // at most one tap queued during animation
  List<int>? _undoBoard; // single-level undo snapshot
  int? _undoGap;
  bool _disposed = false;
  bool _resultDelivered = false;
  DateTime? _hintAt;
  int _sessionSalt = 0;

  static const int _animMs = 230;
  static const String _saveKey = 'sp_save_v1';

  SlidingEngine() {
    _watchdog = Timer.periodic(const Duration(seconds: 2), (_) => _recover());
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _tick?.cancel();
    _watchdog?.cancel();
    super.dispose();
  }

  // ------------------------------------------------------------ timer utils
  void _arm(Duration d, void Function() fn) {
    if (_disposed || phase == SlidePhase.paused) return;
    _timer?.cancel();
    _timer = Timer(d, () {
      _timer = null;
      if (!_disposed && phase != SlidePhase.paused) fn();
    });
  }

  void _startTick() {
    _tick?.cancel();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_disposed || phase == SlidePhase.paused) return;
      if (phase == SlidePhase.playing || phase == SlidePhase.animating) {
        seconds++;
        if (mode == GameMode.clock) {
          remaining--;
          if (remaining <= 0) {
            remaining = 0;
            _finish(SlideResult.timeUp);
            return;
          }
        }
        onEvent?.call(SlideEvent.tick);
        notifyListeners();
      }
    });
  }

  void _stopTick() {
    _tick?.cancel();
    _tick = null;
  }

  /// Watchdog: recover any phase found without a live timer.
  void _recover() {
    if (_disposed || phase == SlidePhase.paused) return;
    if (phase == SlidePhase.animating && _timer == null) {
      _finalizeSlide(); // animation timer died: settle immediately
    } else if (phase == SlidePhase.over && !_resultDelivered) {
      _deliverResult();
    } else if ((phase == SlidePhase.playing || phase == SlidePhase.ready) &&
        _tick == null &&
        result == SlideResult.none) {
      _startTick(); // clock died: restart it
    }
  }

  // ------------------------------------------------------------ game setup
  int _freshSeed() {
    var s = _rand.nextInt(1 << 30);
    while (_usedSeeds.contains(s)) {
      s = (s + 1) % (1 << 30);
    }
    _usedSeeds.add(s);
    return s;
  }

  /// Start a new game. [seed] forces the scramble (daily mode passes the
  /// date seed); otherwise a session-unique seed is used.
  void newGame({
    required int n,
    required GameMode m,
    int? seed,
    List<String>? party,
  }) {
    _timer?.cancel();
    _stopTick();
    size = n.clamp(3, 6);
    mode = m;
    moves = 0;
    seconds = 0;
    hintUsed = false;
    hintTile = -1;
    result = SlideResult.none;
    stars = 0;
    finalScore = 0;
    newBest = false;
    lastSlide = const [];
    _undoBoard = null;
    _undoGap = null;
    _queuedTap = null;
    _resultDelivered = false;
    remaining = SlidingScoring.clockBudget(size);
    if (m == GameMode.party && party != null && party.length >= 2) {
      partyNames = List.of(party);
      partyMoves = List.filled(party.length, 0);
      partyTurn = 0;
    } else {
      partyNames = const [];
      partyMoves = const [];
      partyTurn = 0;
    }

    // Solved layout, then a seeded random walk of the gap (RULES.md §2/§7:
    // solvable by construction, no immediate reversals).
    final cells = size * size;
    board = List.generate(cells, (i) => i == cells - 1 ? 0 : i + 1);
    gap = cells - 1;
    final rng = Random(seed ?? (_freshSeed() + _sessionSalt++));
    final depth = SlidingScoring.scrambleDepth(size);
    final walk = <int>[];
    int prevGap = -1;
    for (int k = 0; k < depth; k++) {
      final nb = _neighbors(gap).where((c) => c != prevGap).toList();
      final pick = nb[rng.nextInt(nb.length)];
      prevGap = gap;
      board[gap] = board[pick];
      board[pick] = 0;
      gap = pick;
      walk.add(gap);
    }
    scrambleWalk = walk;
    if (_isSolved()) {
      // RULES.md §12: never deal an already-solved board — re-scramble.
      newGame(n: n, m: m, party: party);
      return;
    }
    phase = SlidePhase.scrambling;
    notifyListeners();
    onEvent?.call(SlideEvent.gameStart);
    _saveSoon();
  }

  /// Called by the UI when the scramble cascade animation has played.
  void finishScramble() {
    if (phase != SlidePhase.scrambling || _disposed) return;
    phase = SlidePhase.ready;
    _startTick();
    notifyListeners();
  }

  List<int> _neighbors(int cell) {
    final r = cell ~/ size, c = cell % size;
    final out = <int>[];
    if (r > 0) out.add(cell - size);
    if (r < size - 1) out.add(cell + size);
    if (c > 0) out.add(cell - 1);
    if (c < size - 1) out.add(cell + 1);
    return out;
  }

  bool _isSolved() {
    for (int i = 0; i < board.length - 1; i++) {
      if (board[i] != i + 1) return false;
    }
    return board.last == 0;
  }

  /// Cells of the tiles that would move if [cell] were tapped, in order
  /// from NEAREST the gap outward (the order they cascade into the gap).
  /// Empty if the tap is illegal.
  List<int> _slideCells(int cell) {
    if (cell == gap) return const []; // tapping the gap: neutral no-op
    final gr = gap ~/ size, gc = gap % size;
    final r = cell ~/ size, c = cell % size;
    if (r != gr && c != gc) return const []; // not same row/col: illegal
    final out = <int>[];
    if (r == gr) {
      final step = gc > c ? -1 : 1; // walk from the gap toward the tile
      for (int cc = gc + step; ; cc += step) {
        out.add(r * size + cc);
        if (cc == c) break;
      }
    } else {
      final step = gr > r ? -1 : 1;
      for (int rr = gr + step; ; rr += step) {
        out.add(rr * size + c);
        if (rr == r) break;
      }
    }
    return out;
  }

  // ------------------------------------------------------------ input
  /// Tap (or drag-commit) on [cell]. Legal slides apply; illegal taps fire
  /// the invalid event without touching state (RULES.md §5).
  void tapTile(int cell) {
    if (phase == SlidePhase.animating) {
      // RULES.md §12: queue at most one slide during animation.
      final cells = _slideCells(cell);
      _queuedTap = cells.isEmpty ? null : cell;
      return;
    }
    if (phase != SlidePhase.ready && phase != SlidePhase.playing) return;
    if (cell < 0 || cell >= board.length) return;
    final cells = _slideCells(cell);
    if (cells.isEmpty) {
      if (cell != gap) onEvent?.call(SlideEvent.invalid);
      return;
    }
    _applySlide(cells);
  }

  void _applySlide(List<int> cells) {
    // Single-level undo snapshot (RULES.md §4).
    _undoBoard = List.of(board);
    _undoGap = gap;
    _queuedTap = null;
    hintTile = -1;

    final steps = <SlideStep>[];
    if (cells.length == 1) {
      final from = cells.first;
      final value = board[from];
      board[gap] = value;
      board[from] = 0;
      steps.add(SlideStep(value, from, gap));
      gap = from;
    } else {
      // Multi-tile slide: every tile between the tapped tile and the gap
      // shifts one step toward the gap (RULES.md §4).
      final gr = gap ~/ size, gc = gap % size;
      final r0 = cells.first ~/ size, c0 = cells.first % size;
      final dr = (gr - r0).sign, dc = (gc - c0).sign;
      var g = gap;
      for (final cell in cells) {
        final value = board[cell];
        board[g] = value;
        board[cell] = 0;
        steps.add(SlideStep(value, cell, g));
        g = cell;
      }
      gap = g;
      assert(dr == 0 || dc == 0);
    }
    lastSlide = steps;
    slideId++;
    moves++;
    if (mode == GameMode.party && partyMoves.isNotEmpty) {
      partyMoves[partyTurn]++;
      partyTurn = (partyTurn + 1) % partyNames.length;
    }
    if (phase == SlidePhase.ready) {
      // RULES.md §2: the timer starts when the first slide is made.
      _startTick();
    }
    // Every slide goes through the animating phase so input serialization
    // (RULES.md §12) and win detection are uniform.
    phase = SlidePhase.animating;
    onEvent?.call(cells.length == 1 ? SlideEvent.slide : SlideEvent.multiSlide);
    notifyListeners();
    _arm(Duration(milliseconds: _animMs + 60), _finalizeSlide);
    _saveSoon();
  }

  void _finalizeSlide() {
    if (_disposed || phase == SlidePhase.paused) return;
    if (phase != SlidePhase.animating) {
      // Spurious wake (e.g. after pause): drain any queued tap sanely.
      _queuedTap = null;
      return;
    }
    if (_isSolved()) {
      _finish(SlideResult.win);
      return;
    }
    if (mode == GameMode.challenge &&
        moves > SlidingScoring.parFor(size)) {
      _finish(SlideResult.outOfMoves);
      return;
    }
    final queued = _queuedTap;
    _queuedTap = null;
    if (queued != null) {
      final cells = _slideCells(queued);
      if (cells.isNotEmpty) {
        _applySlide(cells);
        return;
      }
    }
    phase = SlidePhase.playing;
    notifyListeners();
  }

  /// Undo: single level, unlimited uses, +1 move per use (RULES.md §4).
  /// No-op when no moves have been made; disabled once finished.
  void undo() {
    if (phase != SlidePhase.ready &&
        phase != SlidePhase.playing &&
        phase != SlidePhase.animating) {
      return;
    }
    if (_undoBoard == null || _undoGap == null) return; // no-op, no error
    board = _undoBoard!;
    gap = _undoGap!;
    _undoBoard = null;
    _undoGap = null;
    moves++;
    hintTile = -1;
    lastSlide = const [];
    slideId++;
    phase = phase == SlidePhase.ready ? SlidePhase.ready : SlidePhase.playing;
    onEvent?.call(SlideEvent.undo);
    notifyListeners();
    _saveSoon();
  }

  /// One hint per game (RULES.md §7): highlights a tile on the solution
  /// path. Using it caps the solve at 2 stars.
  Future<void> hint() async {
    if (hintUsed) return;
    if (phase != SlidePhase.ready && phase != SlidePhase.playing) return;
    hintUsed = true;
    _hintAt = DateTime.now();
    onEvent?.call(SlideEvent.hint);
    notifyListeners();
    final cell = await _computeHint();
    if (_disposed) return;
    // Only honor the hint if the board hasn't changed since the request.
    if (_hintAt != null &&
        (phase == SlidePhase.ready || phase == SlidePhase.playing)) {
      hintTile = cell;
      notifyListeners();
    }
  }

  // ------------------------------------------------------------ hint search
  int _manhattan(List<int> b) {
    var sum = 0;
    for (int i = 0; i < b.length; i++) {
      final v = b[i];
      if (v == 0) continue;
      final gr = (v - 1) ~/ size, gc = (v - 1) % size;
      sum += ((i ~/ size) - gr).abs() + ((i % size) - gc).abs();
    }
    return sum;
  }

  /// All legal tap cells (each defines one slide action).
  List<int> _actions(List<int> b, int g) {
    final gr = g ~/ size, gc = g % size;
    final out = <int>[];
    for (int c = 0; c < size; c++) {
      if (c != gc) out.add(gr * size + c);
    }
    for (int r = 0; r < size; r++) {
      if (r != gr) out.add(r * size + gc);
    }
    return out;
  }

  /// Apply a tap action to (board, gap); returns the new gap.
  /// Tiles cascade nearest-first, matching [_applySlide].
  int _applyAction(List<int> b, int g, int cell) {
    final gr = g ~/ size, gc = g % size;
    final r = cell ~/ size, c = cell % size;
    var ng = g;
    if (r == gr) {
      final step = gc > c ? -1 : 1;
      for (int cc = gc + step; ; cc += step) {
        final idx = r * size + cc;
        b[ng] = b[idx];
        b[idx] = 0;
        ng = idx;
        if (cc == c) break;
      }
    } else {
      final step = gr > r ? -1 : 1;
      for (int rr = gr + step; ; rr += step) {
        final idx = rr * size + c;
        b[ng] = b[idx];
        b[idx] = 0;
        ng = idx;
        if (rr == r) break;
      }
    }
    return ng;
  }

  /// Hint search (RULES.md §11): IDA* with Manhattan heuristic, bounded by
  /// a 2s budget, with a greedy fallback. RULES §11 compliance is enforced
  /// structurally: the suggested move's resulting Manhattan sum is never
  /// worse than the minimum available improvement — the hint can never be
  /// deliberately misleading. Returns the tap cell.
  Future<int> _computeHint() async {
    return Future(() {
      final deadline =
          DateTime.now().add(const Duration(seconds: 2)).millisecondsSinceEpoch;
      final startBoard = List<int>.of(board);
      final startGap = gap;
      final actions = _actions(startBoard, startGap);

      int resultingH(int a) {
        final b = List<int>.of(startBoard);
        _applyAction(b, startGap, a);
        return _manhattan(b);
      }

      // Greedy minimum: the best available Manhattan improvement.
      var greedyBest = actions.first;
      var greedyH = resultingH(greedyBest);
      for (final a in actions.skip(1)) {
        final h = resultingH(a);
        if (h < greedyH) {
          greedyH = h;
          greedyBest = a;
        }
      }

      // IDA*: first move of an optimal solution, time-boxed.
      final path = <int>[];
      final seen = <String>{};
      int? found;

      bool dfs(List<int> b, int g, int depth, int bound) {
        if (DateTime.now().millisecondsSinceEpoch > deadline) return true;
        final h = _manhattan(b);
        final f = depth + h;
        if (f > bound) return false;
        if (h == 0) {
          found = path.isEmpty ? -1 : path.first;
          return true;
        }
        final key = b.join(',');
        if (seen.contains(key)) return false;
        seen.add(key);
        for (final a in _actions(b, g)) {
          final nb = List<int>.of(b);
          final ng = _applyAction(nb, g, a);
          path.add(a);
          if (dfs(nb, ng, depth + 1, bound)) return true;
          path.removeLast();
          if (DateTime.now().millisecondsSinceEpoch > deadline) {
            seen.remove(key);
            return true;
          }
        }
        seen.remove(key);
        return false;
      }

      int? idaMove;
      var bound = _manhattan(startBoard);
      for (int round = 0; round < 40; round++) {
        seen.clear();
        path.clear();
        found = null;
        final done = dfs(List<int>.of(startBoard), startGap, 0, bound);
        if (found != null && found != -1) {
          idaMove = found;
          break;
        }
        if (done) break; // deadline hit or search exhausted
        bound += 2;
        if (DateTime.now().millisecondsSinceEpoch > deadline) break;
      }

      // Prefer the optimal first move only when it is Manhattan-competitive
      // with the best available improvement; otherwise the greedy minimum.
      if (idaMove != null && resultingH(idaMove) <= greedyH) {
        return idaMove;
      }
      return greedyBest;
    });
  }

  // ------------------------------------------------------------ pause/resume
  void setPaused(bool v) {
    if (_disposed) return;
    if (v &&
        phase != SlidePhase.paused &&
        phase != SlidePhase.over &&
        phase != SlidePhase.idle) {
      _pausedFrom = phase;
      phase = SlidePhase.paused;
      _timer?.cancel();
      _timer = null;
      _stopTick();
      _saveSoon();
      notifyListeners();
    } else if (!v && phase == SlidePhase.paused) {
      phase = _pausedFrom;
      _pausedFrom = SlidePhase.playing;
      if (phase == SlidePhase.animating) {
        _arm(const Duration(milliseconds: 120), _finalizeSlide);
      } else if (phase == SlidePhase.playing) {
        _startTick();
      }
      // scrambling / ready: nothing to restart; the UI resumes its cascade.
      notifyListeners();
    }
  }

  SlidePhase _pausedFrom = SlidePhase.playing;

  /// True when resuming from pause needs the manual pause overlay
  /// (a live game was interrupted). Scrambling/ready pauses resume silently.
  bool get resumeNeedsOverlay =>
      _pausedFrom == SlidePhase.playing ||
      _pausedFrom == SlidePhase.animating;

  /// Give up from the pause menu: discards the attempt, no score recorded.
  void giveUp() {
    if (phase == SlidePhase.over || phase == SlidePhase.idle) return;
    _finish(SlideResult.abandoned);
  }

  // ------------------------------------------------------------ finish
  void _finish(SlideResult r) {
    if (phase == SlidePhase.over) return;
    phase = SlidePhase.over;
    result = r;
    _timer?.cancel();
    _timer = null;
    _stopTick();
    _queuedTap = null;
    hintTile = -1;
    if (r == SlideResult.win) {
      stars = SlidingScoring.starsFor(size, moves, hintUsed: hintUsed);
      finalScore = SlidingScoring.score(moves, seconds);
    }
    _clearSave();
    notifyListeners();
    _deliverResult();
  }

  void _deliverResult() {
    if (_resultDelivered || _disposed) return;
    if (phase != SlidePhase.over) return;
    _resultDelivered = true;
    onEvent?.call(
        result == SlideResult.win ? SlideEvent.win : SlideEvent.lose);
  }

  // ------------------------------------------------------------ persistence
  Timer? _saveDebounce;

  void _saveSoon() {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 400), () {
      if (!_disposed) _saveNow();
    });
  }

  Future<void> _saveNow() async {
    if (_disposed) return;
    if (phase == SlidePhase.idle ||
        phase == SlidePhase.over ||
        phase == SlidePhase.scrambling) {
      return;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = {
        'v': 1,
        'size': size,
        'mode': mode.index,
        'board': board,
        'gap': gap,
        'moves': moves,
        'seconds': seconds,
        'remaining': remaining,
        'hintUsed': hintUsed,
        'undoBoard': _undoBoard,
        'undoGap': _undoGap,
        'partyNames': partyNames,
        'partyMoves': partyMoves,
        'partyTurn': partyTurn,
      };
      await prefs.setString(_saveKey, jsonEncode(data));
    } catch (_) {}
  }

  Future<void> _clearSave() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_saveKey);
    } catch (_) {}
  }

  /// True when a valid in-progress game exists to continue.
  static Future<bool> hasSave() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_saveKey);
      if (raw == null) return false;
      return _validate(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return false;
    }
  }

  static bool _validate(Map<String, dynamic> d) {
    try {
      final n = (d['size'] as int).clamp(3, 6);
      final b = (d['board'] as List).map((e) => e as int).toList();
      if (b.length != n * n) return false;
      final sorted = List<int>.of(b)..sort();
      for (int i = 0; i < sorted.length; i++) {
        if (sorted[i] != i) return false; // wrong tile set
      }
      if (!b.contains(0)) return false; // missing empty slot
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Restore a saved game. Returns false when the save is missing/corrupt
  /// (RULES.md §12: corrupt saves are discarded).
  Future<bool> loadSave() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_saveKey);
      if (raw == null) return false;
      final d = jsonDecode(raw) as Map<String, dynamic>;
      if (!_validate(d)) {
        await prefs.remove(_saveKey);
        return false;
      }
      _timer?.cancel();
      _stopTick();
      size = (d['size'] as int).clamp(3, 6);
      mode = GameMode.values[(d['mode'] as int).clamp(0, GameMode.values.length - 1)];
      board = (d['board'] as List).map((e) => e as int).toList();
      gap = d['gap'] as int;
      moves = d['moves'] as int;
      seconds = d['seconds'] as int;
      remaining = (d['remaining'] as int?) ?? SlidingScoring.clockBudget(size);
      hintUsed = (d['hintUsed'] as bool?) ?? false;
      hintTile = -1;
      final ub = d['undoBoard'];
      _undoBoard =
          ub == null ? null : (ub as List).map((e) => e as int).toList();
      _undoGap = d['undoGap'] as int?;
      final pnames = d['partyNames'] as List?;
      partyNames = pnames == null
          ? const []
          : pnames.map((e) => e.toString()).toList();
      final pmoves = d['partyMoves'] as List?;
      partyMoves = pmoves == null
          ? const []
          : pmoves.map((e) => e as int).toList();
      partyTurn = (d['partyTurn'] as int?) ?? 0;
      result = SlideResult.none;
      stars = 0;
      finalScore = 0;
      newBest = false;
      lastSlide = const [];
      _queuedTap = null;
      _resultDelivered = false;
      scrambleWalk = const [];
      phase = SlidePhase.playing;
      _startTick();
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  String formatTime(int s) =>
      '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';
}
