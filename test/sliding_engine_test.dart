import 'package:flutter_test/flutter_test.dart';
import 'package:slidingpuzzle/engine/sliding_engine.dart';
import 'package:slidingpuzzle/services/settings_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('scramble', () {
    test('50 new games are all solvable and none starts solved', () {
      for (int i = 0; i < 50; i++) {
        final e = SlidingEngine();
        e.newGame(n: 4, m: GameMode.classic);
        // Solvable by construction: replay the recorded walk in reverse.
        final walk = List<int>.of(e.scrambleWalk);
        var b = List<int>.of(e.board);
        var g = e.gap;
        expect(b.where((v) => v == 0).length, 1);
        for (int k = walk.length - 1; k >= 0; k--) {
          final prev = k == 0 ? 15 : walk[k - 1];
          b[g] = b[prev];
          b[prev] = 0;
          g = prev;
        }
        for (int c = 0; c < 15; c++) {
          expect(b[c], c + 1, reason: 'game $i not solvable');
        }
        expect(b[15], 0);
        // Never dealt solved.
        var solved = true;
        for (int c = 0; c < 15; c++) {
          if (e.board[c] != c + 1) solved = false;
        }
        expect(solved && e.board[15] == 0, isFalse,
            reason: 'game $i dealt solved');
        e.dispose();
      }
    });

    test('5x5 smoke: 25 cells, depth applied, solvable', () {
      final e = SlidingEngine();
      e.newGame(n: 5, m: GameMode.classic);
      expect(e.board.length, 25);
      expect(e.scrambleWalk.length, SlidingScoring.scrambleDepth(5));
      expect(e.board.where((v) => v == 0).length, 1);
      e.dispose();
    });
  });

  group('moves', () {
    SlidingEngine rigged(List<int> board, int n) {
      final e = SlidingEngine();
      e.newGame(n: n, m: GameMode.classic);
      e.board = List.of(board);
      e.gap = board.indexOf(0);
      e.phase = SlidePhase.ready;
      return e;
    }

    test('adjacent slide moves the tile and counts 1 move', () {
      // 3x3, gap at 8, tile 8 at 7.
      final e = rigged([1, 2, 3, 4, 5, 6, 7, 8, 0], 3);
      e.tapTile(7);
      expect(e.board[8], 8);
      expect(e.board[7], 0);
      expect(e.gap, 7);
      expect(e.moves, 1);
      e.dispose();
    });

    test('illegal diagonal tap changes nothing and fires invalid', () {
      final e = rigged([1, 2, 3, 4, 5, 6, 7, 0, 8], 3);
      var invalid = 0;
      e.onEvent = (ev) {
        if (ev == SlideEvent.invalid) invalid++;
      };
      e.tapTile(0); // diagonal / distant from gap at 7
      expect(e.moves, 0);
      expect(e.board, [1, 2, 3, 4, 5, 6, 7, 0, 8]);
      expect(invalid, 1);
      e.dispose();
    });

    test('tapping the gap is a neutral no-op', () {
      final e = rigged([1, 2, 3, 4, 5, 6, 7, 0, 8], 3);
      var invalid = 0;
      e.onEvent = (ev) {
        if (ev == SlideEvent.invalid) invalid++;
      };
      e.tapTile(7);
      expect(e.moves, 0);
      expect(invalid, 0);
      e.dispose();
    });

    test('multi-tile slide shifts all tiles, counts exactly 1 move', () {
      // 4x4, gap at row 0 col 0 (cell 0); tap cell 3 -> tiles 1,2,3 shift.
      final e = rigged(
          [0, 1, 2, 3, 5, 6, 7, 4, 9, 10, 11, 8, 13, 14, 15, 12], 4);
      e.tapTile(3);
      expect(e.board.sublist(0, 4), [1, 2, 3, 0]);
      expect(e.gap, 3);
      expect(e.moves, 1);
      expect(e.lastSlide.length, 3);
      e.dispose();
    });

    test('win detected immediately on the completing slide', () async {
      final e = rigged([1, 2, 3, 4, 5, 6, 7, 0, 8], 3);
      var won = false;
      e.onEvent = (ev) {
        if (ev == SlideEvent.win) won = true;
      };
      e.tapTile(8); // slide 8 down into the gap
      // Finalize happens on the engine timer; wait for it.
      await Future.delayed(const Duration(milliseconds: 600));
      expect(e.phase, SlidePhase.over);
      expect(e.result, SlideResult.win);
      expect(e.moves, 1);
      expect(e.stars, 3); // 1 move <= par 30, no hint
      expect(won, isTrue);
      e.dispose();
    });

    test('undo restores prior position and costs 1 move', () async {
      final e = rigged([1, 2, 3, 4, 5, 6, 7, 8, 0], 3);
      e.tapTile(7); // moves=1
      await Future.delayed(const Duration(milliseconds: 400));
      e.tapTile(4); // moves=2 (tile 5 down)
      await Future.delayed(const Duration(milliseconds: 400));
      e.tapTile(3); // moves=3
      await Future.delayed(const Duration(milliseconds: 400));
      e.undo();
      // Board matches the position after 2 slides; counter reads 4.
      expect(e.board, [1, 2, 3, 4, 0, 6, 7, 5, 8]);
      expect(e.gap, 4);
      expect(e.moves, 4);
      e.dispose();
    });

    test('undo with no moves is a safe no-op', () {
      final e = rigged([1, 2, 3, 4, 5, 6, 7, 8, 0], 3);
      e.undo();
      expect(e.moves, 0);
      expect(e.board, [1, 2, 3, 4, 5, 6, 7, 8, 0]);
      e.dispose();
    });

    test('star thresholds: par -> 3, 1.5x par -> 2, beyond -> 1', () {
      expect(SlidingScoring.starsFor(4, 80, hintUsed: false), 3);
      expect(SlidingScoring.starsFor(4, 120, hintUsed: false), 2);
      expect(SlidingScoring.starsFor(4, 200, hintUsed: false), 1);
      expect(SlidingScoring.starsFor(4, 10, hintUsed: true), 2); // hint cap
    });

    test('score formula', () {
      expect(SlidingScoring.score(120, 300),
          100000 - 120 * 100 - 300 * 10);
      expect(SlidingScoring.score(99999, 99999), 0);
    });
  });

  group('hint', () {
    test('hint achieves the minimum available Manhattan improvement',
        () async {
      for (int game = 0; game < 5; game++) {
        final e = SlidingEngine();
        e.newGame(n: 3, m: GameMode.classic);
        e.phase = SlidePhase.ready;
        await e.hint();
        // Poll for the async hint result.
        for (int i = 0; i < 100 && e.hintTile < 0; i++) {
          await Future.delayed(const Duration(milliseconds: 50));
        }
        expect(e.hintUsed, isTrue);
        expect(e.hintTile >= 0, isTrue);
        // RULES.md §11: the hint's resulting Manhattan sum must equal the
        // minimum over all legal actions (never misleading).
        var minH = 1 << 30;
        for (final a in _legalTaps(e.board, e.gap, 3)) {
          final b = List<int>.of(e.board);
          _applyTap(b, e.gap, a, 3);
          final h = _manhattan(b, 3);
          if (h < minH) minH = h;
        }
        final hb = List<int>.of(e.board);
        _applyTap(hb, e.gap, e.hintTile, 3);
        expect(_manhattan(hb, 3), minH,
            reason: 'game $game: hint must achieve min available Manhattan');
        e.dispose();
      }
    });
  });
}

