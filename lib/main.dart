import 'package:flutter/material.dart';
import 'package:wajiha_game_core/wajiha_game_core.dart';
import 'game_screen.dart';

void main() => runApp(const SlidingPuzzleApp());

class SlidingPuzzleApp extends StatelessWidget {
  const SlidingPuzzleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GameShell(
      title: 'Sliding Puzzle',
      tagline: 'One empty square, endless "just one more try". Slide tiles home!',
      emoji: '🧩',
      slug: 'slidingpuzzle',
      howToPlay:
          '• Tap a tile next to the empty square to slide it in.\n• Get the numbers back in order: 1, 2, 3… with the gap last.\n• Feeling brave? Take the 4×4. Feeling chill? Start 3×3.\n• Fewest moves + fastest time = certified puzzle wizard. 🧙',
      playerOptions: const [1],
      supportsBots: false,
      gameBuilder: (ctx, players, cb) => SlidingPuzzleScreen(players: players, callbacks: cb),
    );
  }
}
