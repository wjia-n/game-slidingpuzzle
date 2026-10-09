import 'package:flutter/material.dart';
import '../services/audio_service.dart';
import '../services/settings_service.dart';
import '../theme/atelier.dart';
import '../theme/conservator_themes.dart';
import 'custom_theme_screen.dart';
import 'pro_screen.dart';

/// Settings: brass plaque rows, physical lever toggles, canvas-size
/// selector, theme / tile-style / frame pickers, renameable players.
/// (Built from the DESIGN.md spec — Stitch quota blocked this screen.)
class SettingsScreen extends StatefulWidget {
  final WorkshopAudio audio;
  final WorkshopSettings settings;
  const SettingsScreen(
      {super.key, required this.audio, required this.settings});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _nameCtrl = TextEditingController();
  final _nameFocus = FocusNode();
  final List<TextEditingController> _partyCtrls =
      List.generate(4, (_) => TextEditingController());
  final List<FocusNode> _partyFocus = List.generate(4, (_) => FocusNode());

  @override
  void initState() {
    super.initState();
    _nameCtrl.text = widget.settings.playerName;
    _commitOnFocusLoss(
        _nameFocus, () => widget.settings.setPlayerName(_nameCtrl.text));
    for (int i = 0; i < 4; i++) {
      _partyCtrls[i].text = widget.settings.partyNames[i];
      final idx = i;
      _commitOnFocusLoss(_partyFocus[idx],
          () => widget.settings.setPartyName(idx, _partyCtrls[idx].text));
    }
  }

  /// Name edits also commit when the field loses focus (not just the
  /// keyboard-done action), so renames are never silently dropped.
  void _commitOnFocusLoss(FocusNode node, void Function() commit) {
    node.addListener(() {
      if (!node.hasFocus) {
        commit();
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _nameFocus.dispose();
    for (final c in _partyCtrls) {
      c.dispose();
    }
    for (final f in _partyFocus) {
      f.dispose();
    }
    super.dispose();
  }

  void _applyAudio() {
    final s = widget.settings;
    widget.audio.configure(
        musicOn: s.musicOn, sfxOn: s.sfxOn, volume: s.volume);
    if (!s.musicOn) {
      widget.audio.stopMusic();
    } else {
      widget.audio.startMenuMusic();
    }
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
            padding:
                const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    BrassRoundButton(
                      theme: t,
                      icon: Icons.arrow_back,
                      tooltip: 'Back',
                      size: 44,
                      onTap: () {
                        widget.audio.click();
                        Navigator.of(context).pop();
                      },
                    ),
                    const SizedBox(width: 14),
                    Text('WORKSHOP SETTINGS',
                        style: AtelierType.display(20, t)),
                  ],
                ),
                const SizedBox(height: 18),

                _section(t, 'SOUND & MUSIC'),
                _row(t, 'Music', LeverToggle(
                    theme: t,
                    value: s.musicOn,
                    onChanged: (v) {
                      s.setMusic(v);
                      _applyAudio();
                      setState(() {});
                    })),
                _row(t, 'Sound effects', LeverToggle(
                    theme: t,
                    value: s.sfxOn,
                    onChanged: (v) {
                      s.setSfx(v);
                      _applyAudio();
                      setState(() {});
                    })),
                _row(
                    t,
                    'Volume',
                    Expanded(
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: t.brass,
                          inactiveTrackColor: t.woodDark,
                          thumbColor: t.brassLight,
                        ),
                        child: Slider(
                          value: s.volume,
                          onChanged: (v) {
                            s.setVolume(v);
                            _applyAudio();
                            setState(() {});
                          },
                        ),
                      ),
                    )),

                _section(t, 'RESTORER'),
                _nameField(t, 'Your name', _nameCtrl, _nameFocus,
                    (v) => s.setPlayerName(v)),
                const SizedBox(height: 10),
                Text('PARTY RELAY NAMES (pass-and-play)',
                    style: AtelierType.label(10, t)),
                const SizedBox(height: 8),
                for (int i = 0; i < 4; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _nameField(
                        t, 'Player ${i + 1}', _partyCtrls[i], _partyFocus[i],
                        (v) => s.setPartyName(i, v)),
                  ),

