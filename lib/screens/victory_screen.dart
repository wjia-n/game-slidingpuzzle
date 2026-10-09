import 'package:flutter/material.dart';
import '../engine/sliding_engine.dart';
import '../services/audio_service.dart';
import '../services/settings_service.dart';
import '../theme/atelier.dart';
import 'game_screen.dart';

/// Victory: the board as a freshly restored masterpiece, parchment stats
/// slip, brass star medallions stamping in one by one.
/// (Built from the DESIGN.md spec — Stitch quota blocked this screen.)
class VictoryScreen extends StatefulWidget {
  final WorkshopAudio audio;
  final WorkshopSettings settings;
  final SlidingEngine engine;
  const VictoryScreen({
    super.key,
    required this.audio,
    required this.settings,
    required this.engine,
  });

  @override
  State<VictoryScreen> createState() => _VictoryScreenState();
}

class _VictoryScreenState extends State<VictoryScreen> {
  int _starsShown = 0;

  @override
  void initState() {
    super.initState();
    _stampStars();
  }

  Future<void> _stampStars() async {
    for (int i = 1; i <= widget.engine.stars; i++) {
      await Future.delayed(const Duration(milliseconds: 420));
      if (!mounted) return;
      setState(() => _starsShown = i);
    }
  }

  void _again() {
    widget.audio.click();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => GameScreen(
          audio: widget.audio,
          settings: widget.settings,
          size: widget.engine.size,
          mode: widget.engine.mode,
          partyCount: widget.engine.partyNames.isEmpty
              ? 2
              : widget.engine.partyNames.length,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.settings.theme;
    final e = widget.engine;
    final s = widget.settings;
    return Scaffold(
      backgroundColor: t.backdrop,
      body: WoodBackdrop(
        theme: t,
        child: SafeArea(
          child: SingleChildScrollView(
            padding:
                const EdgeInsets.symmetric(horizontal: 26, vertical: 20),
            child: Column(
              children: [
                const SizedBox(height: 10),
                BrassPlaque(theme: t, text: 'RESTORED', fontSize: 26),
                const SizedBox(height: 10),
                Text('A MASTERPIECE, SIGNED AND SEALED',
                    style: AtelierType.label(11, t)),
                const SizedBox(height: 18),
                // Star medallions stamp in one by one.
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (int i = 1; i <= 3; i++) ...[
                      StarMedallion(
                          theme: t, earned: _starsShown >= i, size: 58),
                      if (i < 3) const SizedBox(width: 14),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                if (e.hintUsed)
                  Text('Hint used — stars capped at 2',
                      style: AtelierType.body(12, t,
                          color: t.parchment.withValues(alpha: 0.7))),
                const SizedBox(height: 18),
                // Parchment stats slip.
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 22, vertical: 18),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    color: t.parchment,
                    border:
                        Border.all(color: t.brassDark.withValues(alpha: 0.6)),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.5),
                          offset: const Offset(0, 6),
                          blurRadius: 14),
                    ],
                  ),
                  child: Column(
                    children: [
                      _slipRow(t, 'Restorer', _playerLine()),
                      _slipRow(t, 'Canvas', '${e.size}×${e.size}'),
                      _slipRow(t, 'Mode', e.mode.label),
                      _slipRow(t, 'Moves', '${e.moves}',
                          highlight: true),
                      _slipRow(t, 'Time', e.formatTime(e.seconds),
                          highlight: true),
                      _slipRow(t, 'Score', '${e.finalScore}'),
                      if (e.newBest)
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              color: t.brass,
                            ),
                            child: Text('★ NEW BEST ★',
                                style: AtelierType.label(12, t,
                                    color: t.inkBrown)),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                OakButton(
                    theme: t,
                    label: 'RESTORE AGAIN',
                    sublabel: 'Fresh scramble, same canvas',
                    onTap: _again),
                const SizedBox(height: 12),
                OakButton(
                  theme: t,
                  label: 'GALLERY',
                  sublabel: 'Back to the menu',
                  onTap: () {
                    widget.audio.click();
                    Navigator.of(context).popUntil((r) => r.isFirst);
                  },
                ),
                const SizedBox(height: 16),
                Text(
                  'Best ${e.size}×${e.size}: ${s.bestMoves(e.size)} moves · ${_fmt(s.bestTime(e.size))}',
                  style: AtelierType.body(12, t,
                      color: t.parchment.withValues(alpha: 0.7)),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _playerLine() {
    final e = widget.engine;
    if (e.mode == GameMode.party && e.partyNames.isNotEmpty) {
      final mv = e.partyMoves;
      var best = 0;
      for (int i = 1; i < mv.length; i++) {
        if (mv[i] < mv[best]) best = i;
      }
      return '${e.partyNames[best]} leads the crew';
    }
    return widget.settings.playerName;
  }

  Widget _slipRow(AtelierTheme t, String label, String value,
      {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label.toUpperCase(),
              style: AtelierType.label(11, t, color: t.inkBrown)),
          Text(value,
              style: (highlight
                      ? AtelierType.plaqueTitle(17, t)
                      : AtelierType.body(15, t, color: t.inkBrown))
                  .copyWith(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  String _fmt(int v) =>
      '${(v ~/ 60).toString().padLeft(2, '0')}:${(v % 60).toString().padLeft(2, '0')}';
}