int _manhattan(List<int> b, int n) {
  var sum = 0;
  for (int i = 0; i < b.length; i++) {
    final v = b[i];
    if (v == 0) continue;
    sum += ((i ~/ n) - ((v - 1) ~/ n)).abs() + ((i % n) - ((v - 1) % n)).abs();
  }
  return sum;
}

/// All legal tap cells for (board, gap): same row/col as the gap.
List<int> _legalTaps(List<int> b, int gap, int n) {
  final gr = gap ~/ n, gc = gap % n;
  final out = <int>[];
  for (int c = 0; c < n; c++) {
    if (c != gc) out.add(gr * n + c);
  }
  for (int r = 0; r < n; r++) {
    if (r != gr) out.add(r * n + gc);
  }
  return out;
}

/// Test-side tap application — must mirror the engine's nearest-first
/// multi-tile cascade exactly.
void _applyTap(List<int> b, int gap, int cell, int n) {
  final gr = gap ~/ n, gc = gap % n;
  final r = cell ~/ n, c = cell % n;
  var g = gap;
  if (r == gr) {
    final step = gc > c ? -1 : 1;
    for (int cc = gc + step; ; cc += step) {
      final idx = r * n + cc;
      b[g] = b[idx];
      b[idx] = 0;
      g = idx;
      if (cc == c) break;
    }
  } else {
    final step = gr > r ? -1 : 1;
    for (int rr = gr + step; ; rr += step) {
      final idx = rr * n + c;
      b[g] = b[idx];
      b[idx] = 0;
      g = idx;
      if (rr == r) break;
    }
  }
}
