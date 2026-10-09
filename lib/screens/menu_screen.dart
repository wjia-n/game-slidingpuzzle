import 'package:flutter/material.dart';
import '../engine/sliding_engine.dart';
import '../services/audio_service.dart';
import '../services/iap_service.dart';
import '../services/settings_service.dart';
import '../theme/atelier.dart';
import 'game_screen.dart';
import 'pro_screen.dart';
import 'settings_screen.dart';

/// Main menu: brass title plaque, oak buttons, board-size + mode pickers.
/// Matches the Stitch main-menu screen (DESIGN.md).
class MenuScreen extends StatefulWidget {
  final WorkshopAudio audio;
  final WorkshopSettings settings;
  const MenuScreen({super.key, required this.audio, required this.settings});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  int _size = 4;
  GameMode _mode = GameMode.classic;
  int _partyCount = 2;
  bool _hasSave = false;
  final StoreService _store = StoreService();

  @override
  void initState() {
    super.initState();
    _size = widget.settings.defaultSize;
    _mode = widget.settings.defaultMode;
    widget.audio.startMenuMusic();
    _store.init().then((_) {
      if (!mounted) return;
      _store.proPurchased.addListener(_onProPurchased);
      if (_store.proPurchased.value) {
        widget.settings.setPro(true);
      }
      setState(() {});
    });
    SlidingEngine.hasSave().then((v) {
      if (mounted) setState(() => _hasSave = v);
    });
  }

  void _onProPurchased() {
    if (_store.proPurchased.value) {
      widget.settings.setPro(true);
    }
  }

  @override
  void dispose() {
    _store.proPurchased.removeListener(_onProPurchased);
    _store.dispose();
    super.dispose();
  }