                _section(t, 'CANVAS SIZE'),
                Row(
                  children: [3, 4, 5, 6].map((n) {
                    final locked = n == 6 && !s.isPro;
                    final sel = s.defaultSize == n;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () {
                          widget.audio.click();
                          if (locked) {
                            _openPro();
                          } else {
                            s.setDefaultSize(n);
                            setState(() {});
                          }
                        },
                        child: Container(
                          margin:
                              const EdgeInsets.symmetric(horizontal: 4),
                          padding:
                              const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            color: sel ? t.brass : t.woodDark,
                            border: Border.all(
                                color:
                                    sel ? t.brassLight : t.brassDark,
                                width: sel ? 2.5 : 1.5),
                          ),
                          child: Text('$n×$n${locked ? ' 🔒' : ''}',
                              textAlign: TextAlign.center,
                              style: AtelierType.label(
                                  13, t,
                                  color: sel
                                      ? t.inkBrown
                                      : t.parchment)),
                        ),
                      ),
                    );
                  }).toList(),
                ),

                _section(t, 'WORKSHOP THEME'),
                _catalogGrid(
                  t,
                  ConservatorThemes.all.map((th) {
                    final locked = th.isPro && !s.isPro;
                    final sel = s.themeId == th.id;
                    return _swatch(
                      t,
                      name: th.name,
                      locked: locked,
                      selected: sel,
                      colors: [th.woodMid, th.canvasFace, th.brass],
                      onTap: () {
                        widget.audio.click();
                        if (locked) {
                          _openPro();
                        } else {
                          s.setTheme(th.id);
                          setState(() {});
                        }
                      },
                    );
                  }).toList()
                    ..add(_swatch(
                      t,
                      name: 'My Creation',
                      locked: !s.isPro,
                      selected: s.themeId == 'custom',
                      colors: [
                        Color(s.customColors['woodMid']!),
                        Color(s.customColors['canvasFace']!),
                        Color(s.customColors['brass']!),
                      ],
                      onTap: () {
                        widget.audio.click();
                        if (!s.isPro) {
                          _openPro();
                        } else {
                          Navigator.of(context)
                              .push(MaterialPageRoute(
                                  builder: (_) => CustomThemeScreen(
                                      audio: widget.audio,
                                      settings: s)))
                              .then((_) => setState(() {}));
                        }
                      },
                    )),
                ),

                _section(t, 'TILE FACE STYLE'),
                _catalogGrid(
                  t,
                  TileStyle.values.map((st) {
                    final locked = st.isPro && !s.isPro;
                    final sel = s.tileStyleEnum == st;
                    return GestureDetector(
                      onTap: () {
                        widget.audio.click();
                        if (locked) {
                          _openPro();
                        } else {
                          s.setTileStyle(st.index);
                          setState(() {});
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: sel ? t.brass : t.canvasFace,
                          border: Border.all(
                              color: sel ? t.brassLight : t.canvasEdge,
                              width: sel ? 2.5 : 1.5),
                        ),
                        child: Center(
                          child: tileNumeral(7, st, t,
                              20),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Wrap(
                    spacing: 0,
                    children: TileStyle.values
                        .map((st) => SizedBox(
                              width:
                                  (MediaQuery.of(context).size.width -
                                          44) /
                                      4,
                              child: Text(st.label,
                                  textAlign: TextAlign.center,
                                  style: AtelierType.label(8, t)),
                            ))
                        .toList(),
                  ),
                ),

                _section(t, 'FRAME STYLE'),
                _catalogGrid(
                  t,
                  FrameStyle.values.map((f) {
                    final locked = f.isPro && !s.isPro;
                    final sel = s.frameStyleEnum == f;
                    return GestureDetector(
                      onTap: () {
                        widget.audio.click();
                        if (locked) {
                          _openPro();
                        } else {
                          s.setFrameStyle(f.index);
                          setState(() {});
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: sel ? t.brass : t.woodMid,
                          border: Border.all(
                              color: sel ? t.brassLight : t.woodDark,
                              width: sel ? 2.5 : 1.5),
                        ),
                        child: Text(f.label,
                            textAlign: TextAlign.center,
                            style: AtelierType.label(
                                11, t,
                                color:
                                    sel ? t.inkBrown : t.parchment)),
                      ),
                    );
                  }).toList(),
                ),

                _section(t, 'GUIDANCE'),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: t.parchment,
                    border:
                        Border.all(color: t.brassDark.withValues(alpha: 0.6)),
                  ),
                  child: Text(
                    '★ Stars: finish at or under par for 3 stars, under 1.5× par for 2 stars. '
                    '💡 One hint per game — using it caps your stars at 2. '
                    '↩ Undo is always available and costs 1 move.',
                    style: AtelierType.body(12, t, color: t.inkBrown),
                  ),
                ),
                const SizedBox(height: 24),
                OakButton(
                    theme: t,
                    label: 'BACK',
                    onTap: () => Navigator.of(context).pop()),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openPro() {
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ProScreen(
            audio: widget.audio,
            settings: widget.settings,
            store: null)));
  }

  Widget _section(AtelierTheme t, String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 10),
      child: Text(title, style: AtelierType.label(12, t)),
    );
  }

  Widget _row(AtelierTheme t, String label, Widget control) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [t.woodMid, t.woodDark],
        ),
        border: Border.all(color: t.brassDark, width: 1.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AtelierType.label(13, t)),
          control,
        ],
      ),
    );
  }

  Widget _nameField(AtelierTheme t, String hint,
      TextEditingController ctrl, FocusNode focus, ValueChanged<String> onDone) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: t.recess.withValues(alpha: 0.9),
        border: Border.all(color: t.brassDark, width: 1.5),
      ),
      child: TextField(
        controller: ctrl,
        focusNode: focus,
        style: AtelierType.body(15, t),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle:
              AtelierType.body(14, t, color: t.parchment.withValues(alpha: 0.4)),
          border: InputBorder.none,
        ),
        maxLength: 16,
        onSubmitted: (v) {
          onDone(v);
          setState(() {});
        },
        onChanged: onDone,
      ),
    );
  }

  Widget _catalogGrid(AtelierTheme t, List<Widget> children) {
    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 0.82,
      children: children,
    );
  }

  Widget _swatch(AtelierTheme t,
      {required String name,
      required bool locked,
      required bool selected,
      required List<Color> colors,
      required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: selected ? t.brassLight : t.brassDark,
                    width: selected ? 3 : 1.5),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.45),
                      offset: const Offset(0, 3),
                      blurRadius: 6),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Column(
                  children: colors
                      .map((c) => Expanded(child: Container(color: c)))
                      .toList(),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text('${locked ? '🔒 ' : ''}$name',
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AtelierType.label(8, t)),
        ],
      ),
    );
  }
}
