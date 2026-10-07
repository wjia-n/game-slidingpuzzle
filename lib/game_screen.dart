import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wajiha_game_core/wajiha_game_core.dart';

/// Sliding Puzzle — 15-puzzle (4x4) + chill 3x3 mode. Guaranteed-solvable shuffle.
class SlidingPuzzleScreen extends StatefulWidget {
  final List<Player> players;
  final GameCallbacks callbacks;
  const SlidingPuzzleScreen({super.key, required this.players, required this.callbacks});
  @override
  State<SlidingPuzzleScreen> createState() => _SlidingPuzzleScreenState();
}

class _SlidingPuzzleScreenState extends State<SlidingPuzzleScreen> {
  int? size; // null = mode chooser
  List<int> board = [];
  int gap = 0, moves = 0, seconds = 0, animId = 0, lastMoved = -1;
  bool over = false, won = false;
  Timer? timer;
  final rnd = Random();
  final Map<String, int> bestMoves = {}, bestTime = {};

  @override
  void initState() {
    super.initState();
    _loadBest();
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Future<void> _loadBest() async {
    final p = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      for (final s in [3, 4]) {
        bestMoves['$s'] = p.getInt('sliding_best_${s}_moves') ?? 0;
        bestTime['$s'] = p.getInt('sliding_best_${s}_time') ?? 0;
      }
    });
  }

  String _fmt(int s) =>
      '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';

  void _startGame(int n) {
    timer?.cancel();
    setState(() {
      size = n;
      moves = 0;
      seconds = 0;
      over = false;
      won = false;
      lastMoved = -1;
      animId++;
    });
    // Solvable by construction: random valid slides from the solved state.
    board = List.generate(n * n, (i) => i == n * n - 1 ? 0 : i + 1);
    gap = n * n - 1;
    for (var k = 0; k < n * n * 60; k++) {
      final nb = _neighbors(gap, n);
      final pick = nb[rnd.nextInt(nb.length)];
      board[gap] = board[pick];
      board[pick] = 0;
      gap = pick;
    }
    // Never start already solved (boring!).
    if (_isSolved()) _startGame(n);
    Sfx.click();
  }

  List<int> _neighbors(int i, int n) {
    final r = i ~/ n, c = i % n, out = <int>[];
    if (r > 0) out.add(i - n);
    if (r < n - 1) out.add(i + n);
    if (c > 0) out.add(i - 1);
    if (c < n - 1) out.add(i + 1);
    return out;
  }

  bool _isSolved() {
    for (var i = 0; i < board.length - 1; i++) {
      if (board[i] != i + 1) return false;
    }
    return true;
  }

  void _tap(int i) {
    if (over || won || size == null) return;
    if (!_neighbors(i, size!).contains(gap)) return;
    if (moves == 0) {
      timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!won && mounted) setState(() => seconds++);
      });
    }
    setState(() {
      board[gap] = board[i];
      board[i] = 0;
      gap = i;
      moves++;
      lastMoved = gap;
      animId++;
    });
    widget.players[0].score = moves;
    widget.callbacks.refreshHud();
    Sfx.move();
    if (_isSolved()) _win();
  }

  Future<void> _win() async {
    won = true;
    timer?.cancel();
    Sfx.win();
    setState(() => animId++); // replay the celebration pop
    final p = await SharedPreferences.getInstance();
    final key = '$size';
    final pm = p.getInt('sliding_best_${key}_moves') ?? 0;
    final pt = p.getInt('sliding_best_${key}_time') ?? 0;
    final newBest = (pm == 0 || moves < pm) || (pt == 0 || seconds < pt);
    if (pm == 0 || moves < pm) await p.setInt('sliding_best_${key}_moves', moves);
    if (pt == 0 || seconds < pt) await p.setInt('sliding_best_${key}_time', seconds);
    if (mounted) {
      setState(() {
        bestMoves[key] = p.getInt('sliding_best_${key}_moves') ?? moves;
        bestTime[key] = p.getInt('sliding_best_${key}_time') ?? seconds;
      });
    }
    await Future.delayed(const Duration(milliseconds: 1100));
    if (!mounted) return;
    over = true;
    widget.callbacks.finish(
      headline: 'Puzzle solved! You wizard! 🧩🎉',
      subline: '$moves moves in ${_fmt(seconds)} on $size×$size.'
          '${newBest ? ' NEW PERSONAL BEST! 🏆' : ''}',
    );
  }

  void _backToChooser() {
    timer?.cancel();
    Sfx.click();
    setState(() {
      size = null;
      over = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = ThemeController.of(context).theme;
    if (size == null) return _chooser(t);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          _stat(t, '👣 MOVES', '$moves'),
          Text('$size×$size', style: TextStyle(color: t.muted, fontWeight: FontWeight.w800, fontSize: 16)),
          _stat(t, '⏱ TIME', _fmt(seconds)),
        ]),
        const SizedBox(height: 12),
        Expanded(
          child: Center(
            child: AspectRatio(
              aspectRatio: 1,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: t.surface, borderRadius: t.radius),
                child: GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: size!, mainAxisSpacing: 8, crossAxisSpacing: 8),
                  itemCount: size! * size!,
                  itemBuilder: (_, i) => _tile(i, t),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text('Best $size×$size: ${bestMoves['$size'] ?? 0} moves · ${_fmt(bestTime['$size'] ?? 0)}',
            style: TextStyle(color: t.muted, fontSize: 13)),
        const SizedBox(height: 8),
        WajihaButton(label: 'Shuffle Again', emoji: '🔀', onTap: () => _startGame(size!)),
        const SizedBox(height: 8),
        TextButton(
          onPressed: _backToChooser,
          child: Text('Change size', style: TextStyle(color: t.muted, fontWeight: FontWeight.w700)),
        ),
        const SizedBox(height: 4),
      ]),
    );
  }

  Widget _chooser(GameTheme t) {
    Widget card(int n, String emoji, String label, String sub) {
      return Expanded(
        child: GestureDetector(
          onTap: () => _startGame(n),
          child: Container(
            margin: EdgeInsets.only(left: n == 3 ? 0 : 6, right: n == 4 ? 0 : 6),
            padding: const EdgeInsets.symmetric(vertical: 18),
            decoration: BoxDecoration(
                gradient: t.headerGradient,
                borderRadius: t.radius,
                boxShadow: [BoxShadow(color: t.primary.withValues(alpha: 0.25), blurRadius: 10, offset: const Offset(0, 4))]),
            child: Column(children: [
              Text(emoji, style: const TextStyle(fontSize: 36)),
              const SizedBox(height: 6),
              Text(label, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
              Text(sub, style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12)),
              const SizedBox(height: 6),
              Text('🏆 ${bestMoves['$n'] ?? 0} mv · ${_fmt(bestTime['$n'] ?? 0)}',
                  style: const TextStyle(color: Colors.white, fontSize: 12)),
            ]),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(22),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Text('🧩', style: TextStyle(fontSize: 64)),
        const SizedBox(height: 8),
        Text('Slide it home!',
            style: TextStyle(color: t.text, fontSize: 26, fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        Text('Tap a tile next to the gap to slide it. Line them up 1, 2, 3…',
            textAlign: TextAlign.center, style: TextStyle(color: t.muted, fontSize: 14)),
        const SizedBox(height: 20),
        Row(children: [
          card(3, '😌', '3 × 3', 'Chill mode'),
          card(4, '🤯', '4 × 4', 'Classic 15-puzzle'),
        ]),
        const SizedBox(height: 16),
        Text('Every shuffle is guaranteed solvable ✨',
            style: TextStyle(color: t.muted, fontSize: 12)),
      ]),
    );
  }

  Widget _stat(GameTheme t, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(gradient: t.headerGradient, borderRadius: t.radius),
      child: Column(children: [
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
      ]),
    );
  }

  Widget _tile(int i, GameTheme t) {
    final v = board[i];
    if (v == 0) {
      return Container(
        decoration: BoxDecoration(
            color: t.background.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: t.primary.withValues(alpha: 0.2), width: 1.5)),
        child: Center(
            child: Text('✨',
                style: TextStyle(fontSize: 20, color: t.muted.withValues(alpha: 0.5)))),
      );
    }
    final n = size!;
    final f = (v - 1) / (n * n - 1); // 0..1 across the board
    final c1 = Color.lerp(t.primary, t.secondary, f)!;
    final c2 = Color.lerp(t.secondary, t.accent, f)!;
    final justMoved = i == lastMoved;
    final celebrate = won;
    return GestureDetector(
      onTap: () => _tap(i),
      child: TweenAnimationBuilder<double>(
        key: ValueKey('$animId-$i'),
        tween: Tween(begin: (justMoved || celebrate) ? 0.5 : 1.0, end: 1.0),
        duration: Duration(milliseconds: celebrate ? 500 : 200),
        curve: Curves.elasticOut,
        builder: (_, s, child) => Transform.scale(
          scale: s,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [c1, c2], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: c2.withValues(alpha: 0.4), blurRadius: 8, offset: const Offset(0, 3))],
            ),
            alignment: Alignment.center,
            child: Text('$v',
                style: TextStyle(
                    color: t.dark ? Colors.black : Colors.white,
                    fontSize: n == 3 ? 34 : 28,
                    fontWeight: FontWeight.w900)),
          ),
        ),
      ),
    );
  }
}