  void _startGame({bool cont = false}) {
    widget.audio.click();
    if (!widget.settings.isPro) {
      if (_size > 5) {
        _openPro();
        return;
      }
      if (_mode.isPro) {
        _openPro();
        return;
      }
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GameScreen(
          audio: widget.audio,
          settings: widget.settings,
          size: _size,
          mode: _mode,
          cont: cont,
          partyCount: _partyCount,
        ),
      ),
    ).then((_) {
      widget.audio.startMenuMusic();
      SlidingEngine.hasSave().then((v) {
        if (mounted) setState(() => _hasSave = v);
      });
    });
  }

  void _openPro() {
    widget.audio.click();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProScreen(
          audio: widget.audio,
          settings: widget.settings,
          store: _store,
        ),
      ),
    );
  }

  void _openSettings() {
    widget.audio.click();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SettingsScreen(
          audio: widget.audio,
          settings: widget.settings,
        ),
      ),
    ).then((_) {
      if (mounted) {
        setState(() {
          _size = widget.settings.defaultSize;
          _mode = widget.settings.defaultMode;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.settings.theme;
    final s = widget.settings;
    return Scaffold(
      backgroundColor: t.backdrop,
      body: WoodBackdrop(
        theme: t,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              children: [
                // Oak picture-frame border feel via nested containers.
                const SizedBox(height: 8),
                BrassPlaque(
                    theme: t, text: 'SLIDING PUZZLE', fontSize: 22),
                const SizedBox(height: 8),
                Text('A RESTORATION OF ORDER',
                    style: AtelierType.label(12, t)),
                const SizedBox(height: 20),
                // Board-size preview tiles (Stitch main-menu direction).
                Text('CANVAS SIZE', style: AtelierType.label(12, t)),
                const SizedBox(height: 10),
                Row(
                  children: [3, 4, 5, 6].map((n) {
                    final locked = n == 6 && !s.isPro;
                    final sel = _size == n;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () {
                          widget.audio.click();
                          if (locked) {
                            _openPro();
                          } else {
                            setState(() => _size = n);
                          }
                        },
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 5),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: sel
                                  ? [t.brassLight, t.brass]
                                  : [
                                      t.canvasFace,
                                      Color.lerp(t.canvasFace, t.canvasEdge, 0.3)!
                                    ],
                            ),
                            border: Border.all(
                                color: sel ? t.brassLight : t.brassDark,
                                width: sel ? 3 : 1.5),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.5),
                                  offset: const Offset(0, 4),
                                  blurRadius: 8),
                            ],
                          ),
                          child: Column(
                            children: [
                              Text('$n×$n',
                                  style: AtelierType.plaqueTitle(
                                      15, t)),
                              const SizedBox(height: 2),
                              Text(
                                locked
                                    ? 'PRO'
                                    : (n == 3
                                        ? 'Apprentice'
                                        : n == 4
                                            ? 'Classic'
                                            : n == 5
                                                ? 'Master'
                                                : 'Grand Master'),
                                style: AtelierType.label(9, t,
                                    color: t.inkBrown
                                        .withValues(alpha: 0.8)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 18),
                Text('MODE', style: AtelierType.label(12, t)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: GameMode.values.map((m) {
                    final locked = m.isPro && !s.isPro;
                    final sel = _mode == m;
                    return GestureDetector(
                      onTap: () {
                        widget.audio.click();
                        if (locked) {
                          _openPro();
                        } else {
                          setState(() => _mode = m);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 9),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          color: sel ? t.brass : t.woodDark,
                          border: Border.all(
                              color: sel ? t.brassLight : t.brassDark,
                              width: 1.5),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withValues(alpha: 0.45),
                                offset: const Offset(0, 3),
                                blurRadius: 6),
                          ],
                        ),
                        child: Text(
                          '${m.label}${locked ? ' 🔒' : ''}',
                          style: AtelierType.label(
                              11, t,
                              color: sel
                                  ? t.inkBrown
                                  : t.parchment
                                      .withValues(alpha: 0.85)),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 8),
                Text(_mode.blurb,
                    textAlign: TextAlign.center,
                    style: AtelierType.body(12, t,
                        color: t.parchment.withValues(alpha: 0.7))),
                if (_mode == GameMode.party) ...[
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('PLAYERS', style: AtelierType.label(11, t)),
                      const SizedBox(width: 12),
                      for (int c = 2; c <= 4; c++)
                        GestureDetector(
                          onTap: () {
                            widget.audio.click();
                            setState(() => _partyCount = c);
                          },
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _partyCount == c ? t.brass : t.woodDark,
                              border: Border.all(
                                  color: _partyCount == c
                                      ? t.brassLight
                                      : t.brassDark,
                                  width: 2),
                            ),
                            child: Center(
                              child: Text('$c',
                                  style: AtelierType.label(14, t,
                                      color: _partyCount == c
                                          ? t.inkBrown
                                          : t.parchment)),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 20),
                OakButton(
                  theme: t,
                  label: 'NEW GAME',
                  sublabel: '$_size×$_size · ${_mode.label}',
                  onTap: _startGame,
                ),
                const SizedBox(height: 12),
                if (_hasSave)
                  OakButton(
                    theme: t,
                    label: 'CONTINUE',
                    sublabel: 'Resume the unfinished restoration',
                    onTap: () => _startGame(cont: true),
                  ),
                if (_hasSave) const SizedBox(height: 12),
                OakButton(
                  theme: t,
                  label: 'SETTINGS',
                  onTap: _openSettings,
                ),
                const SizedBox(height: 16),
                // Best records strip.
                _bestStrip(t, s),
                const SizedBox(height: 14),
                GestureDetector(
                  onTap: _openPro,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.workspace_premium,
                          color: t.brassLight, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        s.isPro
                            ? 'PRO WORKSHOP — unlocked'
                            : 'Unlock the Pro Workshop',
                        style: AtelierType.label(12, t,
                            color: t.brassLight),
                      ),
                    ],
                  ),
                ),
                if (s.dailyStreak > 0) ...[
                  const SizedBox(height: 8),
                  Text('🔥 Daily streak: ${s.dailyStreak} day${s.dailyStreak == 1 ? '' : 's'}',
                      style: AtelierType.label(12, t)),
                ],
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _bestStrip(AtelierTheme t, WorkshopSettings s) {
    final bm = s.bestMoves(_size);
    final bt = s.bestTime(_size);
    String fmt(int v) =>
        '${(v ~/ 60).toString().padLeft(2, '0')}:${(v % 60).toString().padLeft(2, '0')}';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: t.recess.withValues(alpha: 0.85),
        border: Border.all(color: t.brassDark, width: 1.5),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              offset: const Offset(0, 2),
              blurRadius: 4,
              blurStyle: BlurStyle.inner),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _bestCell(t, 'BEST MOVES', bm == 0 ? '—' : '$bm'),
          _bestCell(t, 'BEST TIME', bt == 0 ? '—' : fmt(bt)),
          _bestCell(t, 'PAR', '${SlidingScoring.parFor(_size)}'),
        ],
      ),
    );
  }

  Widget _bestCell(AtelierTheme t, String label, String value) {
    return Column(
      children: [
        Text(label, style: AtelierType.label(9, t)),
        const SizedBox(height: 2),
        Text(value,
            style: AtelierType.plaqueTitle(15, t)
                .copyWith(color: t.brassLight)),
      ],
    );
  }
}
